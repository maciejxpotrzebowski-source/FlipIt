import Foundation
import SwiftUI
import Combine
import Supabase
import AuthenticationServices
import CryptoKit

#if canImport(UIKit)
import UIKit
#endif

// MARK: - UserProfile Model

struct UserProfile: Codable, Identifiable, Equatable {
    let id: UUID
    let username: String
    let usernameLower: String
    let createdAt: Date?
    let updatedAt: Date?
    let usernameChangedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case usernameLower = "username_lower"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case usernameChangedAt = "username_changed_at"
    }
    
    init(
        id: UUID,
        username: String,
        usernameLower: String,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        usernameChangedAt: Date? = nil
    ) {
        self.id = id
        self.username = username
        self.usernameLower = usernameLower
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.usernameChangedAt = usernameChangedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        usernameLower = try container.decodeIfPresent(String.self, forKey: .usernameLower) ?? username.lowercased()
        
        createdAt = Self.parseDate(container: container, key: .createdAt)
        updatedAt = Self.parseDate(container: container, key: .updatedAt)
        usernameChangedAt = Self.parseDate(container: container, key: .usernameChangedAt)
    }
    
    private static func parseDate(container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Date? {
        if let date = try? container.decodeIfPresent(Date.self, forKey: key) {
            return date
        }
        if let string = try? container.decodeIfPresent(String.self, forKey: key) {
            let formatterWithFraction = ISO8601DateFormatter()
            formatterWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatterWithFraction.date(from: string) {
                return date
            }
            let standardFormatter = ISO8601DateFormatter()
            standardFormatter.formatOptions = [.withInternetDateTime]
            return standardFormatter.date(from: string)
        }
        return nil
    }
}

// MARK: - Auth Error

enum AuthError: LocalizedError {
    case invalidAppleCredentials
    case invalidNonce
    case usernameTaken
    case invalidUsernameFormat
    case usernameChangeCooldown(daysLeft: Int)
    case notAuthenticated
    case custom(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidAppleCredentials:
            return NSLocalizedString("Unable to verify Apple credentials.", comment: "")
        case .invalidNonce:
            return NSLocalizedString("Authentication security token error.", comment: "")
        case .usernameTaken:
            return NSLocalizedString("This username is already taken or in quarantine.", comment: "")
        case .invalidUsernameFormat:
            return NSLocalizedString("Username must be 3-20 characters long and contain only letters, numbers, or underscores.", comment: "")
        case .usernameChangeCooldown(let daysLeft):
            return String(format: NSLocalizedString("You can change your username in %lld days.", comment: ""), Int64(daysLeft))
        case .notAuthenticated:
            return NSLocalizedString("You must be signed in to perform this action.", comment: "")
        case .custom(let message):
            return message
        }
    }
}

// MARK: - ASWebAuthentication Presentation Context Provider

#if canImport(AuthenticationServices) && canImport(UIKit)
@MainActor
final class WebAuthPresentationProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthPresentationProvider()
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow } ?? UIWindow()
        return window
    }
}
#endif

