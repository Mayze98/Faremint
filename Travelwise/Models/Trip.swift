import Foundation
import SwiftData

@Model
final class Trip {
    /// Stable ID used to match this record with its Firestore document.
    /// Set once on creation; never changes.
    var firestoreID: String
    var name: String
    var budget: Double
    var currency: String
    var startDate: Date
    var endDate: Date?
    var colorHex: String
    var categories: [ExpenseCategory]
    var createdAt: Date
    /// Timestamp of the last write so the sync merge can resolve conflicts.
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Expense.trip)
    var expenses: [Expense]

    var totalSpent: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    var budgetUsedPercent: Double {
        guard budget > 0 else { return 0 }
        return (totalSpent / budget) * 100
    }

    var isPast: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        // A trip is past if its end date has fully passed (the day after end date)
        if let endDate {
            let dayAfterEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate))!
            return today >= dayAfterEnd
        }
        // No end date: consider a trip "past" if it started more than 90 days ago.
        let cutoff = calendar.date(byAdding: .day, value: -90, to: today)!
        return startDate < cutoff
    }

    init(
        firestoreID: String = UUID().uuidString,
        name: String,
        budget: Double,
        currency: String = "CAD",
        startDate: Date = .now,
        endDate: Date? = nil,
        colorHex: String = "4ECDC4",
        categories: [ExpenseCategory] = BaseCategory.allCases.map { ExpenseCategory(base: $0) },
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.firestoreID = firestoreID
        self.name = name
        self.budget = budget
        self.currency = currency
        self.startDate = startDate
        self.endDate = endDate
        self.colorHex = colorHex
        self.categories = categories
        self.expenses = []
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
