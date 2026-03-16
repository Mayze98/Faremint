import SwiftUI

struct ExpenseDetailView: View {
    let expense: Expense
    let currencyCode: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header card
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(expense.categoryName)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.colorForCategory(expense.categoryName))
                            Text(expense.title)
                                .font(.title2.weight(.bold))
                        }
                        Spacer()
                        Circle()
                            .fill(Theme.colorForCategory(expense.categoryName).opacity(0.15))
                            .frame(width: 44, height: 44)
                            .overlay {
                                Image(systemName: categoryIcon)
                                    .foregroundStyle(Theme.colorForCategory(expense.categoryName))
                            }
                    }

                    Divider()

                    // Amount
                    HStack {
                        Text("Amount")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(CurrencyHelper.format(expense.amount, code: currencyCode))
                            .font(.title3.weight(.bold))
                    }

                    // Split info
                    if let split = expense.splitPercent {
                        HStack {
                            Text("Original amount")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(CurrencyHelper.format(expense.originalAmount, code: currencyCode))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Your share")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(split))%")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Theme.accentTeal.opacity(0.15), in: Capsule())
                                .foregroundStyle(Theme.accentTeal)
                        }
                    }

                    // Date
                    HStack {
                        Text("Date")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(expense.createdAt, format: .dateTime.month(.wide).day().year())
                            .font(.subheadline)
                    }
                }
                .padding(20)
                .background(.background, in: RoundedRectangle(cornerRadius: 16))

                // Notes
                if !expense.note.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Notes", systemImage: "note.text")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(expense.note)
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.background, in: RoundedRectangle(cornerRadius: 16))
                }

                // Photo
                if let photoData = expense.photoData, let uiImage = UIImage(data: photoData) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Receipt", systemImage: "camera.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.background, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Expense Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var categoryIcon: String {
        let base = BaseCategory.allCases.first { $0.rawValue == expense.categoryName }
        return base?.systemImage ?? "tag.fill"
    }
}

#Preview {
    NavigationStack {
        ExpenseDetailView(
            expense: Expense(title: "Sushi dinner", amount: 85, categoryName: "Food & Drinks", note: "Great omakase at Sukiyabashi Jiro"),
            currencyCode: "USD"
        )
    }
}
