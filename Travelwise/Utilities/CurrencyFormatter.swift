import Foundation

enum CurrencyHelper {
    static let commonCurrencies: [(code: String, name: String)] = [
        ("USD", "US Dollar"),
        ("EUR", "Euro"),
        ("GBP", "British Pound"),
        ("JPY", "Japanese Yen"),
        ("CAD", "Canadian Dollar"),
        ("AUD", "Australian Dollar"),
        ("CHF", "Swiss Franc"),
        ("CNY", "Chinese Yuan"),
        ("SGD", "Singapore Dollar"),
        ("HKD", "Hong Kong Dollar"),
        ("KRW", "South Korean Won"),
        ("THB", "Thai Baht"),
        ("MYR", "Malaysian Ringgit"),
        ("INR", "Indian Rupee"),
        ("NZD", "New Zealand Dollar"),
        ("MXN", "Mexican Peso"),
        ("BRL", "Brazilian Real"),
        ("SEK", "Swedish Krona"),
        ("NOK", "Norwegian Krone"),
        ("DKK", "Danish Krone")
    ]

    static func format(_ amount: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(code) \(amount)"
    }

    static func symbol(for code: String) -> String {
        let locale = Locale.availableIdentifiers
            .map { Locale(identifier: $0) }
            .first { $0.currency?.identifier == code }
        return locale?.currencySymbol ?? code
    }
}
