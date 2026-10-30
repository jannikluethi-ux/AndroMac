import Foundation

/// Low-level MTP session. Implementations talk to libmtp, a pure-Swift stack, or a mock.
public protocol MTPSession: Sendable {
    var isOpen: Bool { get async }
    
    func open() async throws
    func close() async
    
    func storageIDs() async throws -> [MTPStorageID]
    func storageInfo(_ id: MTPStorageID) async throws -> MTPStorageInfo
    
    /// List children of a parent handle (use root parent for storage root).
    func objectHandles(
        storage: MTPStorageID,
        parent: MTPObjectHandle,
        format: MTPObjectFormat?
    ) async throws -> [MTPObjectHandle]
    
    func objectInfo(_ handle: MTPObjectHandle) async throws -> MTPObjectInfo
    
    /// Stream object data. Range is optional byte range (for resume / partial).
    func readObject(
        _ handle: MTPObjectHandle,
        range: Range<UInt64>?
    ) async throws -> AsyncThrowingStream<Data, Error>
    
    func sendObjectInfo(
        storage: MTPStorageID,
        parent: MTPObjectHandle,
        filename: String,
        size: UInt64,
        format: MTPObjectFormat
    ) async throws -> MTPObjectHandle
    
    func sendObject(
        _ handle: MTPObjectHandle,
        data: AsyncThrowingStream<Data, Error>
    ) async throws
    
    func deleteObject(_ handle: MTPObjectHandle) async throws
    func createFolder(
        storage: MTPStorageID,
        parent: MTPObjectHandle,
        name: String
    ) async throws -> MTPObjectHandle
}

// MARK: - Path resolution helpers (shared)

public struct MTPPathResolver: Sendable {
    public init() {}
    
    /// Split "/DCIM/Camera" → ["DCIM", "Camera"]
    public func components(of path: RemotePath) -> [String] {
        path.rawValue
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
    }
}
