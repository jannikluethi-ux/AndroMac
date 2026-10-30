import Foundation

/// Production MTP session intended to call `MTPBridge` (C API over libmtp).
///
/// Until `MTPBridge.mm` is implemented and linked with real libmtp on a Mac,
/// `open()` fails with a clear error. Production code must **not** fall back to mock.
public actor LibMTPSession: MTPSession {
    
    public private(set) var isOpen = false
    
    private let preferredSerial: String?
    private let preferredVendorID: UInt16?
    private let preferredProductID: UInt16?
    
    public init(
        serial: String? = nil,
        vendorID: UInt16? = 0x22b8,
        productID: UInt16? = nil
    ) {
        self.preferredSerial = serial
        self.preferredVendorID = vendorID
        self.preferredProductID = productID
    }
    
    public func open() async throws {
        // Integration point: call MTPBridgeOpen(serial, vid, pid, &status).
        // MTPBridge.mm is currently a stub returning MTPBridgeNotSupported.
        // When libmtp is linked and MTPBridgeOpen succeeds, set isOpen = true.
        //
        // We deliberately do not call the C bridge from Swift until the Xcode
        // target has a bridging header / module map; that avoids compile failures
        // before the Mac bring-up step wires libmtp.
        throw MTPError.backendUnavailable(
            """
            Real MTP not linked yet. Implement MTPBridge.mm with libmtp \
            (brew install libmtp), add bridging header to AndroMacXPC, then \
            call MTPBridgeOpen. Device filter: serial=\(preferredSerial ?? "any") \
            VID=\(String(format: "0x%04x", preferredVendorID ?? 0x22b8)).
            """
        )
    }
    
    public func close() async {
        isOpen = false
    }
    
    public func storageIDs() async throws -> [MTPStorageID] {
        try requireOpen()
        return []
    }
    
    public func storageInfo(_ id: MTPStorageID) async throws -> MTPStorageInfo {
        try requireOpen()
        throw MTPError.unsupported
    }
    
    public func objectHandles(
        storage: MTPStorageID,
        parent: MTPObjectHandle,
        format: MTPObjectFormat?
    ) async throws -> [MTPObjectHandle] {
        try requireOpen()
        return []
    }
    
    public func objectInfo(_ handle: MTPObjectHandle) async throws -> MTPObjectInfo {
        try requireOpen()
        throw MTPError.unsupported
    }
    
    public func readObject(
        _ handle: MTPObjectHandle,
        range: Range<UInt64>?
    ) async throws -> AsyncThrowingStream<Data, Error> {
        try requireOpen()
        throw MTPError.unsupported
    }
    
    public func sendObjectInfo(
        storage: MTPStorageID,
        parent: MTPObjectHandle,
        filename: String,
        size: UInt64,
        format: MTPObjectFormat
    ) async throws -> MTPObjectHandle {
        try requireOpen()
        throw MTPError.unsupported
    }
    
    public func sendObject(
        _ handle: MTPObjectHandle,
        data: AsyncThrowingStream<Data, Error>
    ) async throws {
        try requireOpen()
        throw MTPError.unsupported
    }
    
    public func deleteObject(_ handle: MTPObjectHandle) async throws {
        try requireOpen()
        throw MTPError.unsupported
    }
    
    public func createFolder(
        storage: MTPStorageID,
        parent: MTPObjectHandle,
        name: String
    ) async throws -> MTPObjectHandle {
        try requireOpen()
        throw MTPError.unsupported
    }
    
    private func requireOpen() throws {
        guard isOpen else { throw MTPError.sessionNotOpen }
    }
}
