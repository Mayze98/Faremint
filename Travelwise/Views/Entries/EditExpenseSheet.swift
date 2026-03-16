import SwiftUI
import SwiftData

struct EditExpenseSheet: View {
    let expense: Expense
    let categories: [ExpenseCategory]
    let currencyCode: String
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var amount: String
    @State private var selectedCategory: String
    @State private var note: String
    @State private var isSplitting: Bool
    @State private var splitPercent: Double
    @State private var photoData: Data?

    init(expense: Expense, categories: [ExpenseCategory], currencyCode: String) {
        self.expense = expense
        self.categories = categories
        self.currencyCode = currencyCode
        _title = State(initialValue: expense.title)
        _amount = State(initialValue: String(format: "%.2f", expense.originalAmount))
        _selectedCategory = State(initialValue: expense.categoryName)
        _note = State(initialValue: expense.note)
        _isSplitting = State(initialValue: expense.splitPercent != nil)
        _splitPercent = State(initialValue: expense.splitPercent ?? 50)
        _photoData = State(initialValue: expense.photoData)
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
                        ForEach(categories) { category in
                            Label(category.name, systemImage: category.systemImage)
                                .tag(category.name)
                        }
                    }
                }

                ExpenseCalculatorView(
                    amount: $amount,
                    isSplitting: $isSplitting,
                    splitPercent: $splitPercent,
                    currencyCode: currencyCode
                )

                Section("Notes") {
                    TextField("Add a note (optional)", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                PhotoPickerSection(imageData: $photoData)
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        applyChanges()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func applyChanges() {
        expense.title = title.trimmingCharacters(in: .whitespaces)
        expense.originalAmount = amountValue
        expense.amount = finalAmount
        expense.splitPercent = isSplitting ? splitPercent : nil
        expense.categoryName = selectedCategory
        expense.note = note.trimmingCharacters(in: .whitespaces)
        expense.photoData = photoData
        dismiss()
    }
}
