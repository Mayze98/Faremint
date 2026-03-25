import Foundation

struct RebalanceSuggestion: Identifiable {
    var id: String { categoryName }
    let categoryName: String
    let currentLimit: Double
    let suggestedLimit: Double
    /// Negative value means the limit is being reduced.
    var delta: Double { suggestedLimit - currentLimit }
}

enum BudgetRebalancer {

    /// Computes suggested limit reductions for under-budget categories to absorb
    /// overspending in other categories. Returns an empty array if no rebalancing
    /// is needed or possible.
    static func rebalance(trip: Trip) -> [RebalanceSuggestion] {
        let categoriesWithLimits = trip.categories.filter { $0.budgetLimit != nil }
        guard !categoriesWithLimits.isEmpty else { return [] }

        let expensesByCategory = Dictionary(grouping: trip.expenses) { $0.categoryName }

        var overspendTotal: Double = 0
        var underCategories: [(category: ExpenseCategory, limit: Double, spent: Double)] = []

        for category in categoriesWithLimits {
            guard let limit = category.budgetLimit else { continue }
            let spent = expensesByCategory[category.name]?.reduce(0) { $0 + $1.amount } ?? 0
            if spent > limit {
                overspendTotal += spent - limit
            } else if limit - spent > 0 {
                underCategories.append((category, limit, spent))
            }
        }

        guard overspendTotal > 0, !underCategories.isEmpty else { return [] }

        let totalSlack = underCategories.reduce(0.0) { $0 + ($1.limit - $1.spent) }
        guard totalSlack > 0 else { return [] }

        return underCategories.compactMap { item in
            let slack = item.limit - item.spent
            let proportionalCut = overspendTotal * (slack / totalSlack)
            // Never suggest a limit below what is already spent.
            let newLimit = max(item.spent, (item.limit - proportionalCut).rounded(.down))
            guard newLimit != item.limit else { return nil }
            return RebalanceSuggestion(
                categoryName: item.category.name,
                currentLimit: item.limit,
                suggestedLimit: newLimit
            )
        }
    }

    /// Applies the suggestions to the trip's category budget limits and marks
    /// the trip as updated so SwiftData / Firestore can pick up the changes.
    static func apply(suggestions: [RebalanceSuggestion], to trip: Trip) {
        for suggestion in suggestions {
            if let index = trip.categories.firstIndex(where: { $0.name == suggestion.categoryName }) {
                trip.categories[index].budgetLimit = suggestion.suggestedLimit
            }
        }
        trip.updatedAt = .now
    }
}
