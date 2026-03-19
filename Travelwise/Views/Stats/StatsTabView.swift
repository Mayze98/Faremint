import SwiftUI
import SwiftData

struct StatsTabView: View {
    @Query(sort: \Trip.createdAt, order: .reverse) private var allTrips: [Trip]
    @AppStorage("currencyCode") private var currencyCode = "CAD"
    @State private var viewModel = StatsViewModel()

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
                    if !viewModel.trips(from: allTrips).isEmpty {
                        ScrollView(.horizontal) {
                            HStack(spacing: 10) {
                                TripFilterChip(
                                    title: "All Trips",
                                    isSelected: viewModel.selectedTripID == nil
                                ) {
                                    viewModel.clearFilter()
                                }

                                ForEach(viewModel.trips(from: allTrips)) { trip in
                                    TripFilterChip(
                                        title: trip.name,
                                        color: Color(hex: trip.colorHex),
                                        isSelected: viewModel.selectedTripID == trip.persistentModelID
                                    ) {
                                        viewModel.selectTrip(trip)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .scrollIndicators(.hidden)
                    }

                    // Total expenses card
                    TotalExpensesCard(
                        totalExpenses: viewModel.totalExpenses(from: allTrips),
                        currencyCode: viewModel.displayCurrency(from: allTrips, defaultCode: currencyCode),
                        subtitle: viewModel.selectedTrip(from: allTrips) == nil ? "Across all trips" : viewModel.selectedTrip(from: allTrips)!.name
                    )
                    .padding(.horizontal)

                    // Pie chart
                    SpendingPieChart(categoryTotals: viewModel.categoryTotals(from: allTrips))
                        .padding(.horizontal)

                    // Category breakdown
                    CategoryBreakdownList(categoryTotals: viewModel.categoryTotals(from: allTrips), currencyCode: viewModel.displayCurrency(from: allTrips, defaultCode: currencyCode))
                        .padding(.horizontal)

                    // Expenses grouped by category (when a trip is selected)
                    if viewModel.selectedTrip(from: allTrips) != nil && !viewModel.expensesByCategory(from: allTrips).isEmpty {
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
                let groups = viewModel.expensesByCategory(from: allTrips)
                ForEach(groups, id: \.category) { group in
                    // Category header
                    HStack(spacing: 8) {
                        Image(systemName: group.systemImage)
                            .font(.caption)
                            .foregroundStyle(Theme.colorForCategory(group.category))
                        Text(group.category)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(CurrencyHelper.format(group.total, code: viewModel.displayCurrency(from: allTrips, defaultCode: currencyCode)))
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
                            Text(CurrencyHelper.format(expense.amount, code: viewModel.displayCurrency(from: allTrips, defaultCode: currencyCode)))
                                .font(.subheadline.weight(.medium))
                                .monospacedDigit()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    }

                    if group.category != groups.last?.category {
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
