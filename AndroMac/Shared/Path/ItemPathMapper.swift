import Foundation
import FileProvider

/// Stable mapping between Finder item identifiers and Android remote paths.
/// Identifier format: "dev/<deviceID-hash>/path/to/item" (path URL-encoded segments)
public struct ItemPath: Hashable, Codable, Sendable {
    public let deviceID: DeviceID
    public let components: [String]
    
    public init(deviceID: DeviceID, components: [String] = []) {
        self.deviceID = deviceID
        self.components = components.filter { !$0.isEmpty }
    }
    
    public var remotePath: RemotePath {
        if components.isEmpty { return .root }
        return RemotePath("/" + components.joined(separator: "/"))
    }
    
    public func child(_ name: String) -> ItemPath {
        ItemPath(deviceID: deviceID, components: components + [name])
    }
    
    public var parent: ItemPath {
        guard !components.isEmpty else { return self }
        return ItemPath(deviceID: deviceID, components: Array(components.dropLast()))
    }
}

public enum ItemPathMapper {
    
    private static let prefix = "dev"
    
    public static func identifier(for path: ItemPath) -> NSFileProviderItemIdentifier {
        if path.components.isEmpty {
            // Per-device root under the domain (domain already scopes the device)
            return .rootContainer
        }
        let encoded = path.components
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? $0 }
            .joined(separator: "/")
        return NSFileProviderItemIdentifier(encoded)
    }
    
    public static func itemPath(
        from identifier: NSFileProviderItemIdentifier,
        deviceID: DeviceID
    ) -> ItemPath {
        if identifier == .rootContainer || identifier == .workingSet {
            return ItemPath(deviceID: deviceID, components: [])
        }
        let raw = identifier.rawValue
        let parts = raw
            .split(separator: "/")
            .map { String($0).removingPercentEncoding ?? String($0) }
            .filter { !$0.isEmpty }
        return ItemPath(deviceID: deviceID, components: parts)
    }
}
