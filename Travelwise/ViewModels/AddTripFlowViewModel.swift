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

    // MARK: - Smart Currency Inference

    /// Infers a trip currency from the destination name and updates `tripCurrency`
    /// if a confident match is found. Does nothing if no match is found so the
    /// user's existing selection is preserved.
    func inferCurrency(from name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return }
        guard let code = Self.currencyCode(for: trimmed) else { return }
        guard code != tripCurrency else { return }
        tripCurrency = code
        // Reset and pre-fetch immediately so the rate is ready by the time
        // the user reaches the budget step.
        exchangeRate = nil
        rateError = false
        Task { await fetchExchangeRate() }
    }

    /// Maps destination keywords (countries, regions, major cities) to ISO 4217
    /// currency codes. Matching is case-insensitive and checks whether any word
    /// in the lookup key appears as a whole word in the input.
    private static func currencyCode(for input: String) -> String? {
        let lower = input.lowercased()

        // Ordered from most-specific to least-specific so "new york" doesn't
        // accidentally match "york" before the full phrase is checked.
        let table: [(keywords: [String], code: String)] = [
            // Americas
            (["usa", "united states", "america", "new york", "los angeles", "chicago",
              "san francisco", "miami", "las vegas", "boston", "seattle", "hawaii",
              "washington", "texas", "california", "florida"], "USD"),
            (["canada", "toronto", "vancouver", "montreal", "calgary", "ottawa"], "CAD"),
            (["mexico", "cancun", "mexico city", "guadalajara", "tulum", "cabo"], "MXN"),
            (["brazil", "rio", "são paulo", "sao paulo", "brasilia", "salvador"], "BRL"),
            (["argentina", "buenos aires"], "ARS"),
            (["chile", "santiago"], "CLP"),
            (["colombia", "bogota", "medellin", "cartagena"], "COP"),
            (["peru", "lima", "machu picchu", "cusco"], "PEN"),
            (["cuba", "havana"], "CUP"),
            (["costa rica", "san jose"], "CRC"),
            (["jamaica", "kingston"], "JMD"),

            // Europe
            (["france", "paris", "nice", "marseille", "bordeaux", "lyon"], "EUR"),
            (["germany", "berlin", "munich", "frankfurt", "hamburg"], "EUR"),
            (["spain", "barcelona", "madrid", "seville", "ibiza", "mallorca", "valencia"], "EUR"),
            (["italy", "rome", "milan", "venice", "florence", "naples", "sicily",
              "amalfi", "tuscany"], "EUR"),
            (["greece", "athens", "santorini", "mykonos", "crete", "rhodes"], "EUR"),
            (["portugal", "lisbon", "porto", "algarve"], "EUR"),
            (["netherlands", "amsterdam", "rotterdam"], "EUR"),
            (["belgium", "brussels", "bruges", "antwerp"], "EUR"),
            (["austria", "vienna", "salzburg", "innsbruck"], "EUR"),
            (["ireland", "dublin"], "EUR"),
            (["finland", "helsinki"], "EUR"),
            (["croatia", "dubrovnik", "split", "zagreb"], "EUR"),
            (["uk", "united kingdom", "england", "london", "edinburgh", "manchester",
              "liverpool", "bristol", "oxford", "cambridge", "scotland", "wales"], "GBP"),
            (["switzerland", "zurich", "geneva", "bern", "lucerne"], "CHF"),
            (["norway", "oslo", "bergen", "tromsø", "tromso"], "NOK"),
            (["sweden", "stockholm", "gothenburg", "malmo"], "SEK"),
            (["denmark", "copenhagen"], "DKK"),
            (["poland", "warsaw", "krakow", "gdansk"], "PLN"),
            (["czechia", "czech", "prague", "brno"], "CZK"),
            (["hungary", "budapest"], "HUF"),
            (["romania", "bucharest"], "RON"),
            (["russia", "moscow", "st. petersburg", "saint petersburg"], "RUB"),
            (["turkey", "istanbul", "ankara", "cappadocia", "antalya", "bodrum"], "TRY"),
            (["ukraine", "kyiv"], "UAH"),

            // Asia
            (["japan", "tokyo", "osaka", "kyoto", "hiroshima", "sapporo", "nara",
              "hakone", "okinawa"], "JPY"),
            (["china", "beijing", "shanghai", "shenzhen", "guangzhou", "chengdu",
              "xian", "xi'an", "hangzhou", "suzhou", "guilin", "yunnan"], "CNY"),
            (["south korea", "korea", "seoul", "busan", "jeju"], "KRW"),
            (["hong kong"], "HKD"),
            (["taiwan", "taipei", "taichung", "tainan", "kaohsiung"], "TWD"),
            (["singapore"], "SGD"),
            (["thailand", "bangkok", "phuket", "chiang mai", "pattaya", "koh samui",
              "krabi"], "THB"),
            (["vietnam", "hanoi", "ho chi minh", "saigon", "danang", "hoi an",
              "ha long", "halong"], "VND"),
            (["indonesia", "bali", "jakarta", "lombok", "yogyakarta", "komodo"], "IDR"),
            (["malaysia", "kuala lumpur", "kl", "penang", "langkawi", "borneo"], "MYR"),
            (["philippines", "manila", "cebu", "boracay", "palawan"], "PHP"),
            (["india", "mumbai", "delhi", "new delhi", "goa", "jaipur", "agra",
              "varanasi", "kerala", "bangalore", "bengaluru", "kolkata", "taj mahal",
              "rajasthan"], "INR"),
            (["nepal", "kathmandu", "pokhara", "everest"], "NPR"),
            (["sri lanka", "colombo", "kandy", "sigiriya"], "LKR"),
            (["maldives", "malé", "male"], "MVR"),
            (["cambodia", "siem reap", "angkor", "phnom penh"], "KHR"),
            (["myanmar", "burma", "yangon", "bagan"], "MMK"),
            (["laos", "luang prabang", "vientiane"], "LAK"),
            (["mongolia", "ulaanbaatar"], "MNT"),
            (["pakistan", "islamabad", "lahore", "karachi"], "PKR"),
            (["bangladesh", "dhaka"], "BDT"),
            (["kazakhstan", "almaty", "astana"], "KZT"),
            (["uzbekistan", "tashkent", "samarkand", "bukhara"], "UZS"),
            (["georgia", "tbilisi", "batumi"], "GEL"),
            (["armenia", "yerevan"], "AMD"),
            (["azerbaijan", "baku"], "AZN"),

            // Middle East
            (["uae", "united arab emirates", "dubai", "abu dhabi"], "AED"),
            (["saudi arabia", "riyadh", "jeddah", "mecca"], "SAR"),
            (["israel", "tel aviv", "jerusalem"], "ILS"),
            (["jordan", "amman", "petra", "wadi rum"], "JOD"),
            (["egypt", "cairo", "luxor", "aswan", "hurghada", "sharm el sheikh"], "EGP"),
            (["morocco", "marrakech", "casablanca", "fes", "fez", "rabat", "tangier"], "MAD"),
            (["qatar", "doha"], "QAR"),
            (["kuwait", "kuwait city"], "KWD"),
            (["bahrain", "manama"], "BHD"),
            (["oman", "muscat", "salalah"], "OMR"),

            // Africa
            (["south africa", "cape town", "johannesburg", "safari", "kruger",
              "durban", "pretoria"], "ZAR"),
            (["kenya", "nairobi", "masai mara", "mombasa", "kilimanjaro"], "KES"),
            (["tanzania", "zanzibar", "dar es salaam", "serengeti"], "TZS"),
            (["ethiopia", "addis ababa"], "ETB"),
            (["ghana", "accra"], "GHS"),
            (["nigeria", "lagos", "abuja"], "NGN"),
            (["senegal", "dakar"], "XOF"),
            (["côte d'ivoire", "ivory coast", "abidjan"], "XOF"),
            (["madagascar"], "MGA"),
            (["mauritius"], "MUR"),
            (["seychelles", "seychelles islands"], "SCR"),
            (["zimbabwe", "harare", "victoria falls"], "ZWL"),
            (["zambia", "lusaka", "livingstone"], "ZMW"),
            (["botswana", "gaborone", "okavango"], "BWP"),
            (["namibia", "windhoek"], "NAD"),
            (["rwanda", "kigali"], "RWF"),
            (["uganda", "kampala"], "UGX"),

            // Oceania
            (["australia", "sydney", "melbourne", "brisbane", "perth", "gold coast",
              "cairns", "great barrier reef", "uluru"], "AUD"),
            (["new zealand", "auckland", "queenstown", "wellington", "christchurch",
              "rotorua", "fiordland"], "NZD"),
            (["fiji", "suva", "nadi"], "FJD"),
            (["hawaii"], "USD"),  // already covered above but explicit for clarity
        ]

        // Build a set of whole words from the input for efficient matching.
        let inputWords = Set(lower.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })

        for (keywords, code) in table {
            for keyword in keywords {
                // Multi-word keyword: check substring match.
                // Single-word keyword: check whole-word match to avoid false positives.
                let kwWords = keyword.components(separatedBy: " ")
                if kwWords.count > 1 {
                    if lower.contains(keyword) { return code }
                } else {
                    if inputWords.contains(keyword) { return code }
                }
            }
        }
        return nil
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

        // Only allocate categories with a non-zero percentage.
        let activeCategories = percents.filter { $0.value > 0 }
        guard !activeCategories.isEmpty else { return }

        // Step 1: Compute the exact (unrounded) share for each category.
        let exactAmounts: [(name: String, exact: Double)] = activeCategories.map { name, pct in
            (name, budget * pct)
        }

        // Step 2: Round each share DOWN to the nearest multiple of 5.
        var rounded: [String: Int] = [:]
        for item in exactAmounts {
            rounded[item.name] = roundDownTo5(item.exact)
        }

        // Step 3: The rounding-down leaves a deficit vs the total budget.
        // Distribute it in increments of 5, largest-remainder-first, so the
        // allocations always sum exactly to the (5-rounded) budget target.
        let targetTotal = roundDownTo5(budget)   // total budget rounded to nearest 5
        let currentTotal = rounded.values.reduce(0, +)
        var deficit = targetTotal - currentTotal  // always a multiple of 5 >= 0

        // Rank by how much was "lost" rounding down (i.e. exact - roundedDown).
        let remainders = exactAmounts
            .map { item in (name: item.name, loss: item.exact - Double(rounded[item.name]!)) }
            .sorted { $0.loss > $1.loss }

        var i = 0
        while deficit >= 5 && i < remainders.count {
            rounded[remainders[i].name, default: 0] += 5
            deficit -= 5
            i += 1
        }

        // Write allocations back.
        for (name, amount) in rounded {
            categoryLimits[name] = String(amount)
        }

        // Step 4: Add must-spend fixed costs on top, rounded to nearest 5.
        let mustSpendByCategory = Dictionary(grouping: mustSpendItems, by: { $0.category.rawValue })
            .mapValues { items in items.compactMap { Double($0.amount) }.reduce(0, +) }
        for (categoryName, amount) in mustSpendByCategory {
            let current = Double(categoryLimits[categoryName] ?? "0") ?? 0
            categoryLimits[categoryName] = String(roundDownTo5(current + amount))
        }
    }

    /// Rounds a value down to the nearest multiple of 5.
    private func roundDownTo5(_ value: Double) -> Int {
        let intVal = Int(value)
        return intVal - (intVal % 5)
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
        // Pre-warm the exchange rate cache so it's ready when the user adds expenses.
        ExchangeRateService.shared.warmUp(from: tripCurrency, to: homeCurrency)
    }
}
