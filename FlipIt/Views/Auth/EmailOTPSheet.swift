import SwiftUI

struct EmailOTPSheet: View {
    @ObservedObject var authManager: AuthManager = .shared
    @Environment(\.dismiss) var dismiss
    
    @State private var email: String = ""
    @State private var otpCode: String = ""
    @State private var step: OTPStep = .enterEmail
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var resendCooldown: Int = 0
    @State private var timer: Timer? = nil
    
    enum OTPStep {
        case enterEmail
        case enterCode
    }
    
    var isValidEmail: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && trimmed.contains(".") && trimmed.count >= 5
    }
    
    var isValidCode: Bool {
        let trimmed = otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count == 6
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    switch step {
                    case .enterEmail:
                        emailInputView
                    case .enterCode:
                        codeVerificationView
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Color.appGroupedBackground.ignoresSafeArea())
            .navigationTitle("Sign in with Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuthed in
                if isAuthed {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Step 1: Email Input
    
    private var emailInputView: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 52))
                .foregroundStyle(Color.blue)
                .padding(.top, 8)
            
            VStack(spacing: 8) {
                Text("Passwordless Sign In")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("We'll send a 6-digit confirmation code to your email. No password needed.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Email Address")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(.secondary)
                    
                    TextField("you@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
                .padding(14)
                .background(Color.appSecondaryGroupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Button(action: {
                sendCode()
            }) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Send Code")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isValidEmail && !isLoading ? Color.blue : Color.gray.opacity(0.4))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!isValidEmail || isLoading)
            .padding(.top, 8)
        }
    }
    
    // MARK: - Step 2: Code Verification
    
    private var codeVerificationView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 52))
                .foregroundStyle(Color.green)
                .padding(.top, 8)
            
            VStack(spacing: 8) {
                Text("Enter 6-Digit Code")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("We sent an activation code to")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(email)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            VStack(spacing: 8) {
                TextField("000000", text: $otpCode)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .padding(14)
                    .background(Color.appSecondaryGroupedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onChange(of: otpCode) { _, newValue in
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered.count > 6 {
                            otpCode = String(filtered.prefix(6))
                        } else {
                            otpCode = filtered
                        }
                        if otpCode.count == 6 {
                            verifyCode()
                        }
                    }
                
                Text("Enter the 6-digit code from your email")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    sendCode()
                }) {
                    if resendCooldown > 0 {
                        Text(String(format: NSLocalizedString("Resend in %llds", comment: ""), Int64(resendCooldown)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Resend Code")
                            .font(.caption.bold())
                            .foregroundStyle(Color.blue)
                    }
                }
                .disabled(resendCooldown > 0 || isLoading)
                
                Text("•")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button("Use Different Email") {
                    step = .enterEmail
                    errorMessage = nil
                    otpCode = ""
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Button(action: {
                verifyCode()
            }) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Verify and Sign In")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isValidCode && !isLoading ? Color.green : Color.gray.opacity(0.4))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!isValidCode || isLoading)
            .padding(.top, 8)
        }
    }
    
    // MARK: - Actions
    
    private func sendCode() {
        guard isValidEmail else { return }
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.sendEmailOTP(email: email)
                await MainActor.run {
                    isLoading = false
                    step = .enterCode
                    startResendTimer()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func verifyCode() {
        guard isValidCode else { return }
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.verifyEmailOTP(email: email, token: otpCode)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func startResendTimer() {
        resendCooldown = 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if self.resendCooldown > 0 {
                    self.resendCooldown -= 1
                } else {
                    self.timer?.invalidate()
                    self.timer = nil
                }
            }
        }
    }
}
