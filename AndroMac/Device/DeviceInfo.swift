import Foundation

public struct DeviceInfo: Identifiable, Codable, Sendable, Hashable {
    public let id: DeviceID
    public var displayName: String
    public let manufacturer: String?
    public let model: String?
    public let serial: String?
    public let androidVersion: String?
    public let usbVendorID: UInt16?
    public let usbProductID: UInt16?
    public let usbSerial: String?
    
    public init(
        id: DeviceID,
        displayName: String,
        manufacturer: String? = nil,
        model: String? = nil,
        serial: String? = nil,
        androidVersion: String? = nil,
        usbVendorID: UInt16? = nil,
        usbProductID: UInt16? = nil,
        usbSerial: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.manufacturer = manufacturer
        self.model = model
        self.serial = serial
        self.androidVersion = androidVersion
        self.usbVendorID = usbVendorID
        self.usbProductID = usbProductID
        self.usbSerial = usbSerial
    }
    
    /// Strongest available stable identity for persistence.
    public static func makeStableID(
        serial: String?,
        usbSerial: String?,
        vendorID: UInt16?,
        productID: UInt16?,
        model: String?
    ) -> DeviceID {
        if let serial, !serial.isEmpty {
            return DeviceID("serial:\(serial)")
        }
        if let usbSerial, !usbSerial.isEmpty {
            return DeviceID("usb:\(usbSerial)")
        }
        let v = vendorID.map { String(format: "%04x", $0) } ?? "0000"
        let p = productID.map { String(format: "%04x", $0) } ?? "0000"
        let m = model ?? "unknown"
        return DeviceID("fallback:\(v)-\(p)-\(m)")
    }
}

public enum ConnectionState: String, Codable, Sendable {
    case disconnected
    case connecting
    case connected
    case ready
    case failed
}
