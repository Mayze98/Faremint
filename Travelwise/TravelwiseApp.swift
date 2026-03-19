import SwiftUI
import SwiftData
import FirebaseCore

@main
struct TravelwiseApp: App {
    @State private var authService: AuthService

    init() {
        FirebaseApp.configure()
        _authService = State(initialValue: AuthService())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
        }
        .modelContainer(for: [Trip.self, Expense.self])
    }
}
