import SwiftUI
import SwiftData

/// Inline version of trip detail shown directly in the entries tab
struct TripDetailInlineView: View {
    @Bindable var trip: Trip
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreKitService.self) private var storeKitService
    @Environment(FirestoreService.self) private var firestoreService
    @AppStorage("currencyCode") private var homeCurrency = "CAD"
    @State private var showingAddExpense = false
    @State private var showingRebalanceSheet = false
    @State private var rebalanceSuggestions: [RebalanceSuggestion] = []

    // Live query so the list updates immediately when expenses are added/deleted
    @Query private var expenses: [Expense]

    init(trip: Trip) {
        self.trip = trip
        let id = trip.persistentModelID
        _expenses = Query(
            filter: #Predicate<Expense> { $0.trip?.persistentModelID == id },
            sort: \.createdAt, order: .reverse
        )
    }

    private var totalSpent: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    private var budgetProgress: Double {
        guard trip.budget > 0 else { return 0 }
        return min(totalSpent / trip.budget, 1.0)
    }

    private var expensesByCategory: [(category: String, expenses: [Expense], total: Double, limit: Double?)] {
        let grouped = Dictionary(grouping: expenses) { $0.categoryName }
        return trip.categories.compactMap { category in
            guard let catExpenses = grouped[category.name], !catExpenses.isEmpty else { return nil }
            let total = catExpenses.reduce(0) { $0 + $1.amount }
            return (category.name, catExpenses, total, category.budgetLimit)
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
                            Text(CurrencyHelper.format(totalSpent, code: homeCurrency))
                                .font(.title2.weight(.bold))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Budget")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(CurrencyHelper.format(trip.budget, code: homeCurrency))
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    ProgressView(value: budgetProgress)
                        .tint(budgetProgress > 0.9 ? .red : (budgetProgress > 0.7 ? .orange : Theme.accentTeal))

                    HStack {
                        Text("\(Int(budgetProgress * 100))% used")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(CurrencyHelper.format(max(0, trip.budget - totalSpent), code: homeCurrency)) remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Pro: rebalance button when any category is overspent
                    if storeKitService.isProUser {
                        let suggestions = BudgetRebalancer.rebalance(trip: trip)
                        if !suggestions.isEmpty {
                            Button {
                                rebalanceSuggestions = suggestions
                                showingRebalanceSheet = true
                            } label: {
                                Label("Rebalance Budget", systemImage: "arrow.triangle.branch")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Theme.accentTeal)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)
                        }
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
                                ExpenseDetailView(expense: expense, currencyCode: homeCurrency, categories: trip.categories)
                            } label: {
                                ExpenseRowView(expense: expense, currencyCode: homeCurrency)
                            }
                            .tint(.primary)
                        }
                    } header: {
                        categoryHeader(for: group)
                    }
                }
            }
        }
        .contentMargins(.top, 0, for: .scrollContent)
        .sheet(isPresented: $showingRebalanceSheet) {
            BudgetRebalanceSheet(trip: trip, suggestions: rebalanceSuggestions)
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
                Text("\(CurrencyHelper.format(group.total, code: homeCurrency)) / \(CurrencyHelper.format(limit, code: homeCurrency))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(group.total > limit ? .red : .secondary)
            } else {
                Text(CurrencyHelper.format(group.total, code: homeCurrency))
                    .font(.caption.weight(.semibold))
            }
        }
    }
}
