import Foundation

public actor RateLimiter {
    private let maxTokens: Double
    private let refillRate: Double
    private var tokens: Double
    private var lastRefill: UInt64

    public init(requestsPerSecond: Double = 9.0) {
        self.maxTokens = requestsPerSecond
        self.refillRate = requestsPerSecond
        self.tokens = requestsPerSecond
        self.lastRefill = DispatchTime.now().uptimeNanoseconds
    }

    public func acquire() async throws {
        refill()

        while tokens < 1.0 {
            let waitMs = Int(((1.0 - tokens) / refillRate) * 1000) + 10
            try await Task.sleep(for: .milliseconds(waitMs))
            refill()
        }

        tokens -= 1.0
    }

    private func refill() {
        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = Double(now - lastRefill) / 1_000_000_000.0
        let newTokens = elapsed * refillRate
        tokens = min(maxTokens, tokens + newTokens)
        lastRefill = now
    }
}
