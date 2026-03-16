import Foundation

public final class ScanScheduler {
    public enum Interval: Int, CaseIterable, Sendable {
        case oneHour = 3600
        case sixHours = 21600
        case twelveHours = 43200
        case twentyFourHours = 86400

        public var label: String {
            switch self {
            case .oneHour: return "Every hour"
            case .sixHours: return "Every 6 hours"
            case .twelveHours: return "Every 12 hours"
            case .twentyFourHours: return "Every 24 hours"
            }
        }
    }

    private var task: Task<Void, Never>?
    private var interval: Interval
    private let onScan: @Sendable () async -> Void

    public init(interval: Interval = .twentyFourHours, onScan: @escaping @Sendable () async -> Void) {
        self.interval = interval
        self.onScan = onScan
    }

    public func start() {
        stop()
        task = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval.rawValue))
                if Task.isCancelled { break }
                await onScan()
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }

    public func updateInterval(_ newInterval: Interval) {
        self.interval = newInterval
        if task != nil {
            start()
        }
    }
}
