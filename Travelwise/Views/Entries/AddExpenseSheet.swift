import SwiftUI

struct AddExpenseSheet: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var amount = ""
    @State private var selectedCategory: String
    @State private var note = ""
    @State private var isSplitting = false
    @State private var splitPercent: Double = 50
    @State private var photoData: Data?

    init(trip: Trip) {
        self.trip = trip
        _selectedCategory = State(initialValue: trip.categories.first?.name ?? "Food & Drinks")
    }

    private var amountValue: Double {
        Double(amount) ?? 0
    }

    private var finalAmount: Double {
        if isSplitting {
            return amountValue * (splitPercent / 100)
        }
        return amountValue
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && amountValue > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Expense title", text: $title)

                    Picker("Category", selection: $selectedCategory) {
                        ForEach(trip.categories) { category in
                            Label(category.name, systemImage: category.systemImage)
                                .tag(category.name)
                        }
                    }
                }

                ExpenseCalculatorView(
                    amount: $amount,
                    isSplitting: $isSplitting,
                    splitPercent: $splitPercent
                )

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

    private func saveExpense() {
        let expense = Expense(
            title: title.trimmingCharacters(in: .whitespaces),
            amount: finalAmount,
            originalAmount: amountValue,
            splitPercent: isSplitting ? splitPercent : nil,
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
