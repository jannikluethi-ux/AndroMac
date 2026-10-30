import Foundation

public enum TransferDirection: String, Codable, Sendable {
    case androidToMac
    case macToAndroid
}

public enum TransferState: String, Codable, Sendable {
    case queued
    case connecting
    case transferring
    case paused
    case cancelling
    case completed
    case failed
    case cancelled
}

public struct TransferRecord: Identifiable, Codable, Sendable {
    public let id: UUID
    public var source: String
    public var destination: String
    public var direction: TransferDirection
    public var bytesTransferred: Int64
    public var totalBytes: Int64?
    public var state: TransferState
    public var errorDescription: String?
    public var startedAt: Date?
    public var endedAt: Date?
    
    public var progress: Double {
        guard let total = totalBytes, total > 0 else { return 0 }
        return min(1.0, Double(bytesTransferred) / Double(total))
    }
}

/// Coordinates streaming transfers. Never loads whole multi‑GB files into memory on the pull path.
/// Push still may buffer when the transport requires a full stream (ADB push via temp file).
public actor TransferCoordinator {
    
    public static let shared = TransferCoordinator()
    
    private var active: [UUID: TransferRecord] = [:]
    private var observers: [UUID: @Sendable (TransferRecord) -> Void] = [:]
    
    private init() {}
    
    public func addObserver(_ handler: @escaping @Sendable (TransferRecord) -> Void) -> UUID {
        let id = UUID()
        observers[id] = handler
        return id
    }
    
    public func removeObserver(_ id: UUID) {
        observers.removeValue(forKey: id)
    }
    
    private func publish(_ record: TransferRecord) {
        active[record.id] = record
        for h in observers.values { h(record) }
    }
    
    public func activeTransfers() -> [TransferRecord] {
        Array(active.values)
    }
    
    /// Stream from Android transport → local file URL.
    public func pull(
        from remote: RemotePath,
        to localURL: URL,
        using transport: any AndroidTransport,
        totalBytes: Int64? = nil
    ) async throws -> TransferRecord {
        var record = TransferRecord(
            id: UUID(),
            source: remote.rawValue,
            destination: localURL.path,
            direction: .androidToMac,
            bytesTransferred: 0,
            totalBytes: totalBytes,
            state: .transferring,
            errorDescription: nil,
            startedAt: Date(),
            endedAt: nil
        )
        publish(record)
        
        do {
            if FileManager.default.fileExists(atPath: localURL.path) {
                try FileManager.default.removeItem(at: localURL)
            }
            FileManager.default.createFile(atPath: localURL.path, contents: nil)
            let handle = try FileHandle(forWritingTo: localURL)
            defer { try? handle.close() }
            
            let stream = try await transport.read(remote, range: nil)
            for try await chunk in stream {
                try handle.write(contentsOf: chunk)
                record.bytesTransferred += Int64(chunk.count)
                publish(record)
            }
            
            record.state = .completed
            record.endedAt = Date()
            publish(record)
            return record
        } catch {
            record.state = .failed
            record.errorDescription = error.localizedDescription
            record.endedAt = Date()
            publish(record)
            throw error
        }
    }
    
    /// Stream local file → Android transport (chunked read from disk).
    public func push(
        from localURL: URL,
        to remote: RemotePath,
        using transport: any AndroidTransport
    ) async throws -> TransferRecord {
        let attrs = try FileManager.default.attributesOfItem(atPath: localURL.path)
        let total = (attrs[.size] as? NSNumber)?.int64Value
        let transferID = UUID()
        
        var record = TransferRecord(
            id: transferID,
            source: localURL.path,
            destination: remote.rawValue,
            direction: .macToAndroid,
            bytesTransferred: 0,
            totalBytes: total,
            state: .transferring,
            errorDescription: nil,
            startedAt: Date(),
            endedAt: nil
        )
        publish(record)
        
        do {
            let handle = try FileHandle(forReadingFrom: localURL)
            defer { try? handle.close() }
            
            // Build stream on the actor so progress updates stay isolated
            let stream = AsyncThrowingStream<Data, Error> { continuation in
                Task {
                    do {
                        var transferred: Int64 = 0
                        while true {
                            let chunk = try handle.read(upToCount: 256 * 1024) ?? Data()
                            if chunk.isEmpty { break }
                            continuation.yield(chunk)
                            transferred += Int64(chunk.count)
                            await self.updateProgress(id: transferID, bytes: transferred)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
            
            try await transport.write(remote, data: stream)
            
            if var done = active[transferID] {
                done.state = .completed
                done.endedAt = Date()
                publish(done)
                return done
            }
            record.state = .completed
            record.endedAt = Date()
            publish(record)
            return record
        } catch {
            if var failed = active[transferID] {
                failed.state = .failed
                failed.errorDescription = error.localizedDescription
                failed.endedAt = Date()
                publish(failed)
            } else {
                record.state = .failed
                record.errorDescription = error.localizedDescription
                record.endedAt = Date()
                publish(record)
            }
            throw error
        }
    }
    
    private func updateProgress(id: UUID, bytes: Int64) {
        guard var r = active[id] else { return }
        r.bytesTransferred = bytes
        publish(r)
    }
}
