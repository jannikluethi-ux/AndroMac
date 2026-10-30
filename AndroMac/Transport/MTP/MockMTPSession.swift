import Foundation

/// In-memory MTP session that mimics a typical Android phone layout.
/// Used for development and unit tests until a real backend (libmtp / pure Swift) is wired.
public actor MockMTPSession: MTPSession {
    
    public private(set) var isOpen = false
    
    private let storage = MTPStorageID(0x00010001)
    private var nextHandle: UInt32 = 100
    private var objects: [UInt32: MockObject] = [:]
    
    private struct MockObject {
        var handle: UInt32
        var parent: UInt32
        var name: String
        var isDir: Bool
        var size: UInt64
        var data: Data?
        var modified: Date
    }
    
    public init() {
        // Build a realistic Android tree
        // Root children
        let dcim = allocate(parent: 0, name: "DCIM", isDir: true)
        let download = allocate(parent: 0, name: "Download", isDir: true)
        let pictures = allocate(parent: 0, name: "Pictures", isDir: true)
        let movies = allocate(parent: 0, name: "Movies", isDir: true)
        let music = allocate(parent: 0, name: "Music", isDir: true)
        let documents = allocate(parent: 0, name: "Documents", isDir: true)
        _ = dcim; _ = download; _ = pictures; _ = movies; _ = music; _ = documents
        
        let camera = allocate(parent: dcim, name: "Camera", isDir: true)
        
        // Sample photo
        let photoData = Data("MOCK_JPEG_PAYLOAD_\(UUID().uuidString)".utf8)
        _ = allocate(
            parent: camera,
            name: "IMG_20260917_120000.jpg",
            isDir: false,
            size: UInt64(photoData.count),
            data: photoData
        )
        
        // Larger mock file for streaming tests (~1 MB)
        var big = Data()
        big.reserveCapacity(1_048_576)
        for i in 0..<1024 {
            big.append(contentsOf: Data(repeating: UInt8(i % 256), count: 1024))
        }
        _ = allocate(
            parent: download,
            name: "large_test_1mb.bin",
            isDir: false,
            size: UInt64(big.count),
            data: big
        )
    }
    
    private func allocate(
        parent: UInt32,
        name: String,
        isDir: Bool,
        size: UInt64 = 0,
        data: Data? = nil
    ) -> UInt32 {
        let h = nextHandle
        nextHandle += 1
        objects[h] = MockObject(
            handle: h,
            parent: parent,
            name: name,
            isDir: isDir,
            size: size,
            data: data,
            modified: Date()
        )
        return h
    }
    
    public func open() async throws {
        isOpen = true
    }
    
    public func close() async {
        isOpen = false
    }
    
    public func storageIDs() async throws -> [MTPStorageID] {
        try requireOpen()
        return [storage]
    }
    
    public func storageInfo(_ id: MTPStorageID) async throws -> MTPStorageInfo {
        try requireOpen()
        guard id == storage else { throw MTPError.operationFailed(.invalidStorageID) }
        return MTPStorageInfo(
            storageID: id,
            storageType: 0x0003, // fixed ROM
            filesystemType: 0x0002, // generic hierarchical
            accessCapability: 0x0000, // read/write
            maxCapacity: 128_000_000_000,
            freeSpaceInBytes: 64_000_000_000,
            freeSpaceInImages: 0xFFFFFFFF,
            storageDescription: "Internal shared storage",
            volumeIdentifier: "mock-android"
        )
    }
    
    public func objectHandles(
        storage: MTPStorageID,
        parent: MTPObjectHandle,
        format: MTPObjectFormat?
    ) async throws -> [MTPObjectHandle] {
        try requireOpen()
        let parentVal = parent.value == 0xFFFFFFFF ? 0 : parent.value
        return objects.values
            .filter { $0.parent == parentVal }
            .filter { format == nil || (format == .association) == $0.isDir }
            .map { MTPObjectHandle($0.handle) }
    }
    
    public func objectInfo(_ handle: MTPObjectHandle) async throws -> MTPObjectInfo {
        try requireOpen()
        guard let obj = objects[handle.value] else {
            throw MTPError.operationFailed(.invalidObjectHandle)
        }
        return MTPObjectInfo(
            handle: handle,
            storageID: storage,
            objectFormat: obj.isDir ? .association : .undefined,
            protectionStatus: 0,
            objectCompressedSize: obj.size,
            associationType: obj.isDir ? .genericFolder : .undefined,
            associationDesc: 0,
            parentObject: MTPObjectHandle(obj.parent == 0 ? 0xFFFFFFFF : obj.parent),
            filename: obj.name,
            captureDate: nil,
            modificationDate: obj.modified
        )
    }
    
    public func readObject(
        _ handle: MTPObjectHandle,
        range: Range<UInt64>?
    ) async throws -> AsyncThrowingStream<Data, Error> {
        try requireOpen()
        guard let obj = objects[handle.value], !obj.isDir else {
            throw MTPError.operationFailed(.invalidObjectHandle)
        }
        let data = obj.data ?? Data()
        let start = Int(range?.lowerBound ?? 0)
        let end = range.map { min(Int($0.upperBound), data.count) } ?? data.count
        guard start <= end, start <= data.count else {
            throw MTPError.ioFailure("Invalid range")
        }
        let slice = data.subdata(in: start..<end)
        
        return AsyncThrowingStream { continuation in
            // Stream in 64 KB chunks
            let chunkSize = 64 * 1024
            var offset = 0
            while offset < slice.count {
                let len = min(chunkSize, slice.count - offset)
                continuation.yield(slice.subdata(in: offset..<(offset + len)))
                offset += len
            }
            continuation.finish()
        }
    }
    
    public func sendObjectInfo(
        storage: MTPStorageID,
        parent: MTPObjectHandle,
        filename: String,
        size: UInt64,
        format: MTPObjectFormat
    ) async throws -> MTPObjectHandle {
        try requireOpen()
        let parentVal = parent.value == 0xFFFFFFFF ? 0 : parent.value
        let h = allocate(
            parent: parentVal,
            name: filename,
            isDir: false,
            size: size,
            data: Data()
        )
        return MTPObjectHandle(h)
    }
    
    public func sendObject(
        _ handle: MTPObjectHandle,
        data: AsyncThrowingStream<Data, Error>
    ) async throws {
        try requireOpen()
        guard var obj = objects[handle.value], !obj.isDir else {
            throw MTPError.operationFailed(.invalidObjectHandle)
        }
        var buffer = Data()
        for try await chunk in data {
            buffer.append(chunk)
        }
        obj.data = buffer
        obj.size = UInt64(buffer.count)
        obj.modified = Date()
        objects[handle.value] = obj
    }
    
    public func deleteObject(_ handle: MTPObjectHandle) async throws {
        try requireOpen()
        guard objects[handle.value] != nil else {
            throw MTPError.operationFailed(.invalidObjectHandle)
        }
        // Simple: delete only the object itself (no recursive)
        objects.removeValue(forKey: handle.value)
    }
    
    public func createFolder(
        storage: MTPStorageID,
        parent: MTPObjectHandle,
        name: String
    ) async throws -> MTPObjectHandle {
        try requireOpen()
        let parentVal = parent.value == 0xFFFFFFFF ? 0 : parent.value
        let h = allocate(parent: parentVal, name: name, isDir: true)
        return MTPObjectHandle(h)
    }
    
    private func requireOpen() throws {
        guard isOpen else { throw MTPError.sessionNotOpen }
    }
}
