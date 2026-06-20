import SwiftUI
import Charts

struct SpendingPieChart: View {
    let categoryTotals: [CategoryTotal]
    let currencyCode: String

    @State private var selectedTab: CategoryTab = .chart

    enum CategoryTab: String, CaseIterable {
        case chart = "Chart"
        case breakdown = "Breakdown"
    }

    private static let defaultColors: [Color] = [.orange, .blue, .purple, .cyan, .pink, .green, .yellow, .brown]

    private func stableColorForCategory(_ name: String) -> Color {
        if let known = Theme.categoryColors[name] { return known }
        let index = stableHash(for: name) % Self.defaultColors.count
        return Self.defaultColors[index]
    }

    private func stableHash(for name: String) -> Int {
        var hash = 0
        for scalar in name.unicodeScalars { hash = (hash &* 31) &+ Int(scalar.value) }
        return abs(hash)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with toggle
            HStack {
                Text("Spending by Category")
                    .font(.headline)
                Spacer()
                if !categoryTotals.isEmpty {
                    Picker("View", selection: $selectedTab) {
                        ForEach(CategoryTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 12)

            if categoryTotals.isEmpty {
                Text("No expenses to display")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                switch selectedTab {
                case .chart:
                    chartView
                case .breakdown:
                    breakdownView
                }
            }
        }
        .padding(.bottom, 16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Chart view

    private var chartView: some View {
        VStack(spacing: 12) {
            Chart(categoryTotals) { item in
                SectorMark(
                    angle: .value("Amount", item.total),
                    innerRadius: .ratio(0.55),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(by: .value("Category", item.name))
            }
            .chartForegroundStyleScale(domain: categoryTotals.map(\.name)) { stableColorForCategory($0) }
            .chartLegend(.hidden)
            .frame(height: 220)
            .padding(.horizontal)

            // Legend chips
            WrappingHStack(spacing: 8) {
                ForEach(categoryTotals, id: \.id) { cat in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(stableColorForCategory(cat.name))
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

    // MARK: - Breakdown view

    private var breakdownView: some View {
        VStack(spacing: 0) {
            ForEach(categoryTotals) { cat in
                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(stableColorForCategory(cat.name))
                            .frame(width: 10, height: 10)
                        Text(cat.name)
                            .font(.subheadline)
                        Spacer()
                        Text(CurrencyHelper.format(cat.total, code: currencyCode))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.tertiarySystemFill))
                                .frame(height: 4)
                            Capsule()
                                .fill(stableColorForCategory(cat.name).opacity(0.8))
                                .frame(width: geo.size.width * (cat.percentage / 100), height: 4)
                        }
                    }
                    .frame(height: 4)
                    .padding(.leading, 20)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)

                if cat.id != categoryTotals.last?.id {
                    Divider().padding(.leading, 34)
                }
            }
        }
    }
}

// MARK: - Wrapping layout (used by legend chips)

private struct WrappingHStack: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var rows: [[LayoutSubviews.Element]] = []
        var currentRow: [LayoutSubviews.Element] = []
        var currentRowWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentRowWidth + size.width > bounds.width && !currentRow.isEmpty {
                rows.append(currentRow); currentRow = [subview]; currentRowWidth = size.width + spacing
            } else { currentRow.append(subview); currentRowWidth += size.width + spacing }
        }
        if !currentRow.isEmpty { rows.append(currentRow) }
        var y = bounds.minY
        for row in rows {
            let rowWidth = row.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width } + CGFloat(row.count - 1) * spacing
            var x = bounds.minX + (bounds.width - rowWidth) / 2
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += rowHeight + spacing
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
    ], currencyCode: "USD")
    .padding()
}
