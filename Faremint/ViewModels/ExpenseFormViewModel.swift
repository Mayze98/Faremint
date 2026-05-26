import SwiftUI
import SwiftData
import CoreLocation

@Observable
final class ExpenseFormViewModel {
    var title: String
    var amount: String
    var selectedCategory: String
    var note: String
    var photoData: Data?

    // MARK: - Location
    var locationName: String?
    var latitude: Double?
    var longitude: Double?

    var hasLocation: Bool { latitude != nil && longitude != nil }

    // MARK: - Currency conversion

    /// The currency the user is currently typing in ("trip" or "home").
    var inputCurrency: String
    /// The user's home/preference currency read from UserDefaults.
    let homeCurrency: String
    /// The trip's own currency code, set on init.
    let tripCurrency: String
    /// Exchange rate: 1 unit of tripCurrency = exchangeRate units of homeCurrency.
    var exchangeRate: Double?
    /// Set to true when the Frankfurter fetch fails.
    var rateError: Bool = false

    /// True when the trip's currency differs from the home currency and a picker is needed.
    var needsConversion: Bool { tripCurrency != homeCurrency }

    /// Live preview of the converted amount in the *other* currency.
    var convertedPreview: String {
        guard needsConversion, let rate = exchangeRate, amountValue > 0 else { return "" }
        if inputCurrency == tripCurrency {
            // Showing the equivalent in home currency
            return "≈ \(CurrencyHelper.format(amountValue * rate, code: homeCurrency))"
        } else {
            // Showing the equivalent in trip currency
            return "≈ \(CurrencyHelper.format(amountValue / rate, code: tripCurrency))"
        }
    }

    // MARK: - Private

    private let existingExpense: Expense?

    var isEditing: Bool { existingExpense != nil }

    // MARK: - Init

    init(trip: Trip) {
        self.existingExpense = nil
        self.title = ""
        self.amount = ""
        self.selectedCategory = trip.categories.first?.name ?? "Food & Drinks"
        self.note = ""
        self.photoData = nil
        self.homeCurrency = UserDefaults.standard.string(forKey: "currencyCode") ?? "CAD"
        self.tripCurrency = trip.currency
        // Default input to trip's currency so the user types in local prices
        self.inputCurrency = trip.currency
    }

    init(expense: Expense) {
        self.existingExpense = expense
        self.title = expense.title
        self.amount = String(format: "%.2f", expense.originalAmount)
        self.selectedCategory = expense.categoryName
        self.note = expense.note
        self.photoData = expense.photoData
        self.locationName = expense.locationName
        self.latitude = expense.latitude
        self.longitude = expense.longitude
        self.homeCurrency = UserDefaults.standard.string(forKey: "currencyCode") ?? "CAD"
        self.tripCurrency = expense.trip?.currency ?? (UserDefaults.standard.string(forKey: "currencyCode") ?? "CAD")
        // When editing, the stored amount is already in home currency
        self.inputCurrency = self.homeCurrency
    }

    // MARK: - Computed

    // MARK: - Input Limits

    static let maxTitleLength = 100
    static let maxNoteLength = 500
    static let maxAmount = 1_000_000.0

    var amountValue: Double {
        let parsed = Double(amount) ?? 0
        return min(max(parsed, 0), Self.maxAmount)
    }

    var canSave: Bool {
        amountValue > 0
    }

    // MARK: - Exchange Rate

    func fetchExchangeRate() async {
        guard needsConversion else { exchangeRate = 1.0; return }
        do {
            exchangeRate = try await ExchangeRateService.shared.rate(from: tripCurrency, to: homeCurrency)
        } catch {
            print("[ExchangeRate] Failed to fetch \(tripCurrency)→\(homeCurrency): \(error)")
            rateError = true
            exchangeRate = nil
        }
    }

    // MARK: - Helpers

    /// Returns the amount in home currency, ensuring the rate is fetched if not yet available.
    private func homeAmount() -> Double {
        if inputCurrency == homeCurrency {
            return amountValue
        }
        guard let rate = exchangeRate else { return amountValue }
        return amountValue * rate
    }

    // MARK: - Save

    /// Ensures the exchange rate is loaded, then saves the expense.
    func saveNewExpense(trip: Trip, modelContext: ModelContext, firestoreService: FirestoreService) async {
        // Block save until rate is available
        if needsConversion && inputCurrency != homeCurrency && exchangeRate == nil {
            await fetchExchangeRate()
        }
        let converted = homeAmount()
        let clampedTitle = String(title.trimmingCharacters(in: .whitespaces).prefix(Self.maxTitleLength))
        let clampedNote = String(note.trimmingCharacters(in: .whitespaces).prefix(Self.maxNoteLength))
        let expense = Expense(
            title: clampedTitle,
            amount: converted,
            originalAmount: converted,
            splitPercent: nil,
            categoryName: selectedCategory,
            note: clampedNote,
            photoData: photoData,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            trip: trip
        )
        modelContext.insert(expense)
        trip.expenses.append(expense)
        firestoreService.saveExpense(expense)
        NotificationService.shared.checkBudgetThresholds(for: trip, pendingAmount: converted, pendingCategory: selectedCategory)
    }

    /// Ensures the exchange rate is loaded, then updates the expense.
    func updateExpense(firestoreService: FirestoreService) async {
        guard let expense = existingExpense else { return }
        if needsConversion && inputCurrency != homeCurrency && exchangeRate == nil {
            await fetchExchangeRate()
        }
        let converted = homeAmount()
        expense.title = String(title.trimmingCharacters(in: .whitespaces).prefix(Self.maxTitleLength))
        expense.originalAmount = converted
        expense.amount = converted
        expense.splitPercent = nil
        expense.categoryName = selectedCategory
        expense.note = String(note.trimmingCharacters(in: .whitespaces).prefix(Self.maxNoteLength))
        expense.photoData = photoData
        expense.latitude = latitude
        expense.longitude = longitude
        expense.locationName = locationName
        expense.updatedAt = .now
        firestoreService.saveExpense(expense)
        if let trip = expense.trip {
            NotificationService.shared.checkBudgetThresholds(for: trip)
        }
    }
}
