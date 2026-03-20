import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAuth

@main
struct TravelwiseApp: App {
    @State private var authService: AuthService
    @State private var firestoreService = FirestoreService()
    let container: ModelContainer

    init() {
        FirebaseApp.configure()
        _authService = State(initialValue: AuthService())
        container = try! ModelContainer(for: Trip.self, Expense.self)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
                .environment(firestoreService)
                .onAppear {
                    NotificationService.shared.requestAuthorization()
                }
                // Watch the current user's UID so we catch every transition:
                //   - user A → nil  (sign-out): clear local data
                //   - nil → user B  (sign-in):  sync from Firestore
                //   - user A → user B (unlikely but safe): clear then sync
                .onChange(of: authService.currentUser?.uid) { oldUID, newUID in
                    if let newUID {
                        // A different user just signed in — clear any stale local data
                        // left by the previous session before syncing the new user's data.
                        if oldUID != newUID {
                            firestoreService.clearLocalData(context: container.mainContext)
                        }
                        Task {
                            await firestoreService.syncFromFirestore(
                                context: container.mainContext
                            )
                        }
                    } else {
                        // Signed out — clear local data immediately.
                        firestoreService.clearLocalData(context: container.mainContext)
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
