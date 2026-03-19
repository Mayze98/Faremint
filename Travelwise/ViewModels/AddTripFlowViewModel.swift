import SwiftUI
import SwiftData

@Observable
final class AddTripFlowViewModel {
    var step = 0
    var name = ""
    var budget = ""
    var categoryLimits: [String: String] = [:]
    var customCategoryName = ""
    var customCategories: [ExpenseCategory] = []
    var startDate = Date.now
    var endDate = Date.now.addingTimeInterval(7 * 24 * 3600)
    var selectedColorIndex = Int.random(in: 0..<8)

    private let currencyCode: String

    // Auto-allocation percentages for built-in categories
    private static let allocationPercents: [String: Double] = [
        "Hotels": 0.30,
        "Flight": 0.25,
        "Food & Drinks": 0.20,
        "Sightseeing": 0.10,
        "Transportation": 0.10,
        "Souvenir": 0.05
    ]

    init(currencyCode: String) {
        self.currencyCode = currencyCode
    }

    var budgetValue: Double {
        Double(budget) ?? 0
    }

    var totalCategoryLimits: Double {
        categoryLimits.values.compactMap { Double($0) }.reduce(0, +)
    }

    var remainingBudget: Double {
        budgetValue - totalCategoryLimits
    }

    var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = .current
        return formatter.currencySymbol ?? "$"
    }

    var nextButtonEnabled: Bool {
        switch step {
        case 0: !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: budgetValue > 0
        case 2: remainingBudget >= 0
        default: false
        }
    }

    func handleNext() -> Bool {
        switch step {
        case 0:
            step = 1
            return false
        case 1:
            autoAllocateBudget()
            step = 2
            return false
        case 2:
            return true // signal to save
        default:
            return false
        }
    }

    func goBack() -> Bool {
        if step > 0 {
            step -= 1
            return false
        }
        return true // signal to dismiss
    }

    func autoAllocateBudget() {
        let budget = budgetValue
        var allocated: Double = 0
        for (categoryName, percent) in Self.allocationPercents {
            let amount = (budget * percent).rounded(.down)
            categoryLimits[categoryName] = String(Int(amount))
            allocated += amount
        }
        let remainder = budget - allocated
        if remainder > 0, let current = Double(categoryLimits["Hotels"] ?? "0") {
            categoryLimits["Hotels"] = String(Int(current + remainder))
        }
    }

    func categoryLimitBinding(for name: String) -> Binding<String> {
        Binding(
            get: { [weak self] in self?.categoryLimits[name, default: ""] ?? "" },
            set: { [weak self] in self?.categoryLimits[name] = $0 }
        )
    }

    func limitValue(for name: String) -> Double? {
        guard let text = categoryLimits[name], let value = Double(text), value > 0 else { return nil }
        return value
    }

    func addCustomCategory() {
        let trimmed = customCategoryName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        customCategories.append(ExpenseCategory(customName: trimmed))
        customCategoryName = ""
    }

    func removeCustomCategory(_ category: ExpenseCategory) {
        categoryLimits.removeValue(forKey: category.name)
        customCategories.removeAll { $0.id == category.id }
    }

    func ensureEndDateAfterStart() {
        if endDate < startDate {
            endDate = startDate.addingTimeInterval(24 * 3600)
        }
    }

    func saveTrip(modelContext: ModelContext, firestoreService: FirestoreService) {
        let baseCategories = BaseCategory.allCases.map {
            ExpenseCategory(base: $0, budgetLimit: limitValue(for: $0.rawValue))
        }
        let customWithLimits = customCategories.map {
            ExpenseCategory(customName: $0.name, systemImage: $0.systemImage, budgetLimit: limitValue(for: $0.name))
        }
        let allCategories = baseCategories + customWithLimits
        let trip = Trip(
            name: name.trimmingCharacters(in: .whitespaces),
            budget: budgetValue,
            currency: currencyCode,
            startDate: startDate,
            endDate: endDate,
            colorHex: Theme.bubblePalette[selectedColorIndex],
            categories: allCategories
        )
        modelContext.insert(trip)
        firestoreService.saveTrip(trip)
    }
}
