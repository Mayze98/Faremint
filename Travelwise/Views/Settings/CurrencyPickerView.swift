import SwiftUI

struct CurrencyPickerView: View {
    @AppStorage("currencyCode") private var currencyCode = "USD"
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var filteredCurrencies: [(code: String, name: String)] {
        if searchText.isEmpty {
            return CurrencyHelper.commonCurrencies
        }
        return CurrencyHelper.commonCurrencies.filter {
            $0.code.localizedCaseInsensitiveContains(searchText) ||
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            ForEach(filteredCurrencies, id: \.code) { currency in
                Button {
                    currencyCode = currency.code
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(currency.code)
                                .font(.subheadline.weight(.semibold))
                            Text(currency.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if currencyCode == currency.code {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Theme.accentTeal)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
                .tint(.primary)
            }
        }
        .searchable(text: $searchText, prompt: "Search currencies")
        .navigationTitle("Currency")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        CurrencyPickerView()
    }
}
