import SwiftUI
import Charts

struct CategoryTotal: Identifiable {
    let id = UUID()
    let name: String
    let total: Double
    let percentage: Double
}

struct SpendingPieChart: View {
    let categoryTotals: [CategoryTotal]

    private var chartColors: [String: Color] {
        var colors: [String: Color] = [:]
        let defaultColors: [Color] = [.orange, .blue, .purple, .cyan, .pink, .green, .yellow, .brown]
        for (index, cat) in categoryTotals.enumerated() {
            colors[cat.name] = Theme.categoryColors[cat.name] ?? defaultColors[index % defaultColors.count]
        }
        return colors
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending by Category")
                .font(.headline)
                .padding(.horizontal)

            if categoryTotals.isEmpty {
                Text("No expenses to display")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                Chart(categoryTotals) { item in
                    SectorMark(
                        angle: .value("Amount", item.total),
                        innerRadius: .ratio(0.55),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(by: .value("Category", item.name))
                }
                .chartForegroundStyleScale(chartColors)
                .chartLegend(position: .bottom, alignment: .center, spacing: 12)
                .frame(height: 220)
                .padding(.horizontal)

                // Percentage labels around chart
                HStack(spacing: 8) {
                    ForEach(categoryTotals.prefix(5)) { cat in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(chartColors[cat.name] ?? .gray)
                                .frame(width: 8, height: 8)
                            Text("\(cat.name) \(Int(cat.percentage))%")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    SpendingPieChart(categoryTotals: [
        CategoryTotal(name: "Food & Drinks", total: 1500, percentage: 25),
        CategoryTotal(name: "Transportation", total: 780, percentage: 13),
        CategoryTotal(name: "Sightseeing", total: 600, percentage: 10),
        CategoryTotal(name: "Flight", total: 1200, percentage: 20),
        CategoryTotal(name: "Hotels", total: 2000, percentage: 33),
    ])
    .padding()
}
