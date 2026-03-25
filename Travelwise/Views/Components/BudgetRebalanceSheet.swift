import SwiftUI

struct BudgetRebalanceSheet: View {
    let trip: Trip
    let suggestions: [RebalanceSuggestion]
    @Environment(\.dismiss) private var dismiss
    @Environment(FirestoreService.self) private var firestoreService
    @AppStorage("currencyCode") private var currencyCode = "CAD"

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Some categories are over their budget limit.")
                            .font(.subheadline.weight(.medium))
                        Text("The suggested adjustments below reduce limits in under-budget categories proportionally to cover the overspend.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Suggested Adjustments") {
                    ForEach(suggestions) { suggestion in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(suggestion.categoryName)
                                    .font(.subheadline.weight(.medium))
                                HStack(spacing: 4) {
                                    Text(CurrencyHelper.format(suggestion.currentLimit, code: currencyCode))
                                        .strikethrough()
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "arrow.right")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(CurrencyHelper.format(suggestion.suggestedLimit, code: currencyCode))
                                        .foregroundStyle(.primary)
                                }
                                .font(.caption)
                            }
                            Spacer()
                            Text(CurrencyHelper.format(suggestion.delta, code: currencyCode))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.red)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Rebalance Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Dismiss") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        BudgetRebalancer.apply(suggestions: suggestions, to: trip)
                        firestoreService.saveTrip(trip)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
