import Foundation

/// Fetches live exchange rates from the Frankfurter API (https://api.frankfurter.app).
/// Rates are cached in memory for the app session to avoid redundant network calls.
final class ExchangeRateService {

    static let shared = ExchangeRateService()

    private var cache: [String: Double] = [:]

    private init() {}

    /// Returns the exchange rate to convert one unit of `from` into `to`.
    /// Returns `1.0` immediately when both codes are equal.
    /// Throws if the network request fails or the response cannot be parsed.
    func rate(from: String, to: String) async throws -> Double {
        guard from != to else { return 1.0 }

        let key = "\(from)→\(to)"
        if let cached = cache[key] { return cached }

        var components = URLComponents(string: "https://api.frankfurter.app/latest")!
        components.queryItems = [
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to", value: to)
        ]
        guard let url = components.url else {
            throw ExchangeRateError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ExchangeRateError.badResponse
        }

        struct FrankfurterResponse: Decodable {
            let rates: [String: Double]
        }

        let decoded = try JSONDecoder().decode(FrankfurterResponse.self, from: data)

        guard let rate = decoded.rates[to] else {
            throw ExchangeRateError.missingRate(to)
        }

        cache[key] = rate
        return rate
    }
}

enum ExchangeRateError: LocalizedError {
    case invalidURL
    case badResponse
    case missingRate(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:       return "Invalid exchange rate URL."
        case .badResponse:      return "Exchange rate server returned an unexpected response."
        case .missingRate(let code): return "Exchange rate for \(code) not found in response."
        }
    }
}
