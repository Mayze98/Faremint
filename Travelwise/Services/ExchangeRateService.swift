import Foundation

/// Fetches live exchange rates from the Frankfurter API (https://api.frankfurter.app).
/// Rates are cached to disk for 24 hours. On network failure, a stale cached value is
/// returned as a fallback rather than surfacing an error to the user.
final class ExchangeRateService {

    static let shared = ExchangeRateService()

    private struct CachedRate: Codable {
        let rate: Double
        let fetchedAt: Date
    }

    private let cacheURL: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("exchange_rates.json")
    }()

    private let maxAge: TimeInterval = 60 * 60 * 24   // 24 hours
    private var cache: [String: CachedRate] = [:]

    private init() {
        loadCacheFromDisk()
    }

    /// Returns the exchange rate to convert one unit of `from` into `to`.
    /// Returns `1.0` immediately when both codes are equal.
    /// Falls back to a stale cached value if the network is unavailable.
    /// Throws only if no cached value exists and the network request fails.
    func rate(from: String, to: String) async throws -> Double {
        guard from != to else { return 1.0 }

        let key = "\(from)→\(to)"

        // Return disk-cached value if still fresh
        if let cached = cache[key], Date().timeIntervalSince(cached.fetchedAt) < maxAge {
            return cached.rate
        }

        do {
            let fetched = try await fetchFromNetwork(from: from, to: to)
            cache[key] = CachedRate(rate: fetched, fetchedAt: Date())
            saveCacheToDisk()
            return fetched
        } catch {
            // Network failed — return stale cache if available rather than showing an error
            if let stale = cache[key] {
                print("[ExchangeRate] Network failed, using stale cache for \(key): \(stale.rate)")
                return stale.rate
            }
            // Retry once after a short delay
            try await Task.sleep(for: .seconds(2))
            let retried = try await fetchFromNetwork(from: from, to: to)
            cache[key] = CachedRate(rate: retried, fetchedAt: Date())
            saveCacheToDisk()
            return retried
        }
    }

    // MARK: - Network

    private func fetchFromNetwork(from: String, to: String) async throws -> Double {
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

        return rate
    }

    // MARK: - Disk persistence

    private func loadCacheFromDisk() {
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode([String: CachedRate].self, from: data) else {
            return
        }
        cache = decoded
    }

    private func saveCacheToDisk() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: cacheURL, options: .atomic)
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
