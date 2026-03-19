import SwiftUI
import SwiftData

@Observable
final class TripDetailViewModel {
    let trip: Trip

    init(trip: Trip) {
        self.trip = trip
    }

    var budgetProgress: Double {
        guard trip.budget > 0 else { return 0 }
        return min(trip.totalSpent / trip.budget, 1.0)
    }

    var expensesByCategory: [(category: String, expenses: [Expense], total: Double, limit: Double?)] {
        let grouped = Dictionary(grouping: trip.expenses) { $0.categoryName }
        return trip.categories.compactMap { category in
            guard let expenses = grouped[category.name], !expenses.isEmpty else { return nil }
            let total = expenses.reduce(0) { $0 + $1.amount }
            return (category.name, expenses.sorted { $0.createdAt > $1.createdAt }, total, category.budgetLimit)
        }.sorted { $0.total > $1.total }
    }

    func deleteExpense(_ expense: Expense, modelContext: ModelContext, firestoreService: FirestoreService) {
        firestoreService.deleteExpense(firestoreID: expense.firestoreID, tripFirestoreID: trip.firestoreID)
        modelContext.delete(expense)
    }

    func deleteTrip(modelContext: ModelContext, firestoreService: FirestoreService) {
        firestoreService.deleteTrip(firestoreID: trip.firestoreID)
        modelContext.delete(trip)
    }

    func moveToPast() {
        trip.endDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)
    }
}
