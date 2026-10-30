import Foundation

/// One connected device: chosen transport + lifecycle.
public actor ConnectionSession {
    public let deviceID: DeviceID
    public let info: DeviceInfo
    private var transport: (any AndroidTransport)?
    private var connected = false
    
    public init(info: DeviceInfo) {
        self.deviceID = info.id
        self.info = info
    }
    
    public func ensureConnected() async throws -> any AndroidTransport {
        if let transport, connected {
            return transport
        }
        let t = await TransportFactory.makeTransport(
            for: info,
            preferADB: true,
            mode: .production
        )
        try await t.connect()
        self.transport = t
        self.connected = true
        PipelineMetrics.shared.mark("transport_connected", deviceID: deviceID.value)
        return t
    }
    
    public func disconnect() async {
        await transport?.disconnect()
        transport = nil
        connected = false
    }
}

/// Registry of live sessions keyed by device ID.
public actor ConnectionSessionStore {
    public static let shared = ConnectionSessionStore()
    
    private var sessions: [String: ConnectionSession] = [:]
    
    private init() {}
    
    public func session(for info: DeviceInfo) -> ConnectionSession {
        if let existing = sessions[info.id.value] {
            return existing
        }
        let s = ConnectionSession(info: info)
        sessions[info.id.value] = s
        return s
    }
    
    public func transport(for deviceID: DeviceID) async throws -> any AndroidTransport {
        guard let session = sessions[deviceID.value] else {
            // Try to revive from DeviceManager
            let devices = await DeviceManager.shared.knownDevices()
            guard let info = devices.first(where: { $0.id == deviceID }) else {
                throw AndroidBridgeError.deviceNotFound
            }
            let s = session(for: info)
            return try await s.ensureConnected()
        }
        return try await session.ensureConnected()
    }
    
    public func remove(_ deviceID: DeviceID) async {
        if let s = sessions.removeValue(forKey: deviceID.value) {
            await s.disconnect()
        }
    }
}
