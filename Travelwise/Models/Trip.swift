import Foundation
import SwiftData

@Model
final class Trip {
    var name: String
    var budget: Double
    var currency: String
    var startDate: Date
    var endDate: Date?
    var colorHex: String
    var categories: [ExpenseCategory]
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Expense.trip)
    var expenses: [Expense]

    var totalSpent: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    var budgetUsedPercent: Double {
        guard budget > 0 else { return 0 }
        return (totalSpent / budget) * 100
    }

    init(
        name: String,
        budget: Double,
        currency: String = "USD",
        startDate: Date = .now,
        endDate: Date? = nil,
        colorHex: String = "4ECDC4",
        categories: [ExpenseCategory] = BaseCategory.allCases.map { ExpenseCategory(base: $0) }
    ) {
        self.name = name
        self.budget = budget
        self.currency = currency
        self.startDate = startDate
        self.endDate = endDate
        self.colorHex = colorHex
        self.categories = categories
        self.expenses = []
        self.createdAt = .now
    }
}
