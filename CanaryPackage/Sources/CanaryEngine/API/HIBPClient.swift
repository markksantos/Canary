import Foundation

public final class HIBPClient: Sendable {
    private let baseURL = "https://haveibeenpwned.com/api/v3"
    private let passwordURL = "https://api.pwnedpasswords.com"
    private let session: URLSession
    private let rateLimiter: RateLimiter
    private let apiKeyProvider: @Sendable () -> String?

    public init(
        session: URLSession = .shared,
        rateLimiter: RateLimiter = RateLimiter(),
        apiKeyProvider: @escaping @Sendable () -> String?
    ) {
        self.session = session
        self.rateLimiter = rateLimiter
        self.apiKeyProvider = apiKeyProvider
    }

    // MARK: - Email Breach Check

    public func checkEmail(_ email: String) async throws -> [BreachModel] {
        guard let apiKey = apiKeyProvider() else {
            throw HIBPError.missingAPIKey
        }

        try await rateLimiter.acquire()

        let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email
        guard let url = URL(string: "\(baseURL)/breachedaccount/\(encoded)?truncateResponse=false") else {
            throw HIBPError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "hibp-api-key")
        request.setValue("Canary", forHTTPHeaderField: "user-agent")

        return try await perform(request, decoding: [BreachModel].self)
    }

    // MARK: - Paste Check

    public func checkPastes(_ email: String) async throws -> [PasteModel] {
        guard let apiKey = apiKeyProvider() else {
            throw HIBPError.missingAPIKey
        }

        try await rateLimiter.acquire()

        let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email
        guard let url = URL(string: "\(baseURL)/pasteaccount/\(encoded)") else {
            throw HIBPError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "hibp-api-key")
        request.setValue("Canary", forHTTPHeaderField: "user-agent")

        return try await perform(request, decoding: [PasteModel].self)
    }

    // MARK: - Password Check (k-anonymity)

    public func checkPassword(sha1Hash: String) async throws -> Int {
        let prefix = String(sha1Hash.prefix(5))
        let suffix = String(sha1Hash.dropFirst(5))

        try await rateLimiter.acquire()

        guard let url = URL(string: "\(passwordURL)/range/\(prefix)") else {
            throw HIBPError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue("Canary", forHTTPHeaderField: "user-agent")

        let (data, response) = try await session.data(for: request)
        try validateStatus(response)

        let responseString = String(data: data, encoding: .utf8) ?? ""
        for line in responseString.split(separator: "\r\n") {
            let parts = line.split(separator: ":")
            if parts.count == 2, parts[0].uppercased() == suffix.uppercased() {
                return Int(parts[1]) ?? 0
            }
        }

        return 0
    }

    // MARK: - Private

    private func perform<T: Decodable>(_ request: URLRequest, decoding type: T.Type) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HIBPError.httpError(0)
        }

        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode(type, from: data)
        case 404:
            // Return empty array for collection types
            if let empty = [String]() as? T { return empty }
            if let empty = [BreachModel]() as? T { return empty }
            if let empty = [PasteModel]() as? T { return empty }
            throw HIBPError.httpError(404)
        case 401:
            throw HIBPError.invalidAPIKey
        case 429:
            if let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After"),
               let seconds = Int(retryAfter) {
                try await Task.sleep(for: .seconds(seconds))
                return try await perform(request, decoding: type)
            }
            throw HIBPError.rateLimited
        default:
            throw HIBPError.httpError(httpResponse.statusCode)
        }
    }

    private func validateStatus(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HIBPError.httpError(0)
        }
        guard httpResponse.statusCode == 200 else {
            throw HIBPError.httpError(httpResponse.statusCode)
        }
    }
}

public enum HIBPError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case rateLimited
    case invalidURL
    case httpError(Int)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "HIBP API key not configured"
        case .invalidAPIKey: return "Invalid HIBP API key"
        case .rateLimited: return "Rate limited by HIBP API"
        case .invalidURL: return "Invalid URL"
        case .httpError(let code): return "HTTP error \(code)"
        }
    }
}
