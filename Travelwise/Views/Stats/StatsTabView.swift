import SwiftUI
import SwiftData

struct StatsTabView: View {
    @Query(sort: \Trip.createdAt, order: .reverse) private var allTrips: [Trip]
    @Environment(StoreKitService.self) private var storeKitService
    @AppStorage("currencyCode") private var currencyCode = "CAD"
    @State private var viewModel = StatsViewModel()
    @State private var showingPastTrips = false
    @State private var showingProUpgrade = false

    private var currentYear: Int {
        Calendar.current.component(.year, from: .now)
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Statistics")
                                .font(.largeTitle.weight(.bold))
                            Text("Your \(currentYear, format: .number.grouping(.never)) spending overview")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            showingPastTrips = true
                        } label: {
                            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                                .font(.title3)
                                .foregroundStyle(Theme.accentTeal)
                                .frame(width: 40, height: 40)
                                .background(Theme.accentTeal.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
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

                    // Total expenses card — daily avg & forecast are Pro
                    TotalExpensesCard(
                        totalExpenses: viewModel.totalExpenses(from: allTrips),
                        currencyCode: currencyCode,
                        subtitle: viewModel.selectedTrip(from: allTrips) == nil ? "Across all trips" : viewModel.selectedTrip(from: allTrips)!.name,
                        dailyAverage: storeKitService.isProUser ? viewModel.dailyAverage(from: allTrips) : nil,
                        forecastedTotal: storeKitService.isProUser ? viewModel.forecastedTotal(from: allTrips) : nil,
                        daysRemaining: storeKitService.isProUser ? viewModel.daysRemaining(from: allTrips) : nil
                    )
                    .padding(.horizontal)

                    // Category: pie chart + breakdown in one card
                    SpendingPieChart(
                        categoryTotals: viewModel.categoryTotals(from: allTrips),
                        currencyCode: currencyCode,
                        isProUser: storeKitService.isProUser,
                        onUpgradeTapped: { showingProUpgrade = true }
                    )
                    .padding(.horizontal)

                    // Spending over time chart — Pro only
                    if storeKitService.isProUser {
                        if !viewModel.dailySpends(from: allTrips).isEmpty {
                            SpendingOverTimeChart(
                                dailySpends: viewModel.dailySpends(from: allTrips),
                                currencyCode: currencyCode
                            )
                            .padding(.horizontal)
                        }
                    } else {
                        // Locked spending over time placeholder
                        proLockedCard(
                            title: "Spending Over Time",
                            icon: "chart.xyaxis.line",
                            description: "Track daily and cumulative spending trends"
                        )
                        .padding(.horizontal)
                    }

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
            .sheet(isPresented: $showingPastTrips) {
                StatsPastTripsSheet()
            }
            .sheet(isPresented: $showingProUpgrade) {
                ProUpgradeView()
            }
        }
    }

    private func proLockedCard(title: String, icon: String, description: String) -> some View {
        Button { showingProUpgrade = true } label: {
            VStack(spacing: 12) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text("PRO")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.accentTeal, in: Capsule())
                }

                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.accentTeal.opacity(0.5))
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
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
                        Text(CurrencyHelper.format(group.total, code: currencyCode))
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
                            Text(CurrencyHelper.format(expense.amount, code: currencyCode))
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
        .environment(StoreKitService())
}
