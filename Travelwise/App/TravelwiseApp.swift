import SwiftUI
import SwiftData
import FirebaseCore

@main
struct TravelwiseApp: App {
    @State private var authService: AuthService
    @State private var firestoreService = FirestoreService()
    @State private var notificationService = NotificationService()
    let container: ModelContainer

    init() {
        FirebaseApp.configure()
        _authService = State(initialValue: AuthService())
        // Delete the existing SwiftData store so the new schema (firestoreID,
        // updatedAt) loads cleanly. Data will be restored from Firestore on
        // the first sync after login.
        let storeURL = URL.applicationSupportDirectory
            .appending(path: "default.store")
        try? FileManager.default.removeItem(at: storeURL)

        container = try! ModelContainer(for: Trip.self, Expense.self)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
                .environment(firestoreService)
                .environment(notificationService)
                .onAppear {
                    notificationService.requestAuthorization()
                }
                // Trigger initial sync right after authentication is confirmed.
                .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
                    guard isAuthenticated else { return }
                    Task {
                        await firestoreService.syncFromFirestore(
                            context: container.mainContext
                        )
                    }
                }
                // Re-sync whenever the app returns to the foreground.
                .onReceive(NotificationCenter.default.publisher(
                    for: UIApplication.willEnterForegroundNotification
                )) { _ in
                    guard authService.isAuthenticated else { return }
                    Task {
                        await firestoreService.syncFromFirestore(
                            context: container.mainContext
                        )
                    }
                }
        }
        .modelContainer(container)
    }
}
