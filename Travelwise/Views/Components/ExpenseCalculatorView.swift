import SwiftUI

struct ExpenseCalculatorView: View {
    @Binding var amount: String
    @Binding var isSplitting: Bool
    @Binding var splitPercent: Double
    var currencyCode: String = "CAD"

    private var amountValue: Double {
        Double(amount) ?? 0
    }

    private var finalAmount: Double {
        if isSplitting {
            return amountValue * (splitPercent / 100)
        }
        return amountValue
    }

    var body: some View {
        Section("Amount") {
            TextField("Total amount", text: $amount)
                .keyboardType(.decimalPad)

            Toggle("Split expense", isOn: $isSplitting)

            if isSplitting {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Your share")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(splitPercent))%")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                    Slider(value: $splitPercent, in: 1...99, step: 1)
                        .tint(Theme.accentTeal)
                }

                if amountValue > 0 {
                    HStack {
                        Text("You pay")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(finalAmount, format: .currency(code: currencyCode))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accentTeal)
                    }
                }
            }
        }
    }

    var calculatedAmount: Double {
        finalAmount
    }
}
