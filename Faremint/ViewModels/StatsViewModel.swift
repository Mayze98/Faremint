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

    // MARK: - Daily Average

    /// Number of elapsed days for the selected context (trip or all trips).
    func elapsedDays(from allTrips: [Trip]) -> Int? {
        if let trip = selectedTrip(from: allTrips) {
            return tripElapsedDays(trip)
        }
        // All-trips mode: span from earliest start to today
        let starts = trips(from: allTrips).map(\.startDate)
        guard let earliest = starts.min() else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: earliest), to: Calendar.current.startOfDay(for: .now)).day ?? 0
        return max(days, 1)
    }

    func dailyAverage(from allTrips: [Trip]) -> Double? {
        guard let days = elapsedDays(from: allTrips), days > 0 else { return nil }
        let total = totalExpenses(from: allTrips)
        guard total > 0 else { return nil }
        return total / Double(days)
    }

    // MARK: - Burn Rate Forecast

    /// Forecasted total spend by end of trip based on current daily average.
    /// Only meaningful when a single active trip with an end date is selected.
    func forecastedTotal(from allTrips: [Trip]) -> Double? {
        guard let trip = selectedTrip(from: allTrips),
              let endDate = trip.endDate,
              !trip.isPast,
              let avg = dailyAverage(from: allTrips) else { return nil }
        let totalDays = Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: trip.startDate),
            to: Calendar.current.startOfDay(for: endDate)).day ?? 0
        guard totalDays > 0 else { return nil }
        return avg * Double(totalDays)
    }

    /// Days remaining in the selected trip. Nil if no trip selected or no end date.
    func daysRemaining(from allTrips: [Trip]) -> Int? {
        guard let trip = selectedTrip(from: allTrips),
              let endDate = trip.endDate,
              !trip.isPast else { return nil }
        let days = Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: endDate)).day ?? 0
        return max(days, 0)
    }

    // MARK: - Spending Over Time

    struct DailySpend: Identifiable {
        let id = UUID()
        let date: Date
        let amount: Double
    }

    /// Returns one DailySpend entry per calendar day that has expenses, for the selected context.
    func dailySpends(from allTrips: [Trip]) -> [DailySpend] {
        let expenses = relevantExpenses(from: allTrips)
        guard !expenses.isEmpty else { return [] }
        let calendar = Calendar.current
        var grouped: [Date: Double] = [:]
        for expense in expenses {
            let day = calendar.startOfDay(for: expense.createdAt)
            grouped[day, default: 0] += expense.amount
        }
        return grouped
            .map { DailySpend(date: $0.key, amount: $0.value) }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Helpers

    private func tripElapsedDays(_ trip: Trip) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: trip.startDate)
        let today = calendar.startOfDay(for: .now)
        let end: Date
        if let tripEnd = trip.endDate, tripEnd < today {
            end = tripEnd
        } else {
            end = today
        }
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(days, 1)
    }

    func selectTrip(_ trip: Trip) {
        selectedTripID = trip.persistentModelID
    }

    func clearFilter() {
        selectedTripID = nil
    }
}
