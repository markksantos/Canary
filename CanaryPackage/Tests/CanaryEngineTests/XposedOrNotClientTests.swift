import Testing
import Foundation
@testable import CanaryEngine

@Suite("XposedOrNot Client Tests", .serialized)
struct XposedOrNotClientTests {
    let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }()

    /// Mirrors the real `breach-analytics` response shape: detailed breaches
    /// live under `ExposedBreaches.breaches_details`, with `xposed_data`
    /// delimited by ";".
    @Test("Parses breaches from breach-analytics endpoint")
    func parsesBreaches() async throws {
        let json = """
        {
          "BreachMetrics": {},
          "ExposedBreaches": {
            "breaches_details": [
              {
                "breach": "Adobe",
                "domain": "adobe.com",
                "xposed_date": "2013",
                "xposed_data": "Email addresses;Password hints;Passwords;Usernames",
                "xposed_records": 152445165,
                "verified": "Yes"
              }
            ]
          }
        }
        """

        MockURLProtocol.register(
            url: "https://api.xposedornot.com/v1/breach-analytics?email=test@example.com",
            statusCode: 200,
            body: json
        )

        let client = XposedOrNotClient(session: session)
        let breaches = try await client.checkEmail("test@example.com")

        #expect(breaches.count == 1)
        let first = try #require(breaches.first)
        #expect(first.breachName == "Adobe")
        #expect(first.domain == "adobe.com")
        #expect(first.exposedRecords == 152_445_165)
        #expect(first.exposedData == ["Email addresses", "Password hints", "Passwords", "Usernames"])
    }

    @Test("Returns empty for clean email (404)")
    func cleanEmail() async throws {
        // No registration -> MockURLProtocol returns 404 by default.
        let client = XposedOrNotClient(session: session)
        let breaches = try await client.checkEmail("clean@example.com")
        #expect(breaches.isEmpty)
    }

    @Test("Returns empty when no ExposedBreaches present")
    func noExposedBreaches() async throws {
        MockURLProtocol.register(
            url: "https://api.xposedornot.com/v1/breach-analytics?email=none@example.com",
            statusCode: 200,
            body: #"{"BreachMetrics": {}}"#
        )

        let client = XposedOrNotClient(session: session)
        let breaches = try await client.checkEmail("none@example.com")
        #expect(breaches.isEmpty)
    }
}
