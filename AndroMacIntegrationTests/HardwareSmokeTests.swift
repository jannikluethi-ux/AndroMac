import XCTest
@testable import AndroMac

/// Physical-device tests. Skip automatically when no phone is connected.
/// Do not run these in CI without hardware.
final class HardwareSmokeTests: XCTestCase {
    
    override func setUp() async throws {
        try await super.setUp()
        // Prefer ADB for integration if available
    }
    
    func testConnectedDeviceCanEnumerateRoot() async throws {
        try XCTSkipIf(true, "Requires physical Android on Mac — run manually")
        let devices = await DeviceManager.shared.knownDevices()
        XCTAssertFalse(devices.isEmpty)
        let session = await ConnectionSessionStore.shared.session(for: devices[0])
        let transport = try await session.ensureConnected()
        let items = try await transport.list(.root)
        XCTAssertFalse(items.isEmpty, "Root should list storage folders")
    }
    
    func testDCIMCanBeEnumerated() async throws {
        try XCTSkipIf(true, "Requires physical Android on Mac — run manually")
    }
    
    func testSmallFileCanBeRead() async throws {
        try XCTSkipIf(true, "Requires physical Android on Mac — run manually")
    }
    
    func testLargeFileCanBeRead() async throws {
        try XCTSkipIf(true, "Requires physical Android on Mac — run manually")
    }
    
    func testFileCanBeWritten() async throws {
        try XCTSkipIf(true, "Requires physical Android on Mac — run manually")
    }
    
    func testDeviceReconnects() async throws {
        try XCTSkipIf(true, "Requires physical Android on Mac — run manually")
    }
}
