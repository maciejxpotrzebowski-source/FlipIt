import SwiftUI

struct UsernameSetupSheet: View {
    @ObservedObject var authManager: AuthManager = .shared
    @Environment(\.dismiss) var dismiss
    
    @State private var usernameInput: String = ""
    @State private var isChecking: Bool = false
    @State private var isAvailable: Bool? = nil
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var checkTask: Task<Void, Never>? = nil
    
    var isValidFormat: Bool {
        AuthManager.isValidUsername(usernameInput)
    }
    
    var canSubmit: Bool {
        isValidFormat && isAvailable == true && !isSubmitting
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "at.badge.plus")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.blue)
                            .padding(.top, 16)
                        
                        Text("Choose Your Username")
                            .font(.title2.bold())
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("Your unique handle will identify you in the FlipIt Community and when sharing decks.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 20)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("@")
                                .font(.title3.bold())
                                .foregroundStyle(.secondary)
                            
                            TextField("username", text: $usernameInput)
                                .font(.title3)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .onChange(of: usernameInput) { _, newValue in
                                    handleUsernameChange(newValue)
                                }
                            
                            if isChecking {
                                ProgressView()
                                    .controlSize(.small)
                            } else if let available = isAvailable {
                                Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(available ? Color.green : Color.red)
                            }
                        }
                        .padding(14)
                        .background(Color.appSecondaryGroupedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(borderColor, lineWidth: 1.5)
                        )
                        
                        // Status description
                        statusCaptionView
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Username Rules:")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Label("3 to 20 characters", systemImage: "checkmark.circle")
                            .fixedSize(horizontal: false, vertical: true)
                        Label("Letters, numbers, and underscores only", systemImage: "checkmark.circle")
                            .fixedSize(horizontal: false, vertical: true)
                        Label("Can be changed once every 30 days", systemImage: "checkmark.circle")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 20)
                    }
                    
                    Button(action: {
                        submitUsername()
                    }) {
                        HStack(spacing: 8) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Save Username")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSubmit ? Color.blue : Color.gray.opacity(0.4))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!canSubmit)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .background(Color.appGroupedBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sign Out") {
                        Task {
                            try? await authManager.signOut()
                            dismiss()
                        }
                    }
                    .foregroundStyle(.red)
                }
            }
        }
    }
    
    private var borderColor: Color {
        if usernameInput.isEmpty {
            return Color.clear
        }
        if !isValidFormat {
            return Color.red.opacity(0.6)
        }
        if isAvailable == true {
            return Color.green.opacity(0.8)
        }
        if isAvailable == false {
            return Color.red.opacity(0.8)
        }
        return Color.clear
    }
    
    @ViewBuilder
    private var statusCaptionView: some View {
        if usernameInput.isEmpty {
            Text("Enter a username between 3 and 20 characters.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if !isValidFormat {
            Text("Must be 3-20 characters: letters, numbers, and underscores only.")
                .font(.caption)
                .foregroundStyle(.red)
        } else if isChecking {
            Text("Checking availability...")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if isAvailable == true {
            Text("Username is available!")
                .font(.caption)
                .foregroundStyle(.green)
        } else if isAvailable == false {
            Text("This username is already taken or in quarantine.")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
    
    private func handleUsernameChange(_ newValue: String) {
        checkTask?.cancel()
        errorMessage = nil
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard AuthManager.isValidUsername(trimmed) else {
            isAvailable = nil
            isChecking = false
            return
        }
        
        isChecking = true
        isAvailable = nil
        
        checkTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            
            do {
                let available = try await authManager.checkUsernameAvailability(trimmed)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.isAvailable = available
                    self.isChecking = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.isAvailable = nil
                    self.isChecking = false
                }
            }
        }
    }
    
    private func submitUsername() {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.setupUsername(usernameInput)
                await MainActor.run {
                    isSubmitting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
