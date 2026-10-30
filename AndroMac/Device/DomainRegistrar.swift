import FileProvider
import Foundation

/// Registers / removes File Provider domains when devices connect or disconnect.
/// Call from the host app (not the extension).
public enum DomainRegistrar {
    
    /// Domain identifier scheme: `andromac.<stable-device-id>`
    public static func domainIdentifier(for deviceID: DeviceID) -> String {
        let safe = deviceID.value
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        return "andromac.\(safe)"
    }
    
    public static func register(device: DeviceInfo) async throws {
        let id = domainIdentifier(for: device.id)
        let domain = NSFileProviderDomain(
            identifier: NSFileProviderDomainIdentifier(rawValue: id),
            displayName: device.displayName
        )
        do {
            try await NSFileProviderManager.add(domain)
            print("[DomainRegistrar] Added domain \(id) → \(device.displayName)")
        } catch {
            // Already registered is fine on reconnect
            print("[DomainRegistrar] add domain \(id): \(error.localizedDescription)")
        }
    }
    
    public static func unregister(deviceID: DeviceID) async throws {
        let id = domainIdentifier(for: deviceID)
        let domainID = NSFileProviderDomainIdentifier(rawValue: id)
        // Prefer removing by matching existing domain if the API surface allows;
        // constructing with identifier is enough for remove on current SDKs.
        let domain = NSFileProviderDomain(
            identifier: domainID,
            displayName: "Android"
        )
        do {
            try await NSFileProviderManager.remove(domain)
            print("[DomainRegistrar] Removed domain \(id)")
        } catch {
            print("[DomainRegistrar] remove domain \(id): \(error.localizedDescription)")
        }
    }
    
    public static func signalEnumerator(for deviceID: DeviceID) async throws {
        let id = domainIdentifier(for: deviceID)
        let domain = NSFileProviderDomain(
            identifier: NSFileProviderDomainIdentifier(rawValue: id),
            displayName: ""
        )
        guard let manager = NSFileProviderManager(for: domain) else { return }
        try await manager.signalEnumerator(for: .rootContainer)
    }
}
