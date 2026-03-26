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

        let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email
        guard let url = URL(string: "\(baseURL)/check-email/\(encoded)") else {
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
