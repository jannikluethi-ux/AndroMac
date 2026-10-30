import XCTest
@testable import AndroMac

final class MTPTransportTests: XCTestCase {
    
    func testListRoot() async throws {
        let transport = MTPTransport(deviceID: DeviceID("test"), session: MockMTPSession())
        try await transport.connect()
        
        let items = try await transport.list(RemotePath.root)
        let names = Set(items.map(\.name))
        
        XCTAssertTrue(names.contains("DCIM"))
        XCTAssertTrue(names.contains("Download"))
        XCTAssertTrue(names.contains("Pictures"))
        
        await transport.disconnect()
    }
    
    func testListDCIMAndReadPhoto() async throws {
        let transport = MTPTransport(deviceID: DeviceID("test"), session: MockMTPSession())
        try await transport.connect()
        
        let dcim = try await transport.list(RemotePath("/DCIM"))
        XCTAssertTrue(dcim.contains { $0.name == "Camera" })
        
        let camera = try await transport.list(RemotePath("/DCIM/Camera"))
        XCTAssertFalse(camera.isEmpty)
        
        let photo = try XCTUnwrap(camera.first { $0.kind == .file })
        var total = 0
        for try await chunk in try await transport.read(photo.path, range: nil) {
            total += chunk.count
        }
        XCTAssertGreaterThan(total, 0)
        
        await transport.disconnect()
    }
    
    func testStreamLargeFile() async throws {
        let transport = MTPTransport(deviceID: DeviceID("test"), session: MockMTPSession())
        try await transport.connect()
        
        let path = RemotePath("/Download/large_test_1mb.bin")
        var total = 0
        for try await chunk in try await transport.read(path, range: nil) {
            total += chunk.count
        }
        XCTAssertEqual(total, 1_048_576)
        
        await transport.disconnect()
    }
    
    func testCreateWriteDelete() async throws {
        let transport = MTPTransport(deviceID: DeviceID("test"), session: MockMTPSession())
        try await transport.connect()
        
        let dir = RemotePath("/Download/AndromacTest")
        try await transport.createDirectory(dir)
        
        let filePath = RemotePath("/Download/AndromacTest/hello.txt")
        let payload = Data("hello from Andromac".utf8)
        let stream = AsyncThrowingStream<Data, Error> { cont in
            cont.yield(payload)
            cont.finish()
        }
        try await transport.write(filePath, data: stream)
        
        var readBack = Data()
        for try await chunk in try await transport.read(filePath, range: nil) {
            readBack.append(chunk)
        }
        XCTAssertEqual(readBack, payload)
        
        try await transport.delete(filePath)
        try await transport.delete(dir)
        
        await transport.disconnect()
    }
}
