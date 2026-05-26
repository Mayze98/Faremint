import SwiftUI

struct EmailVerificationView: View {
    @Environment(AuthService.self) private var authService
    @State private var isChecking = false
    @State private var isResending = false
    @State private var errorMessage: String?
    @State private var resendSuccess = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Icon
                Image(systemName: "envelope.badge")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.accentTeal)

                // Title
                VStack(spacing: 8) {
                    Text("Check your email")
                        .font(.title.weight(.bold))

                    Text("We sent a verification link to")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(authService.userEmail ?? "")
                        .font(.subheadline.weight(.semibold))
                }
                .multilineTextAlignment(.center)

                // Instructions
                Text("Tap the link in the email to verify your account, then come back here and tap the button below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Error / success messages
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .transition(.opacity)
                }

                if resendSuccess {
                    Text("Verification email sent!")
                        .font(.caption)
                        .foregroundStyle(Theme.accentTeal)
                        .transition(.opacity)
                }

                // Verify button
                Button {
                    checkVerification()
                } label: {
                    Group {
                        if isChecking {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("I've verified my email")
                                .font(.headline)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Theme.accentTeal, in: RoundedRectangle(cornerRadius: 16))
                }
                .disabled(isChecking)
                .padding(.horizontal, 24)

                // Resend button
                Button {
                    resendVerification()
                } label: {
                    Group {
                        if isResending {
                            ProgressView()
                                .tint(Theme.accentTeal)
                        } else {
                            Text("Resend verification email")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.accentTeal)
                        }
                    }
                }
                .disabled(isResending)

                Spacer()

                // Sign out link
                Button {
                    try? authService.signOut()
                } label: {
                    Text("Sign out")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 32)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: errorMessage)
        .animation(.easeInOut(duration: 0.3), value: resendSuccess)
    }

    private func checkVerification() {
        isChecking = true
        errorMessage = nil
        Task {
            do {
                try await authService.reloadUser()
                if !authService.isEmailVerified {
                    errorMessage = "Email not yet verified. Please check your inbox and tap the link."
                }
            } catch {
                errorMessage = AuthService.friendlyErrorMessage(for: error)
            }
            isChecking = false
        }
    }

    private func resendVerification() {
        isResending = true
        errorMessage = nil
        resendSuccess = false
        Task {
            do {
                try await authService.sendEmailVerification()
                resendSuccess = true
            } catch {
                errorMessage = AuthService.friendlyErrorMessage(for: error)
            }
            isResending = false
        }
    }
}

#Preview {
    EmailVerificationView()
        .environment(AuthService())
        .fontDesign(.rounded)
}
