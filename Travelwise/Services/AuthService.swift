import Foundation
import FirebaseAuth

@Observable
final class AuthService {
    var currentUser: FirebaseAuth.User?
    var isLoading = true

    var isAuthenticated: Bool {
        currentUser != nil
    }

    var isEmailVerified: Bool {
        currentUser?.isEmailVerified ?? false
    }

    var userEmail: String? {
        currentUser?.email
    }

    var displayName: String? {
        currentUser?.displayName
    }

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
            self?.isLoading = false
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func signUp(email: String, password: String, firstName: String, lastName: String, phoneNumber: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let user = result.user

        // Set display name
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = "\(firstName) \(lastName)"
        try await changeRequest.commitChanges()

        // Send email verification
        try await user.sendEmailVerification()

        currentUser = Auth.auth().currentUser
    }

    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        currentUser = result.user
    }

    func signOut() throws {
        try Auth.auth().signOut()
        currentUser = nil
    }

    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await user.delete()
        currentUser = nil
    }

    func sendEmailVerification() async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await user.sendEmailVerification()
    }

    func reloadUser() async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await user.reload()
        currentUser = Auth.auth().currentUser
    }

    static func friendlyErrorMessage(for error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain else {
            return error.localizedDescription
        }

        switch AuthErrorCode(rawValue: nsError.code) {
        case .emailAlreadyInUse:
            return "This email is already registered. Try signing in instead."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .weakPassword:
            return "Password must be at least 6 characters."
        case .wrongPassword, .invalidCredential:
            return "Incorrect email or password."
        case .userNotFound:
            return "No account found with this email."
        case .networkError:
            return "Network error. Please check your connection."
        case .tooManyRequests:
            return "Too many attempts. Please try again later."
        case .requiresRecentLogin:
            return "Please sign in again before deleting your account."
        default:
            return error.localizedDescription
        }
    }
}
