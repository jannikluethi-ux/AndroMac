import Foundation

/// Lightweight pipeline timing for connection and transfer instrumentation.
public final class PipelineMetrics: @unchecked Sendable {
    public static let shared = PipelineMetrics()
    
    private let lock = NSLock()
    private var events: [(name: String, deviceID: String?, at: Date)] = []
    
    private init() {}
    
    public func mark(_ name: String, deviceID: String? = nil) {
        lock.lock()
        events.append((name, deviceID, Date()))
        lock.unlock()
        print("[Metrics] \(name)\(deviceID.map { " device=\($0)" } ?? "")")
    }
    
    public func reset() {
        lock.lock()
        events.removeAll()
        lock.unlock()
    }
    
    public func report() -> String {
        lock.lock()
        let snapshot = events
        lock.unlock()
        guard let first = snapshot.first else { return "No metrics recorded." }
        var lines: [String] = ["Pipeline metrics:"]
        for e in snapshot {
            let ms = Int(e.at.timeIntervalSince(first.at) * 1000)
            lines.append(String(format: "  +%5d ms  %@", ms, e.name))
        }
        return lines.joined(separator: "\n")
    }
}
