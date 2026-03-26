import Foundation
import Network

public final class DNSMonitor {
    public init() {}

    /// Thread-safe one-shot continuation wrapper to prevent double-resume crashes.
    private final class ContinuationBox<T: Sendable>: @unchecked Sendable {
        private var continuation: CheckedContinuation<T, any Error>?
        private let lock = NSLock()

        init(_ continuation: CheckedContinuation<T, any Error>) {
            self.continuation = continuation
        }

        func resume(returning value: T) {
            lock.lock()
            let cont = continuation
            continuation = nil
            lock.unlock()
            cont?.resume(returning: value)
        }

        func resume(throwing error: any Error) {
            lock.lock()
            let cont = continuation
            continuation = nil
            lock.unlock()
            cont?.resume(throwing: error)
        }
    }

    /// Resolves A records for a domain using NWConnection DNS resolution.
    public func resolveA(domain: String) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let box = ContinuationBox(continuation)
            let host = NWEndpoint.Host(domain)
            let port = NWEndpoint.Port(integerLiteral: 443)
            let params = NWParameters.tcp
            let connection = NWConnection(host: host, port: port, using: params)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if let endpoint = connection.currentPath?.remoteEndpoint,
                       case .hostPort(let host, _) = endpoint {
                        let address: String
                        switch host {
                        case .ipv4(let ipv4):
                            address = "\(ipv4)"
                        case .ipv6(let ipv6):
                            address = "\(ipv6)"
                        default:
                            address = "\(host)"
                        }
                        connection.cancel()
                        box.resume(returning: [address])
                    } else {
                        connection.cancel()
                        box.resume(returning: [])
                    }
                case .failed(let error):
                    connection.cancel()
                    box.resume(throwing: error)
                case .cancelled:
                    box.resume(returning: [])
                default:
                    break
                }
            }

            connection.start(queue: .global())

            DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                connection.cancel()
            }
        }
    }

    public func resolve(domain: String, type: DNSRecordType) async throws -> [String] {
        switch type {
        case .a:
            return try await resolveA(domain: domain)
        case .mx, .ns, .txt:
            return try await resolveViaQuery(domain: domain, type: type)
        }
    }

    private func resolveViaQuery(domain: String, type: DNSRecordType) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let box = ContinuationBox(continuation)
            let queryType: UInt16
            switch type {
            case .mx: queryType = 15
            case .ns: queryType = 2
            case .txt: queryType = 16
            case .a: queryType = 1
            }

            var queryRef: DNSServiceRef?
            let boxPtr = UnsafeMutablePointer<ContinuationBox<[String]>>.allocate(capacity: 1)
            boxPtr.initialize(to: box)

            let callback: DNSServiceQueryRecordReply = { _, _, _, errorCode, _, _, _, rdlen, rdata, _, context in
                guard let context = context else { return }
                let boxPtr = context.assumingMemoryBound(to: ContinuationBox<[String]>.self)
                let box = boxPtr.pointee
                boxPtr.deinitialize(count: 1)
                boxPtr.deallocate()

                if errorCode != kDNSServiceErr_NoError {
                    box.resume(returning: [])
                    return
                }

                if let rdata = rdata, rdlen > 0 {
                    let data = Data(bytes: rdata, count: Int(rdlen))
                    let record = String(data: data, encoding: .utf8) ?? data.map { String(format: "%02x", $0) }.joined()
                    box.resume(returning: [record])
                } else {
                    box.resume(returning: [])
                }
            }

            let err = DNSServiceQueryRecord(
                &queryRef, 0, 0,
                domain, queryType, UInt16(kDNSServiceClass_IN),
                callback, boxPtr
            )

            if err != kDNSServiceErr_NoError {
                boxPtr.deinitialize(count: 1)
                boxPtr.deallocate()
                box.resume(returning: [])
                return
            }

            guard let ref = queryRef else {
                boxPtr.deinitialize(count: 1)
                boxPtr.deallocate()
                box.resume(returning: [])
                return
            }

            let fd = DNSServiceRefSockFD(ref)
            let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .global())
            source.setEventHandler {
                DNSServiceProcessResult(ref)
            }
            source.setCancelHandler {
                DNSServiceRefDeallocate(ref)
            }
            source.resume()

            DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                source.cancel()
                box.resume(returning: [])
            }
        }
    }

    public func checkDomain(_ domain: String, baselines: [DNSBaseline]) async -> [DNSDiff] {
        var diffs: [DNSDiff] = []

        for type in DNSRecordType.allCases {
            let currentRecords = (try? await resolve(domain: domain, type: type)) ?? []
            let baseline = baselines.first { $0.recordType == type }
            let baselineRecords = baseline?.records ?? []

            if !baselineRecords.isEmpty {
                let diff = DNSDiff.compare(baseline: baselineRecords, current: currentRecords, type: type)
                if diff.hasChanges {
                    diffs.append(diff)
                }
            }
        }

        return diffs
    }
}
