import Foundation

// MARK: - Core Identifiers

public struct DeviceID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let value: String
    
    public init(_ value: String) {
        self.value = value
    }
    
    public var description: String { value }
}

public struct RemotePath: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String
    
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
    
    public var description: String { rawValue }
    
    public static let root = RemotePath("/")
}

// MARK: - Remote Item Model

public enum RemoteItemKind: String, Codable, Sendable {
    case file
    case directory
    case unknown
}

public struct RemoteItem: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let path: RemotePath
    public let kind: RemoteItemKind
    public let size: Int64?
    public let modified: Date?
    public let isHidden: Bool
    
    public init(
        id: String,
        name: String,
        path: RemotePath,
        kind: RemoteItemKind,
        size: Int64? = nil,
        modified: Date? = nil,
        isHidden: Bool = false
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.kind = kind
        self.size = size
        self.modified = modified
        self.isHidden = isHidden
    }
}

public struct RemoteMetadata: Codable, Sendable {
    public let path: RemotePath
    public let kind: RemoteItemKind
    public let size: Int64?
    public let modified: Date?
    public let created: Date?
    public let permissions: String?
    
    public init(
        path: RemotePath,
        kind: RemoteItemKind,
        size: Int64? = nil,
        modified: Date? = nil,
        created: Date? = nil,
        permissions: String? = nil
    ) {
        self.path = path
        self.kind = kind
        self.size = size
        self.modified = modified
        self.created = created
        self.permissions = permissions
    }
}

// MARK: - Transport Protocol

public protocol AndroidTransport: Sendable {
    var deviceID: DeviceID { get }
    
    func connect() async throws
    func disconnect() async
    
    func list(_ path: RemotePath) async throws -> [RemoteItem]
    func stat(_ path: RemotePath) async throws -> RemoteMetadata
    
    func read(
        _ path: RemotePath,
        range: Range<Int64>?
    ) async throws -> AsyncThrowingStream<Data, Error>
    
    func write(
        _ path: RemotePath,
        data: AsyncThrowingStream<Data, Error>
    ) async throws
    
    func createDirectory(_ path: RemotePath) async throws
    func delete(_ path: RemotePath) async throws
    func move(_ source: RemotePath, to destination: RemotePath) async throws
}

// MARK: - Errors

public enum AndroidBridgeError: Error, LocalizedError, Sendable {
    case deviceNotFound
    case notConnected
    case transportUnavailable
    case permissionDenied
    case pathNotFound(RemotePath)
    case alreadyExists(RemotePath)
    case ioError(String)
    case cancelled
    case unsupportedOperation
    case usbError(String)
    case mtpError(String)
    case adbError(String)
    
    public var errorDescription: String? {
        switch self {
        case .deviceNotFound: return "Device not found"
        case .notConnected: return "Device is not connected"
        case .transportUnavailable: return "No usable transport (MTP/ADB) available"
        case .permissionDenied: return "Permission denied"
        case .pathNotFound(let p): return "Path not found: \(p)"
        case .alreadyExists(let p): return "Already exists: \(p)"
        case .ioError(let msg): return "I/O error: \(msg)"
        case .cancelled: return "Operation cancelled"
        case .unsupportedOperation: return "Unsupported operation"
        case .usbError(let msg): return "USB error: \(msg)"
        case .mtpError(let msg): return "MTP error: \(msg)"
        case .adbError(let msg): return "ADB error: \(msg)"
        }
    }
}
