import Foundation

public struct DiagnosticsSnapshot: Codable, Sendable {
    public var exportedAt: Date
    public var appVersion: String
    public var devices: [DeviceDiagnostics]
    
    public struct DeviceDiagnostics: Codable, Sendable {
        public var id: String
        public var displayName: String
        public var manufacturer: String?
        public var model: String?
        public var serial: String?
        public var usbVendorID: String?
        public var usbProductID: String?
        public var connectionState: String
        public var notes: String?
    }
}

public enum DiagnosticsExport {
    
    public static func snapshot(
        devices: [DeviceInfo],
        states: [DeviceID: ConnectionState]
    ) -> DiagnosticsSnapshot {
        DiagnosticsSnapshot(
            exportedAt: Date(),
            appVersion: "0.1-m4",
            devices: devices.map { d in
                DiagnosticsSnapshot.DeviceDiagnostics(
                    id: d.id.value,
                    displayName: d.displayName,
                    manufacturer: d.manufacturer,
                    model: d.model,
                    serial: d.serial.map { String($0.prefix(4)) + "…" }, // redacted
                    usbVendorID: d.usbVendorID.map { String(format: "0x%04x", $0) },
                    usbProductID: d.usbProductID.map { String(format: "0x%04x", $0) },
                    connectionState: (states[d.id] ?? .disconnected).rawValue,
                    notes: DeviceProfile.match(
                        manufacturer: d.manufacturer,
                        model: d.model,
                        vendorID: d.usbVendorID
                    )?.notes
                )
            }
        )
    }
    
    public static func jsonString(_ snap: DiagnosticsSnapshot) throws -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(snap)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
