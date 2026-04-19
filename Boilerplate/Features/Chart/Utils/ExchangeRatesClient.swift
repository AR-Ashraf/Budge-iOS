import Foundation

/// Fetches Fawaz Ahmed currency-api style JSON (`{ "usd": { "eur": 0.92, ... } }`) for conversion into a base currency.
enum ExchangeRatesClient {
    private static var cache: [String: (rates: [String: Double], at: Date)] = [:]
    private static let ttl: TimeInterval = 3600

    static func rates(base: String) async -> [String: Double]? {
        let upper = base.uppercased()
        if let c = cache[upper], Date().timeIntervalSince(c.at) < ttl {
            return c.rates
        }
        let url = URL(string: "https://latest.currency-api.pages.dev/v1/currencies/\(upper.lowercased()).json")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let inner = obj[upper.lowercased()] as? [String: Any]
            else { return nil }
            var out: [String: Double] = [:]
            for (k, v) in inner {
                if let d = v as? Double {
                    out[k.uppercased()] = d
                } else if let n = v as? NSNumber {
                    out[k.uppercased()] = n.doubleValue
                }
            }
            out[upper] = 1
            cache[upper] = (out, Date())
            return out
        } catch {
            return nil
        }
    }

    /// Convert `amount` from `srcCurrency` to `baseCurrency` using rates where values are "how many base per 1 unit of key" per web `getExchangeRates`.
    static func convertToBase(amount: Double, srcCurrency: String, baseCurrency: String) async -> Double {
        let base = baseCurrency.uppercased()
        let from = srcCurrency.uppercased()
        if from == base { return amount }
        guard let rates = await rates(base: base) else { return amount }
        let rFrom = rates[from] ?? 1
        guard rFrom != 0 else { return amount }
        return amount / rFrom
    }
}
