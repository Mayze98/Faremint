import SwiftUI
import SwiftData
import FirebaseCore

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
                // Clear local data on sign-out; sync from Firestore on sign-in.
                .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
                    if isAuthenticated {
                        Task {
                            await firestoreService.syncFromFirestore(
                                context: container.mainContext
                            )
                        }
                    } else {
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
