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
    @State private var photoData: Data?

    init(expense: Expense, categories: [ExpenseCategory], currencyCode: String) {
        self.expense = expense
        self.categories = categories
        self.currencyCode = currencyCode
        _title = State(initialValue: expense.title)
        _amount = State(initialValue: String(format: "%.2f", expense.originalAmount))
        _selectedCategory = State(initialValue: expense.categoryName)
        _note = State(initialValue: expense.note)
        _photoData = State(initialValue: expense.photoData)
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

    private var categoryGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            ForEach(categories) { category in
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

    private func applyChanges() {
        expense.title = title.trimmingCharacters(in: .whitespaces)
        expense.originalAmount = amountValue
        expense.amount = amountValue
        expense.splitPercent = nil
        expense.categoryName = selectedCategory
        expense.note = note.trimmingCharacters(in: .whitespaces)
        expense.photoData = photoData
        dismiss()
    }
}