// MARK: - AuthManager

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    /// Feature flag: Sign in with Apple requires paid Apple Developer Program capability.
    /// Set to false on Free Personal Team builds to prevent unsupported capability crashes.
    static let isAppleSignInEnabled: Bool = false
    
    @Published var currentUser: User? = nil
    @Published var currentProfile: UserProfile? = nil
    @Published var isLoading: Bool = false
    @Published var needsUsernameSetup: Bool = false
    @Published var errorMessage: String? = nil
    
    private var currentNonce: String?
    private var authStateTask: Task<Void, Never>?
    
    var isAuthenticated: Bool {
        currentUser != nil
    }
    
    var userEmail: String? {
        currentUser?.email
    }
    
    var currentUserId: UUID? {
        currentUser?.id
    }
    
    var username: String? {
        currentProfile?.username
    }
    
    var formattedHandle: String {
        if let u = username, !u.isEmpty {
            return "@\(u)"
        }
        return ""
    }
    
    var canChangeUsername: Bool {
        guard let changedAt = currentProfile?.usernameChangedAt else { return true }
        return Date().timeIntervalSince(changedAt) >= (30 * 86400)
    }
    
    var daysUntilUsernameChange: Int {
        guard let changedAt = currentProfile?.usernameChangedAt else { return 0 }
        let elapsed = Date().timeIntervalSince(changedAt)
        let remainingSeconds = (30 * 86400) - elapsed
        return max(1, Int(ceil(remainingSeconds / 86400)))
    }
    
    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    init() {
        startListeningToAuthState()
        Task { [weak self] in
            await self?.restoreSession()
        }
    }
    
    deinit {
        authStateTask?.cancel()
    }
    
    // MARK: - Auth State Lifecycle
    
    private func startListeningToAuthState() {
        authStateTask = Task { [weak self] in
            for await state in SupabaseManager.shared.client.auth.authStateChanges {
                guard !Task.isCancelled else { break }
                await self?.handleAuthStateChanged(user: state.session?.user)
            }
        }
    }
    
    private func restoreSession() async {
        do {
            let session = try await client.auth.session
            await handleAuthStateChanged(user: session.user)
        } catch {
            // Brak aktywnej sesji
            currentUser = nil
            currentProfile = nil
            needsUsernameSetup = false
        }
    }
    
    private func handleAuthStateChanged(user: User?) async {
        self.currentUser = user
        if let _ = user {
            await fetchProfile()
        } else {
            self.currentProfile = nil
            self.needsUsernameSetup = false
        }
    }
    
    // MARK: - Profile Management
    
    func fetchProfile() async {
        guard let userId = currentUser?.id else {
            currentProfile = nil
            needsUsernameSetup = false
            return
        }
        
        do {
            let profiles: [UserProfile] = try await client.from("profiles")
                .select()
                .eq("id", value: userId)
                .execute()
                .value
            
            if let profile = profiles.first {
                self.currentProfile = profile
                self.needsUsernameSetup = false
            } else {
                self.currentProfile = nil
                self.needsUsernameSetup = true
            }
        } catch {
            #if DEBUG
            print("fetchProfile error: \(error)")
            #endif
            self.currentProfile = nil
            self.needsUsernameSetup = true
        }
    }
    
    static func isValidUsername(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let regex = "^[a-zA-Z0-9_]{3,20}$"
        return trimmed.range(of: regex, options: .regularExpression) != nil
    }
    
    func checkUsernameAvailability(_ username: String) async throws -> Bool {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidUsername(trimmed) else { return false }
        
        struct CheckUsernameParams: Encodable {
            let check_username: String
        }
        
        let isAvailable: Bool = try await client.rpc(
            "is_username_available",
            params: CheckUsernameParams(check_username: trimmed)
        ).execute().value
        
        return isAvailable
    }
    
    func setupUsername(_ username: String) async throws {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidUsername(trimmed) else {
            throw AuthError.invalidUsernameFormat
        }
        
        guard let user = currentUser else {
            throw AuthError.notAuthenticated
        }
        
        let available = try await checkUsernameAvailability(trimmed)
        guard available else {
            throw AuthError.usernameTaken
        }
        
        struct ProfileInsert: Encodable {
            let id: UUID
            let username: String
            let username_lower: String
        }
        
        let newProfile = ProfileInsert(
            id: user.id,
            username: trimmed,
            username_lower: trimmed.lowercased()
        )
        
        try await client.from("profiles")
            .upsert(newProfile)
            .execute()
        
        await fetchProfile()
    }
    
    func changeUsername(_ newUsername: String) async throws {
        let trimmed = newUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidUsername(trimmed) else {
            throw AuthError.invalidUsernameFormat
        }
        
        guard currentUser != nil else {
            throw AuthError.notAuthenticated
        }
        
        struct ChangeUsernameParams: Encodable {
            let new_username: String
        }
        
        struct ChangeUsernameResult: Decodable {
            let success: Bool
            let error: String?
            let days_left: Int?
        }
        
        let result: ChangeUsernameResult = try await client.rpc(
            "change_username",
            params: ChangeUsernameParams(new_username: trimmed)
        ).execute().value
        
        if !result.success {
            if let days = result.days_left {
                throw AuthError.usernameChangeCooldown(daysLeft: days)
            } else {
                throw AuthError.custom(result.error ?? "Failed to change username")
            }
        }
        
        await fetchProfile()
    }
    
    // MARK: - Sign in with Apple
    
    func generateNonce() -> String {
        let rawNonce = UUID().uuidString + UUID().uuidString
        currentNonce = rawNonce
        return rawNonce
    }
    
    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    func handleAppleAuthorization(authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = appleIDCredential.identityToken,
              let idTokenString = String(data: identityTokenData, encoding: .utf8) else {
            throw AuthError.invalidAppleCredentials
        }
        
        guard let nonce = currentNonce else {
            throw AuthError.invalidNonce
        }
        
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idTokenString,
                nonce: nonce
            )
        )
        
        await handleAuthStateChanged(user: session.user)
    }
    
    // MARK: - Sign in with Google (OAuth)
    
    func signInWithGoogle() async throws {
        guard let callbackURL = URL(string: "flipit://auth-callback") else { return }
        
        let authURL = try await client.auth.getOAuthSignInURL(
            provider: .google,
            redirectTo: callbackURL
        )
        
        #if canImport(AuthenticationServices) && canImport(UIKit)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "flipit"
            ) { [weak self] returnURL, error in
                if let error = error {
                    if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                
                guard let returnURL = returnURL else {
                    continuation.resume(returning: ())
                    return
                }
                
                Task { @MainActor [weak self] in
                    guard let self = self else {
                        continuation.resume(returning: ())
                        return
                    }
                    do {
                        let newSession = try await self.client.auth.session(from: returnURL)
                        await self.handleAuthStateChanged(user: newSession.user)
                        continuation.resume(returning: ())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            session.presentationContextProvider = WebAuthPresentationProvider.shared
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
        #endif
    }
    
    func handleOpenURL(_ url: URL) async {
        guard url.scheme == "flipit" && url.host == "auth-callback" else { return }
        do {
            let session = try await client.auth.session(from: url)
            await handleAuthStateChanged(user: session.user)
        } catch {
            #if DEBUG
            print("Failed to restore session from URL: \(error)")
            #endif
        }
    }
    
    // MARK: - Email OTP (Passwordless)
    
    func sendEmailOTP(email: String) async throws {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try await client.auth.signInWithOTP(
            email: trimmed,
            redirectTo: URL(string: "flipit://auth-callback"),
            shouldCreateUser: true
        )
    }
    
    func verifyEmailOTP(email: String, token: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let session = try await client.auth.verifyOTP(
            email: trimmedEmail,
            token: trimmedToken,
            type: .email
        )
        await handleAuthStateChanged(user: session.user)
    }
    
    // MARK: - Sign Out & Delete Account
    
    func signOut() async throws {
        try await client.auth.signOut()
        currentUser = nil
        currentProfile = nil
        needsUsernameSetup = false
    }
    
    func deleteAccount() async throws {
        guard currentUser != nil else { return }
        
        struct DeleteAccountResult: Decodable {
            let success: Bool
            let error: String?
        }
        
        let result: DeleteAccountResult = try await client.rpc("delete_my_account").execute().value
        if !result.success {
            throw AuthError.custom(result.error ?? "Failed to delete account")
        }
        
        try await client.auth.signOut()
        currentUser = nil
        currentProfile = nil
        needsUsernameSetup = false
    }
}
