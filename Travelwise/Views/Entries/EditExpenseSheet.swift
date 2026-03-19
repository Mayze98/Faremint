import SwiftUI
import SwiftData

struct EditExpenseSheet: View {
    let expense: Expense
    let categories: [ExpenseCategory]
    let currencyCode: String
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ExpenseFormViewModel

    init(expense: Expense, categories: [ExpenseCategory], currencyCode: String) {
        self.expense = expense
        self.categories = categories
        self.currencyCode = currencyCode
        _viewModel = State(initialValue: ExpenseFormViewModel(expense: expense))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    TextField("0.00", text: $viewModel.amount)
                        .keyboardType(.decimalPad)
                        .font(.title2.weight(.semibold))
                }

                Section("Details") {
                    TextField("Expense title", text: $viewModel.title)
                }

                Section("Category") {
                    categoryGrid
                }

                Section("Notes") {
                    TextField("Add a note (optional)", text: $viewModel.note, axis: .vertical)
                        .lineLimit(3...6)
                }

                PhotoPickerSection(imageData: $viewModel.photoData)
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.updateExpense()
                        dismiss()
                    }
                    .disabled(!viewModel.canSave)
                }
            }
        }
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            ForEach(categories) { category in
                Button {
                    viewModel.selectedCategory = category.name
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: category.systemImage)
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(
                                viewModel.selectedCategory == category.name
                                    ? Theme.colorForCategory(category.name).opacity(0.2)
                                    : Color(.systemGray6)
                            )
                            .foregroundStyle(
                                viewModel.selectedCategory == category.name
                                    ? Theme.colorForCategory(category.name)
                                    : .secondary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(
                                        viewModel.selectedCategory == category.name
                                            ? Theme.colorForCategory(category.name)
                                            : .clear,
                                        lineWidth: 2
                                    )
                            )

                        Text(category.name)
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundStyle(
                                viewModel.selectedCategory == category.name ? .primary : .secondary
                            )
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
