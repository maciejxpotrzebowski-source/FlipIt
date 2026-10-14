import SwiftUI

struct UserProfileSection: View {
    var store: FlipItStore? = nil
    @ObservedObject var authManager: AuthManager = .shared
    var onOpenAuth: () -> Void = {}
    var onOpenChangeUsername: () -> Void = {}
    
    @State private var showSignOutDialog: Bool = false
    @State private var showConfirmRemoveDataAlert: Bool = false
    @State private var showDeleteAccountAlert: Bool = false
    @State private var isDeletingAccount: Bool = false
    @State private var isSigningOut: Bool = false
    
    var body: some View {
        Section(header: Text("Account")) {
            if authManager.isAuthenticated {
                authenticatedContent
            } else {
                unauthenticatedContent
            }
        }
        .confirmationDialog(
            "Sign Out",
            isPresented: $showSignOutDialog,
            titleVisibility: .visible
        ) {
            Button("Keep on Device") {
                performSignOut(keepLocalData: true)
            }
            Button("Remove from Device", role: .destructive) {
                showConfirmRemoveDataAlert = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Do you want to keep your flashcards on this device, or remove local data?")
        }
        .alert("Remove Local Data?", isPresented: $showConfirmRemoveDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove Everything", role: .destructive) {
                performSignOut(keepLocalData: false)
            }
        } message: {
            Text("All flashcards and learning progress will be permanently deleted from this device. Decks already published in Community will remain safely in the cloud.")
        }
        .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Forever", role: .destructive) {
                isDeletingAccount = true
                Task {
                    try? await authManager.deleteAccount()
                    await MainActor.run {
                        isDeletingAccount = false
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete your account? Your username will enter a 60-day quarantine and your cloud profile will be removed. This action cannot be undone.")
        }
    }
    
    // MARK: - Authenticated Content
    
    @ViewBuilder
    private var authenticatedContent: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                
                Text(initials)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(authManager.formattedHandle.isEmpty ? "FlipIt User" : authManager.formattedHandle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                if let email = authManager.userEmail, !email.isEmpty {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        
        Button(action: {
            onOpenChangeUsername()
        }) {
            HStack {
                Label("Change Username", systemImage: "at")
                Spacer()
                if !authManager.canChangeUsername {
                    Text(String(format: NSLocalizedString("%lldd cooldown", comment: ""), Int64(authManager.daysUntilUsernameChange)))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        
        Button(role: .none, action: {
            showSignOutDialog = true
        }) {
            HStack {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(Color.red)
                Spacer()
                if isSigningOut {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .disabled(isSigningOut)
        
        Button(role: .destructive, action: {
            showDeleteAccountAlert = true
        }) {
            HStack {
                Label("Delete Account", systemImage: "trash")
                    .foregroundStyle(Color.red.opacity(0.8))
                
                Spacer()
                
                if isDeletingAccount {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }
    
    // MARK: - Sign Out Action
    
    private func performSignOut(keepLocalData: Bool) {
        isSigningOut = true
        Task {
            try? await authManager.signOut()
            await MainActor.run {
                if !keepLocalData {
                    store?.resetToInitialState()
                    #if canImport(UIKit)
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    #endif
                } else {
                    #if canImport(UIKit)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    #endif
                }
                isSigningOut = false
            }
        }
    }
    
    // MARK: - Unauthenticated Content
    
    @ViewBuilder
    private var unauthenticatedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sign in to FlipIt")
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Text("Back up your flashcards in the cloud, sync study progress, and publish decks under your unique username.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        
        Button(action: {
            onOpenAuth()
        }) {
            HStack {
                Image(systemName: "person.crop.circle.badge.plus")
                Text("Sign In or Create Account")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(Color.blue)
        }
    }
    
    private var initials: String {
        if let username = authManager.username, !username.isEmpty {
            return String(username.prefix(1)).uppercased()
        }
        if let email = authManager.userEmail, !email.isEmpty {
            return String(email.prefix(1)).uppercased()
        }
        return "F"
    }
}
