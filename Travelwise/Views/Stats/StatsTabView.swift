import SwiftUI
import SwiftData

struct StatsTabView: View {
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @AppStorage("currencyCode") private var currencyCode = "CAD"
    @State private var selectedTripID: PersistentIdentifier?

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
            ScrollView {
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
                        ScrollView(.horizontal, showsIndicators: false) {
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
                }
                .padding(.top)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
        }
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
