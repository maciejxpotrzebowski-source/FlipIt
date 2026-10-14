import SwiftUI
import AuthenticationServices

struct AuthPromptSheet: View {
    @ObservedObject var authManager: AuthManager = .shared
    @Environment(\.dismiss) var dismiss
    
    var canSkip: Bool = true
    var title: String? = nil
    var subtitle: String? = nil
    
    @State private var showEmailSheet: Bool = false
    @State private var showUsernameSetup: Bool = false
    @State private var isSigningInGoogle: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // MARK: - Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 76, height: 76)
                            
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.system(size: 38))
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 12)
                        
                        Text(title.map { LocalizedStringKey($0) } ?? "Sign In to FlipIt")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text(subtitle.map { LocalizedStringKey($0) } ?? "Log in to save your flashcards in the cloud and never lose your progress.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // MARK: - Feature Bullets
                    VStack(alignment: .leading, spacing: 14) {
                        bulletRow(
                            icon: "icloud.fill",
                            iconColor: .blue,
                            title: "Cloud Backup & Sync",
                            subtitle: "Your decks and review streak stay synchronized across devices."
                        )
                        
                        bulletRow(
                            icon: "sparkles",
                            iconColor: .purple,
                            title: "AI Flashcard Generator",
                            subtitle: "Generate dozens of cards in seconds with AI."
                        )
                        
                        bulletRow(
                            icon: "person.2.fill",
                            iconColor: .green,
                            title: "Community Market",
                            subtitle: "Publish and explore community decks under your unique @username."
                        )
                    }
                    .padding(16)
                    .background(Color.appSecondaryGroupedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.red)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // MARK: - Auth Buttons
                    VStack(spacing: 12) {
                        // 1. Sign in with Apple
                        SignInWithAppleButton(
                            onRequest: { request in
                                let nonce = authManager.generateNonce()
                                request.requestedScopes = [.fullName, .email]
                                request.nonce = authManager.sha256(nonce)
                            },
                            onCompletion: { result in
                                handleAppleCompletion(result)
                            }
                        )
                        .signInWithAppleButtonStyle(.whiteOutline)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // 2. Sign in with Google
                        Button(action: {
                            signInWithGoogle()
                        }) {
                            HStack(spacing: 10) {
                                if isSigningInGoogle {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("G")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.red)
                                }
                                
                                Text("Sign in with Google")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.appSecondaryGroupedBackground)
                            .foregroundStyle(Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                            )
                        }
                        .disabled(isSigningInGoogle)
                        
                        // 3. Continue with Email OTP
                        Button(action: {
                            showEmailSheet = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 16))
                                Text("Sign in with Email Code")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.blue.opacity(0.12))
                            .foregroundStyle(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // 4. Skip Button (if allowed)
                        if canSkip {
                            Button(action: {
                                dismiss()
                            }) {
                                Text("Skip and continue without signing in")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Color.appGroupedBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEmailSheet) {
                EmailOTPSheet(authManager: authManager)
            }
            .sheet(isPresented: $showUsernameSetup) {
                UsernameSetupSheet(authManager: authManager)
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuthed in
                if isAuthed {
                    if authManager.needsUsernameSetup {
                        showUsernameSetup = true
                    } else {
                        dismiss()
                    }
                }
            }
            .onChange(of: authManager.needsUsernameSetup) { _, needsSetup in
                if needsSetup && authManager.isAuthenticated {
                    showUsernameSetup = true
                }
            }
        }
    }
    
    private func bulletRow(icon: String, iconColor: Color, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            Task {
                do {
                    try await authManager.handleAppleAuthorization(authorization: authorization)
                } catch {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func signInWithGoogle() {
        isSigningInGoogle = true
        errorMessage = nil
        Task {
            do {
                try await authManager.signInWithGoogle()
                await MainActor.run {
                    self.isSigningInGoogle = false
                }
            } catch {
                await MainActor.run {
                    self.isSigningInGoogle = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
