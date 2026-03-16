import Testing
import Foundation
@testable import CanaryEngine

// MARK: - Mock URLProtocol

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var mockData: [String: Data] = [:]
    nonisolated(unsafe) static var mockCodes: [String: Int] = [:]

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url!.absoluteString
        let statusCode = Self.mockCodes[url] ?? 404
        let data = Self.mockData[url] ?? Data()

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func register(url: String, statusCode: Int, data: Data) {
        mockData[url] = data
        mockCodes[url] = statusCode
    }

    static func register(url: String, statusCode: Int, body: String) {
        register(url: url, statusCode: statusCode, data: body.data(using: .utf8)!)
    }

    static func reset() {
        mockData.removeAll()
        mockCodes.removeAll()
    }
}

// MARK: - Tests

@Suite("HIBPClient Tests", .serialized)
struct HIBPClientTests {
    let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }()

    init() {
        MockURLProtocol.reset()
    }

    @Test("Password check returns exposure count")
    func passwordCheck() async throws {
        let hash = PasswordHasher.sha1Hash(of: "password")
        let prefix = String(hash.prefix(5))
        let suffix = String(hash.dropFirst(5))

        MockURLProtocol.register(
            url: "https://api.pwnedpasswords.com/range/\(prefix)",
            statusCode: 200,
            body: "\(suffix):9545824\r\nABCDEF1234567890ABCDEF1234567890ABC:3\r\n"
        )

        let client = HIBPClient(session: session, apiKeyProvider: { "test-key" })
        let count = try await client.checkPassword(sha1Hash: hash)
        #expect(count == 9545824)
    }

    @Test("Password check returns 0 for clean password")
    func cleanPassword() async throws {
        MockURLProtocol.register(
            url: "https://api.pwnedpasswords.com/range/ABCDE",
            statusCode: 200,
            body: "1234567890ABCDEF1234567890ABCDEF123:5\r\n"
        )

        let client = HIBPClient(session: session, apiKeyProvider: { "test-key" })
        let count = try await client.checkPassword(sha1Hash: "ABCDE" + "FGHIJ1234567890ABCDEF1234567890ABCDE")
        #expect(count == 0)
    }

    @Test("Email check returns breaches")
    func emailCheck() async throws {
        let breachJSON = """
        [{"Name":"TestBreach","Title":"Test Breach","Domain":"test.com","BreachDate":"2024-01-01","AddedDate":"2024-01-15T00:00:00Z","ModifiedDate":"2024-01-15T00:00:00Z","PwnCount":1000000,"Description":"Test breach","LogoPath":"https://example.com/logo.png","DataClasses":["Email addresses","Passwords"],"IsVerified":true,"IsFabricated":false,"IsSensitive":false,"IsRetired":false,"IsSpamList":false,"IsMalware":false,"IsSubscriptionFree":false}]
        """

        MockURLProtocol.register(
            url: "https://haveibeenpwned.com/api/v3/breachedaccount/test@example.com?truncateResponse=false",
            statusCode: 200,
            data: breachJSON.data(using: .utf8)!
        )

        let client = HIBPClient(session: session, apiKeyProvider: { "test-key" })
        let breaches = try await client.checkEmail("test@example.com")
        #expect(breaches.count == 1)
        #expect(breaches.first?.name == "TestBreach")
        #expect(breaches.first?.pwnCount == 1000000)
    }

    @Test("Missing API key throws error")
    func missingAPIKey() async {
        let client = HIBPClient(session: session, apiKeyProvider: { nil })
        do {
            _ = try await client.checkEmail("test@example.com")
            Issue.record("Expected error")
        } catch {
            #expect(error is HIBPError)
        }
    }

    @Test("404 returns empty array")
    func notFound() async throws {
        let client = HIBPClient(session: session, apiKeyProvider: { "test-key" })
        let breaches = try await client.checkEmail("clean@example.com")
        #expect(breaches.isEmpty)
    }
}
