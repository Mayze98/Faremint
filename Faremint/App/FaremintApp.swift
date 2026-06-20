import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAuth

@main
struct FaremintApp: App {
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
                // Called whenever Firebase resolves the auth state — on launch,
                // sign-in, sign-out, and account switches.
                .onChange(of: authService.currentUser?.uid) { _, newUID in
                    handleAuthChange(newUID: newUID)
                }
                // Also fire on first appearance in case onChange misses the
                // initial value set during app launch (Firebase restores cached
                // sessions synchronously before the first onChange can attach).
                .onChange(of: authService.isLoading) { _, isLoading in
                    guard !isLoading else { return }
                    handleAuthChange(newUID: authService.currentUser?.uid)
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

    /// Central handler for every auth state transition, including app launch.
    @MainActor
    private func handleAuthChange(newUID: String?) {
        if let newUID {
            // Determine whether the store already holds this user's data.
            // If not, pass clearFirst:true so the wipe and the Firestore fetch
            // happen inside the same serial Task with no gap between them.
            let needsClear = firestoreService.loadedUID != newUID
            Task { @MainActor in
                await firestoreService.syncFromFirestore(
                    context: container.mainContext,
                    clearFirst: needsClear
                )
            }
        } else {
            firestoreService.clearLocalData(context: container.mainContext)
        }
    }
}
