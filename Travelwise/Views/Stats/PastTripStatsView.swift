import SwiftUI
import SwiftData

struct PastTripStatsView: View {
    @Bindable var trip: Trip
    @AppStorage("currencyCode") private var homeCurrency = "CAD"

    private var totalSpent: Double {
        trip.totalSpent
    }

    private var budgetProgress: Double {
        guard trip.budget > 0 else { return 0 }
        return min(totalSpent / trip.budget, 1.0)
    }

    private var categoryTotals: [CategoryTotal] {
        var totals: [String: Double] = [:]
        for expense in trip.expenses {
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

    private var expensesByCategory: [(category: String, systemImage: String, expenses: [Expense], total: Double, limit: Double?)] {
        let grouped = Dictionary(grouping: trip.expenses) { $0.categoryName }
        return trip.categories.compactMap { category in
            guard let expenses = grouped[category.name], !expenses.isEmpty else { return nil }
            let total = expenses.reduce(0) { $0 + $1.amount }
            return (category.name, category.systemImage, expenses.sorted { $0.createdAt > $1.createdAt }, total, category.budgetLimit)
        }.sorted { $0.total > $1.total }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Budget overview card
                budgetOverview
                    .padding(.horizontal)

                // Total expenses card
                TotalExpensesCard(
                    totalExpenses: totalSpent,
                    currencyCode: homeCurrency,
                    subtitle: trip.name
                )
                .padding(.horizontal)

                // Pie chart
                SpendingPieChart(categoryTotals: categoryTotals)
                    .padding(.horizontal)

                // Category breakdown
                CategoryBreakdownList(categoryTotals: categoryTotals, currencyCode: homeCurrency)
                    .padding(.horizontal)

                // Expenses grouped by category
                if !expensesByCategory.isEmpty {
                    expenseListSection
                        .padding(.horizontal)
                }
            }
            .padding(.top)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var budgetOverview: some View {
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
                Text("\(Int(trip.budgetUsedPercent))% used")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                let remaining = max(0, trip.budget - totalSpent)
                Text("\(CurrencyHelper.format(remaining, code: homeCurrency)) remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Date range
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let endDate = trip.endDate {
                    Text("\(trip.startDate, format: .dateTime.month(.abbreviated).day().year()) – \(endDate, format: .dateTime.month(.abbreviated).day().year())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(trip.startDate, format: .dateTime.month(.abbreviated).day().year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var expenseListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Expenses")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(expensesByCategory, id: \.category) { group in
                    // Category header
                    HStack(spacing: 8) {
                        Image(systemName: group.systemImage)
                            .font(.caption)
                            .foregroundStyle(Theme.colorForCategory(group.category))
                        Text(group.category)
                            .font(.subheadline.weight(.semibold))
                        Spacer()

                        if let limit = group.limit {
                            Text("\(CurrencyHelper.format(group.total, code: homeCurrency)) / \(CurrencyHelper.format(limit, code: homeCurrency))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(group.total > limit ? .red : .secondary)
                        } else {
                            Text(CurrencyHelper.format(group.total, code: homeCurrency))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 14)
                    .padding(.bottom, 6)

                    // Expenses in this category
                    ForEach(group.expenses) { expense in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(expense.title)
                                    .font(.subheadline)
                                Text(expense.createdAt, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Text(CurrencyHelper.format(expense.amount, code: homeCurrency))
                                .font(.subheadline.weight(.medium))
                                .monospacedDigit()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    }

                    if group.category != expensesByCategory.last?.category {
                        Divider()
                            .padding(.horizontal)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .padding(.vertical)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    let trip: Trip = {
        let t = Trip(name: "Japan 2024", budget: 5000, startDate: .now, endDate: .now, colorHex: "FF6B6B")
        SampleData.container.mainContext.insert(t)
        return t
    }()
    NavigationStack {
        PastTripStatsView(trip: trip)
    }
    .modelContainer(SampleData.container)
}
