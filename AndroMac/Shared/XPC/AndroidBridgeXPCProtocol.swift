import Foundation

/// XPC service name (must match Info.plist / launchd)
public let AndroMacXPCServiceName = "com.andromac.bridge"

/// Serializable device descriptor for XPC (no USB handles).
public struct XPCDeviceDescriptor: Codable, Sendable {
    public let id: String
    public let displayName: String
    public let manufacturer: String?
    public let model: String?
    public let serial: String?
    public let vendorID: UInt16?
    public let productID: UInt16?
    
    public init(from info: DeviceInfo) {
        self.id = info.id.value
        self.displayName = info.displayName
        self.manufacturer = info.manufacturer
        self.model = info.model
        self.serial = info.serial
        self.vendorID = info.usbVendorID
        self.productID = info.usbProductID
    }
}

public struct XPCRemoteItem: Codable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let size: Int64?
    public let modified: Date?
    
    public init(from item: RemoteItem) {
        self.id = item.id
        self.name = item.name
        self.path = item.path.rawValue
        self.isDirectory = item.kind == .directory
        self.size = item.size
        self.modified = item.modified
    }
    
    public func toRemoteItem() -> RemoteItem {
        RemoteItem(
            id: id,
            name: name,
            path: RemotePath(path),
            kind: isDirectory ? .directory : .file,
            size: size,
            modified: modified
        )
    }
}

public struct XPCRemoteMetadata: Codable, Sendable {
    public let path: String
    public let isDirectory: Bool
    public let size: Int64?
    public let modified: Date?
    
    public init(from meta: RemoteMetadata) {
        self.path = meta.path.rawValue
        self.isDirectory = meta.kind == .directory
        self.size = meta.size
        self.modified = meta.modified
    }
}

/// Typed XPC API. Only Codable / Sendable domain values cross the boundary.
@objc public protocol AndroidBridgeXPCProtocol {
    func listDevices(with reply: @escaping ([Data]?, Error?) -> Void)
    
    func listDirectory(
        deviceID: String,
        path: String,
        with reply: @escaping ([Data]?, Error?) -> Void
    )
    
    func metadata(
        deviceID: String,
        path: String,
        with reply: @escaping (Data?, Error?) -> Void
    )
    
    /// Returns a temporary file URL path for the fetched content (streamed server-side).
    func fetchToTempFile(
        deviceID: String,
        path: String,
        with reply: @escaping (String?, Error?) -> Void
    )
    
    func writeFromFile(
        deviceID: String,
        path: String,
        localFilePath: String,
        with reply: @escaping (Error?) -> Void
    )
    
    func createDirectory(
        deviceID: String,
        path: String,
        with reply: @escaping (Error?) -> Void
    )
    
    func deleteItem(
        deviceID: String,
        path: String,
        with reply: @escaping (Error?) -> Void
    )
}

// MARK: - Host-side async client

public final class AndroidBridgeXPCClient: @unchecked Sendable {
    private let connection: NSXPCConnection
    
    public init(serviceName: String = AndroMacXPCServiceName) {
        connection = NSXPCConnection(serviceName: serviceName)
        connection.remoteObjectInterface = NSXPCInterface(with: AndroidBridgeXPCProtocol.self)
        connection.resume()
    }
    
    deinit {
        connection.invalidate()
    }
    
    private var proxy: AndroidBridgeXPCProtocol {
        connection.remoteObjectProxyWithErrorHandler { error in
            print("[XPCClient] error: \(error)")
        } as! AndroidBridgeXPCProtocol
    }
    
    public func devices() async throws -> [XPCDeviceDescriptor] {
        try await withCheckedThrowingContinuation { cont in
            proxy.listDevices { data, error in
                if let error { cont.resume(throwing: error); return }
                let list = (data ?? []).compactMap { try? JSONDecoder().decode(XPCDeviceDescriptor.self, from: $0) }
                cont.resume(returning: list)
            }
        }
    }
    
    public func list(deviceID: String, path: String) async throws -> [XPCRemoteItem] {
        try await withCheckedThrowingContinuation { cont in
            proxy.listDirectory(deviceID: deviceID, path: path) { data, error in
                if let error { cont.resume(throwing: error); return }
                let list = (data ?? []).compactMap { try? JSONDecoder().decode(XPCRemoteItem.self, from: $0) }
                cont.resume(returning: list)
            }
        }
    }
    
    public func metadata(deviceID: String, path: String) async throws -> XPCRemoteMetadata {
        try await withCheckedThrowingContinuation { cont in
            proxy.metadata(deviceID: deviceID, path: path) { data, error in
                if let error { cont.resume(throwing: error); return }
                guard let data,
                      let meta = try? JSONDecoder().decode(XPCRemoteMetadata.self, from: data) else {
                    cont.resume(throwing: AndroidBridgeError.ioError("Bad metadata response"))
                    return
                }
                cont.resume(returning: meta)
            }
        }
    }
    
    public func fetchToTempFile(deviceID: String, path: String) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            proxy.fetchToTempFile(deviceID: deviceID, path: path) { path, error in
                if let error { cont.resume(throwing: error); return }
                guard let path else {
                    cont.resume(throwing: AndroidBridgeError.ioError("No temp path"))
                    return
                }
                cont.resume(returning: URL(fileURLWithPath: path))
            }
        }
    }
    
    public func writeFromFile(deviceID: String, path: String, localFile: URL) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            proxy.writeFromFile(deviceID: deviceID, path: path, localFilePath: localFile.path) { error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            }
        }
    }
    
    public func createDirectory(deviceID: String, path: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            proxy.createDirectory(deviceID: deviceID, path: path) { error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            }
        }
    }
    
    public func deleteItem(deviceID: String, path: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            proxy.deleteItem(deviceID: deviceID, path: path) { error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            }
        }
    }
}
