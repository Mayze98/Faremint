import SwiftUI
import Charts

struct SpendingOverTimeChart: View {
    let dailySpends: [StatsViewModel.DailySpend]
    let currencyCode: String

    @State private var selectedMode: ChartMode = .daily

    enum ChartMode: String, CaseIterable {
        case daily = "Daily"
        case cumulative = "Cumulative"
    }

    // MARK: - Data

    /// Fill gaps between first and last day so the area chart is continuous.
    /// Always returns at least 2 points so the chart has something to draw.
    private var filledDaily: [(date: Date, amount: Double)] {
        guard let first = dailySpends.first?.date,
              let last = dailySpends.last?.date else { return [] }
        let calendar = Calendar.current
        let lookup = Dictionary(dailySpends.map { (calendar.startOfDay(for: $0.date), $0.amount) },
                                uniquingKeysWith: +)
        var result: [(date: Date, amount: Double)] = []
        var current = calendar.startOfDay(for: first)
        let end = calendar.startOfDay(for: last)
        while current <= end {
            result.append((current, lookup[current] ?? 0))
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        // Area/line charts need ≥2 points to render — pad with a zero day before
        if result.count == 1, let only = result.first {
            let dayBefore = calendar.date(byAdding: .day, value: -1, to: only.date)!
            result.insert((dayBefore, 0), at: 0)
        }
        return result
    }

    private var cumulativeData: [(date: Date, amount: Double)] {
        var running: Double = 0
        return filledDaily.map { entry in
            running += entry.amount
            return (entry.date, running)
        }
    }

    private var chartData: [(date: Date, amount: Double)] {
        selectedMode == .daily ? filledDaily : cumulativeData
    }

    private var maxAmount: Double {
        chartData.map(\.amount).max() ?? 1
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Spending Over Time")
                    .font(.headline)
                Spacer()
                Picker("Mode", selection: $selectedMode) {
                    ForEach(ChartMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 12)

            if chartData.isEmpty {
                Text("No expenses to display")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                Chart(chartData, id: \.date) { point in
                    // Filled area
                    AreaMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Amount", point.amount)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(hex: "88D4E2").opacity(0.4),
                                Color(hex: "88D4E2").opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    // Line on top
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Amount", point.amount)
                    )
                    .foregroundStyle(Color(hex: "6CB4EE"))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: xStrideCount)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption2)
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        if let amount = value.as(Double.self) {
                            AxisValueLabel {
                                Text(CurrencyHelper.compactFormat(amount, code: currencyCode))
                                    .font(.caption2)
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [4, 4]))
                    }
                }
                .chartYScale(domain: 0...(maxAmount * 1.15))
                .frame(height: 180)
                .padding(.horizontal)
                .animation(.easeInOut(duration: 0.3), value: selectedMode)
            }
        }
        .padding(.bottom, 16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var xStrideCount: Int {
        let count = filledDaily.count
        if count <= 7 { return 1 }
        if count <= 14 { return 2 }
        if count <= 30 { return 5 }
        return 7
    }
}

#Preview {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let spends: [StatsViewModel.DailySpend] = (-9...0).map { offset in
        let date = calendar.date(byAdding: .day, value: offset, to: today)!
        return StatsViewModel.DailySpend(date: date, amount: Double.random(in: 30...350))
    }
    return SpendingOverTimeChart(dailySpends: spends, currencyCode: "USD")
        .padding()
}
