import SwiftUI

struct ChangeUsernameSheet: View {
    @ObservedObject var authManager: AuthManager = .shared
    @Environment(\.dismiss) var dismiss
    
    @State private var newUsernameInput: String = ""
    @State private var isChecking: Bool = false
    @State private var isAvailable: Bool? = nil
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var checkTask: Task<Void, Never>? = nil
    @State private var showConfirmDialog: Bool = false
    
    var isValidFormat: Bool {
        AuthManager.isValidUsername(newUsernameInput)
    }
    
    var isDifferentFromCurrent: Bool {
        newUsernameInput.lowercased() != (authManager.username ?? "").lowercased()
    }
    
    var canSubmit: Bool {
        authManager.canChangeUsername && isValidFormat && isDifferentFromCurrent && isAvailable == true && !isSubmitting
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if !authManager.canChangeUsername {
                    cooldownNoticeView
                } else {
                    changeUsernameFormView
                }
            }
            .padding(.top, 16)
            .background(Color.appGroupedBackground.ignoresSafeArea())
            .navigationTitle("Change Username")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
            }
            .confirmationDialog(
                "Change Username?",
                isPresented: $showConfirmDialog,
                titleVisibility: .visible
            ) {
                Button("Confirm Change", role: .none) {
                    submitUsernameChange()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Your current username '@\(authManager.username ?? "")' will enter a 60-day quarantine. You will not be able to change your username again for 30 days.")
            }
        }
    }
    
    // MARK: - Cooldown View
    
    private var cooldownNoticeView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Image(systemName: "hourglass.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.orange)
                    .padding(.top, 24)
                
                VStack(spacing: 8) {
                    Text("Username Change on Cooldown")
                        .font(.title3.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("Usernames can only be changed once every 30 days.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                
                VStack(spacing: 6) {
                    Text("Days remaining:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("\(authManager.daysUntilUsernameChange)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.orange)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.appSecondaryGroupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
                
                Button("Done") {
                    dismiss()
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
    }
    
    // MARK: - Change Username Form
    
    private var changeUsernameFormView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current Username")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(authManager.formattedHandle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("New Username")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack {
                        Text("@")
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                        
                        TextField("new_username", text: $newUsernameInput)
                            .font(.title3)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .onChange(of: newUsernameInput) { _, newValue in
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
                    
                    statusCaptionView
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("30-day cooldown applies after changing", systemImage: "clock")
                        .fixedSize(horizontal: false, vertical: true)
                    Label("Old username enters 60-day quarantine", systemImage: "shield")
                        .fixedSize(horizontal: false, vertical: true)
                    Label("Decks you published will update automatically", systemImage: "arrow.triangle.2.circlepath")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 4)
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 20)
                }
                
                Button(action: {
                    showConfirmDialog = true
                }) {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Change Username")
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
    }
    
    private var borderColor: Color {
        if newUsernameInput.isEmpty {
            return Color.clear
        }
        if !isValidFormat {
            return Color.red.opacity(0.6)
        }
        if !isDifferentFromCurrent {
            return Color.orange.opacity(0.6)
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
        if newUsernameInput.isEmpty {
            EmptyView()
        } else if !isValidFormat {
            Text("Must be 3-20 characters: letters, numbers, and underscores only.")
                .font(.caption)
                .foregroundStyle(.red)
        } else if !isDifferentFromCurrent {
            Text("This is already your current username.")
                .font(.caption)
                .foregroundStyle(.orange)
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
        
        guard trimmed.lowercased() != (authManager.username ?? "").lowercased() else {
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
    
    private func submitUsernameChange() {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.changeUsername(newUsernameInput)
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
