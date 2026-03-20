import SwiftUI
import SwiftData

@Observable
final class TripDetailViewModel {
    let trip: Trip

    init(trip: Trip) {
        self.trip = trip
    }

    func deleteExpense(_ expense: Expense, modelContext: ModelContext, firestoreService: FirestoreService) {
        firestoreService.deleteExpense(firestoreID: expense.firestoreID, tripFirestoreID: trip.firestoreID)
        modelContext.delete(expense)
        // Re-evaluate thresholds so UserDefaults keys reset if spend dropped below a threshold
        NotificationService.shared.checkBudgetThresholds(for: trip)
    }

    func deleteTrip(modelContext: ModelContext, firestoreService: FirestoreService) {
        NotificationService.shared.clearNotificationState(for: trip)
        firestoreService.deleteTrip(firestoreID: trip.firestoreID)
        modelContext.delete(trip)
    }

    func moveToPast() {
        trip.endDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)
    }
}
