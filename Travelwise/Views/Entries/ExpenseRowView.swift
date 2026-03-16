import SwiftUI

struct ExpenseRowView: View {
    let expense: Expense
    let currencyCode: String

    var body: some View {
        HStack(spacing: 12) {
            // Category color indicator
            Circle()
                .fill(Theme.colorForCategory(expense.categoryName))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.title)
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 6) {
                    Text(expense.createdAt, format: .dateTime.month(.abbreviated).day())
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if expense.splitPercent != nil {
                        Text("Split \(Int(expense.splitPercent ?? 0))%")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.accentTeal.opacity(0.15), in: Capsule())
                            .foregroundStyle(Theme.accentTeal)
                    }

                    if expense.photoData != nil {
                        Image(systemName: "camera.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if !expense.note.isEmpty {
                        Image(systemName: "note.text")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Text(CurrencyHelper.format(expense.amount, code: currencyCode))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}
