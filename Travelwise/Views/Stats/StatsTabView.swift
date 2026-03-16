import SwiftUI
import SwiftData

struct StatsTabView: View {
    @Query private var trips: [Trip]
    @AppStorage("currencyCode") private var currencyCode = "USD"

    private var totalExpenses: Double {
        trips.reduce(0) { $0 + $1.totalSpent }
    }

    private var categoryTotals: [CategoryTotal] {
        var totals: [String: Double] = [:]
        for trip in trips {
            for expense in trip.expenses {
                totals[expense.categoryName, default: 0] += expense.amount
            }
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

                    // Total expenses card
                    TotalExpensesCard(totalExpenses: totalExpenses, currencyCode: currencyCode)
                        .padding(.horizontal)

                    // Pie chart
                    SpendingPieChart(categoryTotals: categoryTotals)
                        .padding(.horizontal)

                    // Category breakdown
                    CategoryBreakdownList(categoryTotals: categoryTotals, currencyCode: currencyCode)
                        .padding(.horizontal)
                }
                .padding(.top)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

#Preview {
    StatsTabView()
        .modelContainer(SampleData.container)
}
