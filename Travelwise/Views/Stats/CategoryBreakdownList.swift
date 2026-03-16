import SwiftUI

struct CategoryBreakdownList: View {
    let categoryTotals: [CategoryTotal]
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Breakdown")
                .font(.headline)
                .padding(.horizontal)

            if categoryTotals.isEmpty {
                Text("No expenses recorded")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(categoryTotals) { cat in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Theme.colorForCategory(cat.name))
                                .frame(width: 10, height: 10)

                            Text(cat.name)
                                .font(.subheadline)

                            Spacer()

                            Text(CurrencyHelper.format(cat.total, code: currencyCode))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)

                        if cat.id != categoryTotals.last?.id {
                            Divider()
                                .padding(.leading, 34)
                        }
                    }
                }
            }
        }
        .padding(.vertical)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    CategoryBreakdownList(categoryTotals: [
        CategoryTotal(name: "Food & Drinks", total: 1500, percentage: 25),
        CategoryTotal(name: "Hotels", total: 2000, percentage: 33),
        CategoryTotal(name: "Flight", total: 1200, percentage: 20),
    ], currencyCode: "USD")
    .padding()
}
