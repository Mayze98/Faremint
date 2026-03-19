import SwiftUI
import SwiftData

@Observable
final class ExpenseFormViewModel {
    var title: String
    var amount: String
    var selectedCategory: String
    var note: String
    var photoData: Data?

    private let existingExpense: Expense?

    var isEditing: Bool { existingExpense != nil }

    init(trip: Trip) {
        self.existingExpense = nil
        self.title = ""
        self.amount = ""
        self.selectedCategory = trip.categories.first?.name ?? "Food & Drinks"
        self.note = ""
        self.photoData = nil
    }

    init(expense: Expense) {
        self.existingExpense = expense
        self.title = expense.title
        self.amount = String(format: "%.2f", expense.originalAmount)
        self.selectedCategory = expense.categoryName
        self.note = expense.note
        self.photoData = expense.photoData
    }

    var amountValue: Double {
        Double(amount) ?? 0
    }

    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && amountValue > 0
    }

    func saveNewExpense(trip: Trip, modelContext: ModelContext) {
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
        trip.expenses.append(expense)
    }

    func updateExpense() {
        guard let expense = existingExpense else { return }
        expense.title = title.trimmingCharacters(in: .whitespaces)
        expense.originalAmount = amountValue
        expense.amount = amountValue
        expense.splitPercent = nil
        expense.categoryName = selectedCategory
        expense.note = note.trimmingCharacters(in: .whitespaces)
        expense.photoData = photoData
    }
}
