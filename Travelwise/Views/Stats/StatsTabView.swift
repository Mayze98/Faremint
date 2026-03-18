import SwiftUI
import SwiftData

struct StatsTabView: View {
    @Query(sort: \Trip.createdAt, order: .reverse) private var allTrips: [Trip]
    @AppStorage("currencyCode") private var currencyCode = "CAD"
    @State private var selectedTripID: PersistentIdentifier?

    private var trips: [Trip] {
        let currentYear = Calendar.current.component(.year, from: .now)
        return allTrips.filter {
            Calendar.current.component(.year, from: $0.startDate) == currentYear && !$0.isPast
        }
    }

    private var selectedTrip: Trip? {
        guard let id = selectedTripID else { return nil }
        return trips.first { $0.persistentModelID == id }
    }

    private var relevantExpenses: [Expense] {
        if let trip = selectedTrip {
            return trip.expenses
        }
        return trips.flatMap(\.expenses)
    }

    private var displayCurrency: String {
        selectedTrip?.currency ?? currencyCode
    }

    private var totalExpenses: Double {
        relevantExpenses.reduce(0) { $0 + $1.amount }
    }

    private var expensesByCategory: [(category: String, systemImage: String, expenses: [Expense], total: Double)] {
        guard let trip = selectedTrip else { return [] }
        let grouped = Dictionary(grouping: trip.expenses) { $0.categoryName }
        return trip.categories.compactMap { category in
            guard let expenses = grouped[category.name], !expenses.isEmpty else { return nil }
            let total = expenses.reduce(0) { $0 + $1.amount }
            return (category.name, category.systemImage, expenses.sorted { $0.createdAt > $1.createdAt }, total)
        }.sorted { $0.total > $1.total }
    }

    private var categoryTotals: [CategoryTotal] {
        var totals: [String: Double] = [:]
        for expense in relevantExpenses {
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

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Statistics")
                            .font(.largeTitle.weight(.bold))
                        Text("Your spending overview")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // Trip picker
                    if !trips.isEmpty {
                        ScrollView(.horizontal) {
                            HStack(spacing: 10) {
                                TripFilterChip(
                                    title: "All Trips",
                                    isSelected: selectedTripID == nil
                                ) {
                                    selectedTripID = nil
                                }

                                ForEach(trips) { trip in
                                    TripFilterChip(
                                        title: trip.name,
                                        color: Color(hex: trip.colorHex),
                                        isSelected: selectedTripID == trip.persistentModelID
                                    ) {
                                        selectedTripID = trip.persistentModelID
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .scrollIndicators(.hidden)
                    }

                    // Total expenses card
                    TotalExpensesCard(
                        totalExpenses: totalExpenses,
                        currencyCode: displayCurrency,
                        subtitle: selectedTrip == nil ? "Across all trips" : selectedTrip!.name
                    )
                    .padding(.horizontal)

                    // Pie chart
                    SpendingPieChart(categoryTotals: categoryTotals)
                        .padding(.horizontal)

                    // Category breakdown
                    CategoryBreakdownList(categoryTotals: categoryTotals, currencyCode: displayCurrency)
                        .padding(.horizontal)

                    // Expenses grouped by category (when a trip is selected)
                    if selectedTrip != nil && !expensesByCategory.isEmpty {
                        expenseListSection
                            .padding(.horizontal)
                    }
                }
                .padding(.top)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
        }
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
                        Text(CurrencyHelper.format(group.total, code: displayCurrency))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
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
                            Text(CurrencyHelper.format(expense.amount, code: displayCurrency))
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

struct TripFilterChip: View {
    let title: String
    var color: Color = Theme.accentTeal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? color.opacity(0.2) : Color(.tertiarySystemFill), in: Capsule())
                .foregroundStyle(isSelected ? color : .secondary)
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? color : .clear, lineWidth: 1.5)
                )
        }
    }
}

#Preview {
    StatsTabView()
        .modelContainer(SampleData.container)
}
