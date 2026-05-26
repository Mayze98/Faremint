import SwiftUI

/// A styled card view used by `ImageRenderer` to produce a shareable trip summary image.
struct TripSummaryCard: View {
    let tripName: String
    let startDate: Date
    let endDate: Date?
    let totalSpent: Double
    let budget: Double
    let expenseCount: Int
    let topCategory: String?
    let currencyCode: String
    let colorHex: String

    private var tripDays: Int {
        let calendar = Calendar.current
        let end = endDate ?? .now
        return max(calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: calendar.startOfDay(for: end)).day ?? 0, 1)
    }

    private var dateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        let start = formatter.string(from: startDate)
        if let end = endDate {
            return "\(start) – \(formatter.string(from: end))"
        }
        return "Started \(start)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.9))
                Text(tripName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text(dateRange)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                LinearGradient(
                    colors: [Color(hex: colorHex), Color(hex: colorHex).opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Stats grid
            VStack(spacing: 16) {
                HStack(spacing: 0) {
                    statCell(label: "Total Spent", value: CurrencyHelper.format(totalSpent, code: currencyCode))
                    Divider().frame(height: 36)
                    statCell(label: "Budget", value: CurrencyHelper.format(budget, code: currencyCode))
                }

                Divider()

                HStack(spacing: 0) {
                    statCell(label: "Days", value: "\(tripDays)")
                    Divider().frame(height: 36)
                    statCell(label: "Expenses", value: "\(expenseCount)")
                    Divider().frame(height: 36)
                    statCell(label: "Daily Avg", value: CurrencyHelper.format(totalSpent / Double(tripDays), code: currencyCode))
                }

                if let top = topCategory {
                    Divider()
                    HStack {
                        Text("Top Category")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(top)
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(20)

            // Footer
            HStack {
                Spacer()
                Text("Tracked with Faremint")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.bottom, 12)
        }
        .frame(width: 340)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Renderer helper

extension TripSummaryCard {
    @MainActor
    static func renderImage(
        tripName: String,
        startDate: Date,
        endDate: Date?,
        totalSpent: Double,
        budget: Double,
        expenseCount: Int,
        topCategory: String?,
        currencyCode: String,
        colorHex: String
    ) -> UIImage? {
        let card = TripSummaryCard(
            tripName: tripName,
            startDate: startDate,
            endDate: endDate,
            totalSpent: totalSpent,
            budget: budget,
            expenseCount: expenseCount,
            topCategory: topCategory,
            currencyCode: currencyCode,
            colorHex: colorHex
        )
        let renderer = ImageRenderer(content: card.padding(20).background(Color(.systemGroupedBackground)))
        renderer.scale = 3.0
        return renderer.uiImage
    }
}

#Preview {
    TripSummaryCard(
        tripName: "Tokyo 2026",
        startDate: .now.addingTimeInterval(-7 * 86400),
        endDate: .now,
        totalSpent: 2450,
        budget: 5000,
        expenseCount: 23,
        topCategory: "Food & Drinks",
        currencyCode: "CAD",
        colorHex: "45B7D1"
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
