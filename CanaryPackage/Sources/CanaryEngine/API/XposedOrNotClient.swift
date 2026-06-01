import Foundation

public final class XposedOrNotClient: Sendable {
    private let baseURL = "https://api.xposedornot.com/v1"
    private let session: URLSession
    private let rateLimiter: RateLimiter

    public init(
        session: URLSession = .shared,
        rateLimiter: RateLimiter = RateLimiter(requestsPerSecond: 2.0)
    ) {
        self.session = session
        self.rateLimiter = rateLimiter
    }

    public func checkEmail(_ email: String) async throws -> [XONBreach] {
        try await rateLimiter.acquire()

        // The detailed per-breach payload (with dates, record counts, and the
        // list of exposed data classes) lives on the `breach-analytics`
        // endpoint. The simpler `check-email` endpoint only returns breach
        // names, so it cannot populate `XONBreach`.
        guard var components = URLComponents(string: "\(baseURL)/breach-analytics") else {
            throw XONError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "email", value: email)]
        guard let url = components.url else {
            throw XONError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Canary", forHTTPHeaderField: "user-agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw XONError.httpError(0)
        }

        switch httpResponse.statusCode {
        case 200:
            let decoded = try JSONDecoder().decode(XONResponse.self, from: data)
            return decoded.exposedBreaches?.breachesDetails?.map { $0.toXONBreach() } ?? []
        case 404:
            // No breaches found for this address.
            return []
        default:
            throw XONError.httpError(httpResponse.statusCode)
        }
    }
}

public enum XONError: LocalizedError {
    case invalidURL
    case httpError(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid XposedOrNot URL"
        case .httpError(let code): return "XposedOrNot HTTP error \(code)"
        }
    }
}
