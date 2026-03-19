import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel = AuthViewModel()
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case firstName, lastName, phone, email, password, confirmPassword
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 40)

                    // App branding
                    VStack(spacing: 12) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 56))
                            .foregroundStyle(Theme.accentTeal)

                        Text("Travelwise")
                            .font(.largeTitle.weight(.bold))

                        Text(viewModel.isSignUp ? "Create your account" : "Welcome back")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Form fields
                    VStack(spacing: 16) {
                        // Name fields (sign-up only)
                        if viewModel.isSignUp {
                            HStack(spacing: 12) {
                                formField(label: "First Name", placeholder: "John", text: $viewModel.firstName, field: .firstName)
                                    .textContentType(.givenName)

                                formField(label: "Last Name", placeholder: "Doe", text: $viewModel.lastName, field: .lastName)
                                    .textContentType(.familyName)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))

                            // Phone
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Phone Number")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                TextField("+1 (555) 123-4567", text: $viewModel.phoneNumber)
                                    .textContentType(.telephoneNumber)
                                    .keyboardType(.phonePad)
                                    .focused($focusedField, equals: .phone)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Email
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            TextField("you@example.com", text: $viewModel.email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .email)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        }

                        // Password
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            SecureField("At least 6 characters", text: $viewModel.password)
                                .textContentType(viewModel.isSignUp ? .newPassword : .password)
                                .focused($focusedField, equals: .password)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        }

                        // Confirm password (sign-up only)
                        if viewModel.isSignUp {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Confirm Password")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                SecureField("Re-enter password", text: $viewModel.confirmPassword)
                                    .textContentType(.newPassword)
                                    .focused($focusedField, equals: .confirmPassword)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.horizontal, 24)

                    // Error message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .transition(.opacity)
                    }

                    // Submit button
                    Button {
                        focusedField = nil
                        Task {
                            await viewModel.submit(authService: authService)
                        }
                    } label: {
                        Group {
                            if viewModel.isProcessing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(viewModel.isSignUp ? "Create Account" : "Sign In")
                                    .font(.headline)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            viewModel.canSubmit && !viewModel.isProcessing
                                ? Theme.accentTeal
                                : Color(.systemGray4),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                    }
                    .disabled(!viewModel.canSubmit || viewModel.isProcessing)
                    .padding(.horizontal, 24)

                    // Toggle sign-in / sign-up
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.toggleMode()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.isSignUp ? "Already have an account?" : "Don't have an account?")
                                .foregroundStyle(.secondary)
                            Text(viewModel.isSignUp ? "Sign in" : "Sign up")
                                .foregroundStyle(Theme.accentTeal)
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }

                    Spacer()
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isSignUp)
        .animation(.easeInOut(duration: 0.3), value: viewModel.errorMessage)
    }

    private func formField(label: String, placeholder: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .focused($focusedField, equals: field)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthService())
        .fontDesign(.rounded)
}
