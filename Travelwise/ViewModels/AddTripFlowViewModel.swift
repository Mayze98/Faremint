import SwiftUI
import SwiftData

struct MustSpendItem: Identifiable, Hashable {
    let id = UUID()
    var category: BaseCategory
    var amount: String
}

@Observable
final class AddTripFlowViewModel {
    var step = 0
    var name = ""
    var budget = ""
    var categoryLimits: [String: String] = [:]
    var customCategories: [ExpenseCategory] = []
    var startDate = Date.now
    var endDate = Date.now.addingTimeInterval(7 * 24 * 3600)
    var selectedColorIndex = Int.random(in: 0..<8)
    var priorityCategories: Set<String> = []
    var mustSpendItems: [MustSpendItem] = []
    var mustSpendCategory: BaseCategory = .flight
    var mustSpendAmount = ""

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

    // Base allocation percentages (sums to 1.00)
    private static let basePercents: [String: Double] = [
        "Hotels": 0.27, "Flight": 0.22, "Food & Drinks": 0.18,
        "Activities": 0.07, "Sightseeing": 0.09, "Transportation": 0.09,
        "Shopping": 0.05, "Souvenir": 0.03
    ]

    /// Returns final per-category allocation percentages after applying
    /// priority boosts. Priority categories receive +30% of their
    /// base share; the extra is absorbed proportionally from non-priority
    /// categories so the total always sums to 1.00.
    private func effectivePercents() -> [String: Double] {
        let base = Self.basePercents
        guard !priorityCategories.isEmpty else { return base }

        let priorityKeys    = priorityCategories.filter { base[$0] != nil }
        let nonPriorityKeys = base.keys.filter { !priorityKeys.contains($0) }
        guard !nonPriorityKeys.isEmpty else { return base }

        let boostFactor = 0.30
        let extraWeight = priorityKeys.compactMap { base[$0] }.reduce(0) { $0 + $1 * boostFactor }
        let nonPriorityTotal = nonPriorityKeys.compactMap { base[$0] }.reduce(0, +)
        guard nonPriorityTotal > 0 else { return base }

        var result = base
        for key in priorityKeys    { result[key] = base[key]! * (1.0 + boostFactor) }
        for key in nonPriorityKeys { result[key] = max(base[key]! - extraWeight * (base[key]! / nonPriorityTotal), 0) }
        return result
    }

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

    var mustSpendTotal: Double {
        mustSpendItems.compactMap { Double($0.amount) }.reduce(0, +)
    }

    var isMustSpendWithinBudget: Bool {
        mustSpendTotal <= budgetValue
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
        case 2: isMustSpendWithinBudget   // must-spend items - optional
        case 3: true   // priorities - optional
        case 4: remainingBudget >= 0
        default: false
        }
    }

    func handleNext() -> Bool {
        switch step {
        case 0:
            step = 1
            return false
        case 1:
            step = 2
            return false
        case 2:
            step = 3
            return false
        case 3:
            autoAllocateBudget()   // compute allocation with priorities
            step = 4
            return false
        case 4:
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
        let budget = max(budgetValue - mustSpendTotal, 0)
        let percents = adjustedPercentsForMustSpend(basePercents: effectivePercents())
        var allocated: Double = 0
        for (categoryName, percent) in percents {
            let amount = (budget * percent).rounded(.down)
            categoryLimits[categoryName] = String(Int(amount))
            allocated += amount
        }
        let mustSpendByCategory = Dictionary(grouping: mustSpendItems, by: { $0.category.rawValue })
            .mapValues { items in items.compactMap { Double($0.amount) }.reduce(0, +) }
        for (categoryName, amount) in mustSpendByCategory {
            let current = Double(categoryLimits[categoryName] ?? "0") ?? 0
            let updated = (current + amount).rounded(.down)
            categoryLimits[categoryName] = String(Int(updated))
        }
        let remainder = budget - allocated
        if remainder > 0, let remainderCategory = remainderCategoryName(excluding: mustSpendExclusionCategories) {
            let current = Double(categoryLimits[remainderCategory] ?? "0") ?? 0
            categoryLimits[remainderCategory] = String(Int((current + remainder).rounded(.down)))
        }
    }

    var mustSpendExclusionCategories: Set<String> {
        let excluded: Set<BaseCategory> = [.flight, .hotels]
        return Set(mustSpendItems.map { $0.category }.filter { excluded.contains($0) }.map { $0.rawValue })
    }

    private func adjustedPercentsForMustSpend(basePercents: [String: Double]) -> [String: Double] {
        guard !mustSpendExclusionCategories.isEmpty else { return basePercents }

        var filtered = basePercents
        for category in mustSpendExclusionCategories {
            filtered[category] = 0
        }

        let total = filtered.values.reduce(0, +)
        guard total > 0 else { return filtered }

        return filtered.mapValues { $0 / total }
    }

    private func remainderCategoryName(excluding excluded: Set<String>) -> String? {
        let preferred = "Food & Drinks"
        if !excluded.contains(preferred), categoryLimits.keys.contains(preferred) {
            return preferred
        }
        return categoryLimits.keys.first { !excluded.contains($0) }
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

    func addMustSpendItem() {
        let trimmed = mustSpendAmount.trimmingCharacters(in: .whitespaces)
        guard let value = Double(trimmed), value > 0 else { return }
        mustSpendItems.append(MustSpendItem(category: mustSpendCategory, amount: String(value)))
        if mustSpendExclusionCategories.contains(mustSpendCategory.rawValue) {
            priorityCategories.remove(mustSpendCategory.rawValue)
        }
        mustSpendAmount = ""
    }

    func removeMustSpendItem(_ item: MustSpendItem) {
        mustSpendItems.removeAll { $0.id == item.id }
    }

    func mustSpendAmountBinding(for item: MustSpendItem) -> Binding<String> {
        Binding(
            get: { [weak self] in
                self?.mustSpendItems.first(where: { $0.id == item.id })?.amount ?? ""
            },
            set: { [weak self] newValue in
                guard let index = self?.mustSpendItems.firstIndex(where: { $0.id == item.id }) else { return }
                self?.mustSpendItems[index].amount = newValue
            }
        )
    }

    func removeCustomCategory(_ category: ExpenseCategory) {
        categoryLimits.removeValue(forKey: category.name)
        customCategories.removeAll { $0.id == category.id }
    }

    func clearAllLimits() {
        categoryLimits.removeAll()
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
