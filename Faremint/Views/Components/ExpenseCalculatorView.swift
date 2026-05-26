import SwiftUI

struct ExpenseCalculatorView: View {
    @Binding var amount: String
    var currencyCode: String = "CAD"

    var body: some View {
        Section("Amount") {
            TextField("0.00", text: $amount)
                .keyboardType(.decimalPad)
                .font(.title2.weight(.semibold))
        }
    }
}
