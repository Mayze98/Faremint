import SwiftUI

struct TotalExpensesCard: View {
    let totalExpenses: Double
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total Expenses")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))

            Text(CurrencyHelper.format(totalExpenses, code: currencyCode))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Across all trips")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
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
}

#Preview {
    TotalExpensesCard(totalExpenses: 6100, currencyCode: "USD")
        .padding()
}
