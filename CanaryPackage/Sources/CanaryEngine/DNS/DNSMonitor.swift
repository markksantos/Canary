import Foundation
import Network

public final class DNSMonitor {
    public init() {}

    /// Resolves A records for a domain using NWConnection DNS resolution.
    public func resolveA(domain: String) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
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
                        continuation.resume(returning: [address])
                    } else {
                        connection.cancel()
                        continuation.resume(returning: [])
                    }
                case .failed(let error):
                    connection.cancel()
                    continuation.resume(throwing: error)
                case .cancelled:
                    break
                default:
                    break
                }
            }

            connection.start(queue: .global())

            // Timeout after 10 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                connection.cancel()
            }
        }
    }

    /// Resolves DNS records using dnssd framework via getaddrinfo for basic resolution.
    /// For MX/NS/TXT, uses a lightweight DNS query approach.
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
            let queryType: UInt16
            switch type {
            case .mx: queryType = 15
            case .ns: queryType = 2
            case .txt: queryType = 16
            case .a: queryType = 1
            }

            var queryRef: DNSServiceRef?
            let context = UnsafeMutablePointer<CheckedContinuation<[String], any Error>>.allocate(capacity: 1)
            context.initialize(to: continuation)

            let callback: DNSServiceQueryRecordReply = { _, _, _, errorCode, _, _, _, rdlen, rdata, _, context in
                guard let context = context else { return }
                let contPtr = context.assumingMemoryBound(to: CheckedContinuation<[String], any Error>.self)

                if errorCode != kDNSServiceErr_NoError {
                    contPtr.pointee.resume(returning: [])
                    contPtr.deinitialize(count: 1)
                    contPtr.deallocate()
                    return
                }

                if let rdata = rdata, rdlen > 0 {
                    let data = Data(bytes: rdata, count: Int(rdlen))
                    let record = String(data: data, encoding: .utf8) ?? data.map { String(format: "%02x", $0) }.joined()
                    contPtr.pointee.resume(returning: [record])
                } else {
                    contPtr.pointee.resume(returning: [])
                }
                contPtr.deinitialize(count: 1)
                contPtr.deallocate()
            }

            let err = DNSServiceQueryRecord(
                &queryRef, 0, 0,
                domain, queryType, UInt16(kDNSServiceClass_IN),
                callback, context
            )

            if err != kDNSServiceErr_NoError {
                context.deinitialize(count: 1)
                context.deallocate()
                continuation.resume(returning: [])
                return
            }

            guard let ref = queryRef else {
                context.deinitialize(count: 1)
                context.deallocate()
                continuation.resume(returning: [])
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
            }
        }
    }

    /// Checks all record types for a domain and compares against baselines.
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
