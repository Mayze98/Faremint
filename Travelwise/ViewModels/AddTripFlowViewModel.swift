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

    /// The currency chosen for this specific trip (editable on the budget step).
    var tripCurrency: String
    /// The user's home/preference currency (read from UserDefaults).
    let homeCurrency: String
    /// Exchange rate: 1 unit of tripCurrency = exchangeRate units of homeCurrency.
    var exchangeRate: Double?
    /// True if the Frankfurter fetch failed.
    var rateError: Bool = false

    /// Formatted equivalent of the home-currency budget converted into the trip currency.
    var budgetInTripCurrency: String {
        guard tripCurrency != homeCurrency, budgetValue > 0, let rate = exchangeRate else { return "" }
        return CurrencyHelper.format(budgetValue * rate, code: tripCurrency)
    }

    /// True when a conversion is needed and the rate is still loading.
    var isFetchingRate: Bool { tripCurrency != homeCurrency && exchangeRate == nil && !rateError }

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
        self.tripCurrency = currencyCode
        self.homeCurrency = UserDefaults.standard.string(forKey: "currencyCode") ?? "CAD"
    }

    // MARK: - Exchange Rate

    func fetchExchangeRate() async {
        guard tripCurrency != homeCurrency else {
            exchangeRate = 1.0
            return
        }
        rateError = false
        exchangeRate = nil
        do {
            exchangeRate = try await ExchangeRateService.shared.rate(from: homeCurrency, to: tripCurrency)
        } catch {
            print("[ExchangeRate] Trip budget fetch failed: \(error)")
            rateError = true
        }
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

    /// Symbol for the home currency — shown next to the budget input field.
    var homeCurrencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = homeCurrency
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
            currency: tripCurrency,
            startDate: startDate,
            endDate: endDate,
            colorHex: Theme.bubblePalette[selectedColorIndex],
            categories: allCategories
        )
        modelContext.insert(trip)
        firestoreService.saveTrip(trip)
    }
}
