import SwiftUI
import SwiftData

/// Inline version of trip detail shown directly in the entries tab
struct TripDetailInlineView: View {
    @Bindable var trip: Trip
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddExpense = false

    private var budgetProgress: Double {
        guard trip.budget > 0 else { return 0 }
        return min(trip.totalSpent / trip.budget, 1.0)
    }

    private var expensesByCategory: [(category: String, expenses: [Expense], total: Double, limit: Double?)] {
        let grouped = Dictionary(grouping: trip.expenses) { $0.categoryName }
        return trip.categories.compactMap { category in
            guard let expenses = grouped[category.name], !expenses.isEmpty else { return nil }
            let total = expenses.reduce(0) { $0 + $1.amount }
            return (category.name, expenses.sorted { $0.createdAt > $1.createdAt }, total, category.budgetLimit)
        }.sorted { $0.total > $1.total }
    }

    var body: some View {
        List {
            // Budget overview
            Section {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Spent")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(CurrencyHelper.format(trip.totalSpent, code: trip.currency))
                                .font(.title2.weight(.bold))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Budget")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(CurrencyHelper.format(trip.budget, code: trip.currency))
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    ProgressView(value: budgetProgress)
                        .tint(budgetProgress > 0.9 ? .red : (budgetProgress > 0.7 ? .orange : Theme.accentTeal))

                    HStack {
                        Text("\(Int(trip.budgetUsedPercent))% used")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(CurrencyHelper.format(max(0, trip.budget - trip.totalSpent), code: trip.currency)) remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            // Expenses
            if expensesByCategory.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.title)
                            .foregroundStyle(.tertiary)
                        Text("No expenses yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                ForEach(expensesByCategory, id: \.category) { group in
                    Section {
                        ForEach(group.expenses) { expense in
                            NavigationLink {
                                ExpenseDetailView(expense: expense, currencyCode: trip.currency, categories: trip.categories)
                            } label: {
                                ExpenseRowView(expense: expense, currencyCode: trip.currency)
                            }
                            .tint(.primary)
                        }
                    } header: {
                        categoryHeader(for: group)
                    }
                }
            }
        }
    }

    private func categoryHeader(for group: (category: String, expenses: [Expense], total: Double, limit: Double?)) -> some View {
        HStack {
            let cat = trip.categories.first { $0.name == group.category }
            Image(systemName: cat?.systemImage ?? "tag.fill")
                .foregroundStyle(Theme.colorForCategory(group.category))
            Text(group.category)

            if let limit = group.limit, group.total > limit {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption2)
            }

            Spacer()

            if let limit = group.limit {
                Text("\(CurrencyHelper.format(group.total, code: trip.currency)) / \(CurrencyHelper.format(limit, code: trip.currency))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(group.total > limit ? .red : .secondary)
            } else {
                Text(CurrencyHelper.format(group.total, code: trip.currency))
                    .font(.caption.weight(.semibold))
            }
        }
    }
}
