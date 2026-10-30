import Foundation

/// Selects ADB or MTP for a device. Production never silently uses mock MTP.
public enum TransportFactory {
    
    public enum Mode: Sendable {
        /// Prefer ADB when serial is known; otherwise real LibMTP session.
        case production
        /// Unit tests only — MockMTPSession.
        case unitTestMockMTP
    }
    
    /// Production: ADB if preferred + serial present; else real MTP (`LibMTPSession`).
    /// Real MTP will fail at `connect()` until libmtp is linked — that is intentional.
    public static func makeTransport(
        for info: DeviceInfo,
        preferADB: Bool = true,
        mode: Mode = .production
    ) async -> any AndroidTransport {
        if mode == .unitTestMockMTP {
            return MTPTransport(deviceID: info.id, session: MockMTPSession())
        }
        
        let profile = DeviceProfile.match(
            manufacturer: info.manufacturer,
            model: info.model,
            vendorID: info.usbVendorID
        )
        let wantADB = preferADB && (profile?.prefersADB ?? true)
        
        if wantADB, let serial = info.serial ?? info.usbSerial {
            return ADBTransport(deviceID: info.id, serial: serial)
        }
        
        let session = LibMTPSession(
            serial: info.serial ?? info.usbSerial,
            vendorID: info.usbVendorID ?? 0x22b8,
            productID: info.usbProductID
        )
        return MTPTransport(deviceID: info.id, session: session)
    }
}
