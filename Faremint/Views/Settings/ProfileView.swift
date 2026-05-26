import SwiftUI

struct ProfileView: View {
    @Environment(AuthService.self) private var authService
    @State private var showingChangePassword = false

    var body: some View {
        Form {
            Section("Account") {
                LabeledContent("Email") {
                    Text(authService.userEmail ?? "—")
                        .foregroundStyle(.secondary)
                }
                Button("Change Password") {
                    showingChangePassword = true
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingChangePassword) {
            ChangePasswordSheet()
        }
    }
}

// MARK: - Change Password Sheet

private struct ChangePasswordSheet: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @FocusState private var focusedField: Field?

    @State private var isChanging = false
    @State private var errorMessage: String?

    private enum Field { case current, new, confirm }

    private var newPasswordMismatch: Bool {
        !confirmPassword.isEmpty && confirmPassword != newPassword
    }

    private var canSubmit: Bool {
        !currentPassword.isEmpty &&
        newPassword.count >= 6 &&
        newPassword == confirmPassword &&
        !isChanging
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Current password", text: $currentPassword)
                        .textContentType(.password)
                        .focused($focusedField, equals: .current)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .new }

                    SecureField("New password", text: $newPassword)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .new)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .confirm }

                    SecureField("Confirm new password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .confirm)
                        .submitLabel(.done)
                        .onSubmit { if canSubmit { submit() } }
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if newPasswordMismatch {
                            Text("Passwords do not match")
                                .foregroundStyle(.red)
                        }
                        if let error = errorMessage {
                            Text(error)
                                .foregroundStyle(.red)
                        }
                        Text("Must be at least 6 characters.")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submit()
                    } label: {
                        if isChanging {
                            ProgressView()
                        } else {
                            Text("Update")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear { focusedField = .current }
    }

    private func submit() {
        focusedField = nil
        isChanging = true
        errorMessage = nil
        Task {
            do {
                try await authService.changePassword(currentPassword: currentPassword, newPassword: newPassword)
                dismiss()
            } catch {
                errorMessage = AuthService.friendlyErrorMessage(for: error)
                isChanging = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
    .environment(AuthService())
}
