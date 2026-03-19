import Foundation

@Observable
final class AuthViewModel {
    var email = ""
    var password = ""
    var confirmPassword = ""
    var firstName = ""
    var lastName = ""
    var phoneNumber = ""
    var isSignUp = false
    var errorMessage: String?
    var isProcessing = false

    var canSubmit: Bool {
        let emailValid = !email.trimmingCharacters(in: .whitespaces).isEmpty
        let passwordValid = password.count >= 6
        if isSignUp {
            let nameValid = !firstName.trimmingCharacters(in: .whitespaces).isEmpty
                && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
            let phoneValid = phoneNumber.filter(\.isNumber).count >= 7
            return nameValid && phoneValid && emailValid && passwordValid && password == confirmPassword
        }
        return emailValid && passwordValid
    }

    func submit(authService: AuthService) async {
        errorMessage = nil
        isProcessing = true
        defer { isProcessing = false }

        do {
            if isSignUp {
                try await authService.signUp(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password,
                    firstName: firstName.trimmingCharacters(in: .whitespaces),
                    lastName: lastName.trimmingCharacters(in: .whitespaces),
                    phoneNumber: phoneNumber.trimmingCharacters(in: .whitespaces)
                )
            } else {
                try await authService.signIn(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
            }
        } catch {
            errorMessage = AuthService.friendlyErrorMessage(for: error)
        }
    }

    func toggleMode() {
        isSignUp.toggle()
        errorMessage = nil
        confirmPassword = ""
        firstName = ""
        lastName = ""
        phoneNumber = ""
    }
}
