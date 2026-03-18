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

    private static let defaultColors: [Color] = [.orange, .blue, .purple, .cyan, .pink, .green, .yellow, .brown]

    private func colorFor(_ name: String, at index: Int) -> Color {
        Theme.categoryColors[name] ?? Self.defaultColors[index % Self.defaultColors.count]
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
                .chartForegroundStyleScale(domain: categoryTotals.map(\.name)) { name in
                    let index = categoryTotals.firstIndex { $0.name == name } ?? 0
                    return colorFor(name, at: index)
                }
                .chartLegend(.hidden)
                .frame(height: 220)
                .padding(.horizontal)

                // Percentage labels
                WrappingHStack(spacing: 8) {
                    ForEach(Array(categoryTotals.enumerated()), id: \.element.id) { index, cat in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(colorFor(cat.name, at: index))
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

private struct WrappingHStack: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
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
