import SwiftUI
import SwiftData

struct AddExpenseSheet: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var amount = ""
    @State private var selectedCategory: String
    @State private var note = ""
    @State private var photoData: Data?

    init(trip: Trip) {
        self.trip = trip
        _selectedCategory = State(initialValue: trip.categories.first?.name ?? "Food & Drinks")
    }

    private var amountValue: Double {
        Double(amount) ?? 0
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && amountValue > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    TextField("0.00", text: $amount)
                        .keyboardType(.decimalPad)
                        .font(.title2.weight(.semibold))
                }

                Section("Details") {
                    TextField("Expense title", text: $title)
                }

                Section("Category") {
                    categoryGrid
                }

                Section("Notes") {
                    TextField("Add a note (optional)", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                PhotoPickerSection(imageData: $photoData)
            }
            .navigationTitle("New Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveExpense()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            ForEach(trip.categories) { category in
                Button {
                    selectedCategory = category.name
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: category.systemImage)
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(
                                selectedCategory == category.name
                                    ? Theme.colorForCategory(category.name).opacity(0.2)
                                    : Color(.systemGray6)
                            )
                            .foregroundStyle(
                                selectedCategory == category.name
                                    ? Theme.colorForCategory(category.name)
                                    : .secondary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(
                                        selectedCategory == category.name
                                            ? Theme.colorForCategory(category.name)
                                            : .clear,
                                        lineWidth: 2
                                    )
                            )

                        Text(category.name)
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundStyle(
                                selectedCategory == category.name ? .primary : .secondary
                            )
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func saveExpense() {
        let expense = Expense(
            title: title.trimmingCharacters(in: .whitespaces),
            amount: amountValue,
            originalAmount: amountValue,
            splitPercent: nil,
            categoryName: selectedCategory,
            note: note.trimmingCharacters(in: .whitespaces),
            photoData: photoData,
            trip: trip
        )
        modelContext.insert(expense)
        dismiss()
    }
}

#Preview {
    AddExpenseSheet(trip: Trip(name: "Test", budget: 1000))
        .modelContainer(SampleData.container)
}
