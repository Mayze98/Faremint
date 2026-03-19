import SwiftUI
import SwiftData

@Observable
final class TripDetailViewModel {
    let trip: Trip

    init(trip: Trip) {
        self.trip = trip
    }

    func deleteExpense(_ expense: Expense, modelContext: ModelContext, firestoreService: FirestoreService, notificationService: NotificationService) {
        firestoreService.deleteExpense(firestoreID: expense.firestoreID, tripFirestoreID: trip.firestoreID)
        modelContext.delete(expense)
        // Re-evaluate thresholds so UserDefaults keys reset if spend dropped below a threshold
        notificationService.checkBudgetThresholds(for: trip)
    }

    func deleteTrip(modelContext: ModelContext, firestoreService: FirestoreService, notificationService: NotificationService) {
        notificationService.clearNotificationState(for: trip)
        firestoreService.deleteTrip(firestoreID: trip.firestoreID)
        modelContext.delete(trip)
    }

    func moveToPast() {
        trip.endDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)
    }
}
