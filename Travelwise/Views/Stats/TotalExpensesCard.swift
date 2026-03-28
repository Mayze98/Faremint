import SwiftUI

struct TotalExpensesCard: View {
    let totalExpenses: Double
    let currencyCode: String
    var subtitle: String = "Across all trips"
    var dailyAverage: Double? = nil
    var forecastedTotal: Double? = nil
    var daysRemaining: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Total
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Expenses")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                Text(CurrencyHelper.format(totalExpenses, code: currencyCode))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            // Metrics row — only shown when data is available
            if dailyAverage != nil || forecastedTotal != nil {
                Divider()
                    .background(.white.opacity(0.3))

                HStack(spacing: 0) {
                    if let avg = dailyAverage {
                        metricView(
                            label: "Daily Avg",
                            value: CurrencyHelper.format(avg, code: currencyCode)
                        )
                    }

                    if dailyAverage != nil && forecastedTotal != nil {
                        Divider()
                            .frame(height: 32)
                            .background(.white.opacity(0.3))
                    }

                    if let forecast = forecastedTotal {
                        let label = daysRemaining.map { $0 == 1 ? "1 day left" : "\($0) days left" } ?? "Forecast"
                        metricView(
                            label: label,
                            value: "~\(CurrencyHelper.format(forecast, code: currencyCode))"
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: "A8E6CF"), Color(hex: "88D4E2"), Color(hex: "6CB4EE")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color(hex: "88D4E2").opacity(0.3), radius: 10, y: 5)
    }

    private func metricView(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VStack(spacing: 16) {
        TotalExpensesCard(totalExpenses: 6100, currencyCode: "USD")
        TotalExpensesCard(
            totalExpenses: 6100,
            currencyCode: "USD",
            subtitle: "Tokyo 2025",
            dailyAverage: 437,
            forecastedTotal: 8300,
            daysRemaining: 5
        )
    }
    .padding()
}
