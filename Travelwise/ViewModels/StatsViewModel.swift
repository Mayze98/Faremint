import SwiftUI
import SwiftData

@Observable
final class StatsViewModel {
    var selectedTripID: PersistentIdentifier?

    func trips(from allTrips: [Trip]) -> [Trip] {
        let currentYear = Calendar.current.component(.year, from: .now)
        return allTrips.filter {
            Calendar.current.component(.year, from: $0.startDate) == currentYear && !$0.isPast
        }
    }

    func selectedTrip(from allTrips: [Trip]) -> Trip? {
        guard let id = selectedTripID else { return nil }
        return trips(from: allTrips).first { $0.persistentModelID == id }
    }

    func relevantExpenses(from allTrips: [Trip]) -> [Expense] {
        if let trip = selectedTrip(from: allTrips) {
            return trip.expenses
        }
        return trips(from: allTrips).flatMap(\.expenses)
    }

    func totalExpenses(from allTrips: [Trip]) -> Double {
        relevantExpenses(from: allTrips).reduce(0) { $0 + $1.amount }
    }

    func displayCurrency(from allTrips: [Trip], defaultCode: String) -> String {
        selectedTrip(from: allTrips)?.currency ?? defaultCode
    }

    func categoryTotals(from allTrips: [Trip]) -> [CategoryTotal] {
        var totals: [String: Double] = [:]
        for expense in relevantExpenses(from: allTrips) {
            totals[expense.categoryName, default: 0] += expense.amount
        }
        let grandTotal = totals.values.reduce(0, +)
        return totals.map { name, total in
            CategoryTotal(
                name: name,
                total: total,
                percentage: grandTotal > 0 ? (total / grandTotal) * 100 : 0
            )
        }.sorted { $0.total > $1.total }
    }

    func expensesByCategory(from allTrips: [Trip]) -> [(category: String, systemImage: String, expenses: [Expense], total: Double)] {
        guard let trip = selectedTrip(from: allTrips) else { return [] }
        let grouped = Dictionary(grouping: trip.expenses) { $0.categoryName }
        return trip.categories.compactMap { category in
            guard let expenses = grouped[category.name], !expenses.isEmpty else { return nil }
            let total = expenses.reduce(0) { $0 + $1.amount }
            return (category.name, category.systemImage, expenses.sorted { $0.createdAt > $1.createdAt }, total)
        }.sorted { $0.total > $1.total }
    }

    func selectTrip(_ trip: Trip) {
        selectedTripID = trip.persistentModelID
    }

    func clearFilter() {
        selectedTripID = nil
    }
}
