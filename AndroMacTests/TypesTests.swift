import XCTest
@testable import AndroMac

final class TypesTests: XCTestCase {
    
    func testDeviceIDStable() {
        let id1 = DeviceInfo.makeStableID(
            serial: "ABC123",
            usbSerial: nil,
            vendorID: 0x18d1,
            productID: 0x4ee1,
            model: "Pixel"
        )
        let id2 = DeviceInfo.makeStableID(
            serial: "ABC123",
            usbSerial: "other",
            vendorID: 0x0000,
            productID: 0x0000,
            model: "Other"
        )
        XCTAssertEqual(id1, id2)
        XCTAssertEqual(id1.value, "serial:ABC123")
    }
    
    func testRemotePath() {
        let p = RemotePath("/DCIM/Camera")
        XCTAssertEqual(p.rawValue, "/DCIM/Camera")
    }
}
