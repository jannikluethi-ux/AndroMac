import Foundation
import IOKit
import IOKit.usb

/// Event-driven USB device discovery using IOKit notifications.
/// No polling. Registers for matched / terminated events on IOUSBDevice.
public final class USBDiscovery: @unchecked Sendable {
    
    public enum Event {
        case attached(USBDeviceSnapshot)
        case detached(locationID: UInt32)
    }
    
    public struct USBDeviceSnapshot: Sendable {
        public let locationID: UInt32
        public let vendorID: UInt16
        public let productID: UInt16
        public let serial: String?
        public let vendorName: String?
        public let productName: String?
        public let isLikelyAndroid: Bool
    }
    
    public var onEvent: (@Sendable (Event) -> Void)?
    
    private var notificationPort: IONotificationPortRef?
    private var matchedIterator: io_iterator_t = 0
    private var terminatedIterator: io_iterator_t = 0
    private let queue = DispatchQueue(label: "com.andromac.usbdiscovery")
    
    // Known Android vendor IDs (from ADB / usb.ids / udev rules)
    private static let androidVendorIDs: Set<UInt16> = [
        0x18d1, // Google
        0x04e8, // Samsung
        0x2717, // Xiaomi
        0x05c6, // Qualcomm (many OEMs)
        0x2a70, // OnePlus
        0x0bb4, // HTC
        0x12d1, // Huawei
        0x22b8, // Motorola
        0x0fce, // Sony
        0x2a45, // Meizu
        0x29a9, // Yulong / Coolpad
        0x19d2, // ZTE
        0x0e79, // Archos
        0x0489, // Foxconn / some others
        0x04c5, // Fujitsu
        0x2080, // Nook / Barnes & Noble (older)
        0x1bbb, // T-Mobile / Alcatel
        0x1f3a, // Allwinner
        0x2207, // Rockchip
        0x0b05, // ASUS
        0x04dd, // Sharp
        0x0930, // Toshiba
        0x1d4d, // Pegatron
        0x2b4c, // ZUK / Lenovo
        0x2e04, // Fairphone / some
    ]
    
    public init() {}
    
    deinit {
        stop()
    }
    
    // MARK: - Public
    
    public func start() {
        queue.async { [weak self] in
            self?._start()
        }
    }
    
    public func stop() {
        queue.async { [weak self] in
            self?._stop()
        }
    }
    
    // MARK: - Implementation
    
    private func _start() {
        guard notificationPort == nil else { return }
        
        let port = IONotificationPortCreate(kIOMainPortDefault)
        guard let port else {
            print("[USBDiscovery] Failed to create notification port")
            return
        }
        notificationPort = port
        
        // Add the notification port's run-loop source to the main run loop.
        // For a background actor we could use a dedicated CFRunLoop; main is simplest for the host app.
        if let source = IONotificationPortGetRunLoopSource(port)?.takeUnretainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        
        let matching = IOServiceMatching(kIOUSBDeviceClassName) as NSMutableDictionary
        
        // Retain self for the C callbacks via Unmanaged
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        // Matched (device appeared / finished matching)
        var matched: io_iterator_t = 0
        let matchResult = IOServiceAddMatchingNotification(
            port,
            kIOFirstMatchNotification,
            matching,
            { (refcon, iterator) in
                guard let refcon else { return }
                let discovery = Unmanaged<USBDiscovery>.fromOpaque(refcon).takeUnretainedValue()
                discovery.handleMatched(iterator: iterator)
            },
            selfPtr,
            &matched
        )
        
        if matchResult == KERN_SUCCESS {
            matchedIterator = matched
            // Drain already-connected devices
            handleMatched(iterator: matched)
        } else {
            print("[USBDiscovery] IOServiceAddMatchingNotification (matched) failed: \(matchResult)")
        }
        
        // Terminated
        let matching2 = IOServiceMatching(kIOUSBDeviceClassName) as NSMutableDictionary
        var terminated: io_iterator_t = 0
        let termResult = IOServiceAddMatchingNotification(
            port,
            kIOTerminatedNotification,
            matching2,
            { (refcon, iterator) in
                guard let refcon else { return }
                let discovery = Unmanaged<USBDiscovery>.fromOpaque(refcon).takeUnretainedValue()
                discovery.handleTerminated(iterator: iterator)
            },
            selfPtr,
            &terminated
        )
        
        if termResult == KERN_SUCCESS {
            terminatedIterator = terminated
            // Drain (usually empty at start)
            handleTerminated(iterator: terminated)
        } else {
            print("[USBDiscovery] IOServiceAddMatchingNotification (terminated) failed: \(termResult)")
        }
        
        print("[USBDiscovery] Started")
    }
    
    private func _stop() {
        if matchedIterator != 0 {
            IOObjectRelease(matchedIterator)
            matchedIterator = 0
        }
        if terminatedIterator != 0 {
            IOObjectRelease(terminatedIterator)
            terminatedIterator = 0
        }
        if let port = notificationPort {
            if let source = IONotificationPortGetRunLoopSource(port)?.takeUnretainedValue() {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            }
            IONotificationPortDestroy(port)
            notificationPort = nil
        }
        print("[USBDiscovery] Stopped")
    }
    
    // MARK: - Callbacks
    
    private func handleMatched(iterator: io_iterator_t) {
        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            defer { IOObjectRelease(service) }
            
            if let snapshot = extractSnapshot(from: service) {
                // Only surface likely Android devices (or everything if you prefer broader matching)
                if snapshot.isLikelyAndroid {
                    onEvent?(.attached(snapshot))
                }
            }
        }
    }
    
    private func handleTerminated(iterator: io_iterator_t) {
        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            defer { IOObjectRelease(service) }
            
            let locationID = propertyUInt32(service, key: "locationID")
                ?? propertyUInt32(service, key: kUSBDevicePropertyLocationID)
                ?? 0
            
            if locationID != 0 {
                onEvent?(.detached(locationID: locationID))
            }
        }
    }
    
    // MARK: - Property helpers
    
    private func extractSnapshot(from service: io_service_t) -> USBDeviceSnapshot? {
        let vendorID = propertyUInt16(service, key: "idVendor")
            ?? propertyUInt16(service, key: kUSBVendorID)
        let productID = propertyUInt16(service, key: "idProduct")
            ?? propertyUInt16(service, key: kUSBProductID)
        
        guard let vid = vendorID, let pid = productID else { return nil }
        
        let locationID = propertyUInt32(service, key: "locationID")
            ?? propertyUInt32(service, key: kUSBDevicePropertyLocationID)
            ?? 0
        
        let serial = propertyString(service, key: "USB Serial Number")
            ?? propertyString(service, key: kUSBSerialNumberString)
        
        let vendorName = propertyString(service, key: "USB Vendor Name")
            ?? propertyString(service, key: "kUSBVendorString")
        
        let productName = propertyString(service, key: "USB Product Name")
            ?? propertyString(service, key: "kUSBProductString")
            ?? propertyString(service, key: "USB Product Name")
        
        let isAndroid = Self.androidVendorIDs.contains(vid)
            || (vendorName?.lowercased().contains("android") == true)
            || (productName?.lowercased().contains("android") == true)
            || (productName?.lowercased().contains("mtp") == true)
        
        return USBDeviceSnapshot(
            locationID: locationID,
            vendorID: vid,
            productID: pid,
            serial: serial,
            vendorName: vendorName,
            productName: productName,
            isLikelyAndroid: isAndroid
        )
    }
    
    private func propertyString(_ service: io_service_t, key: String) -> String? {
        guard let cf = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() else { return nil }
        return cf as? String
    }
    
    private func propertyUInt16(_ service: io_service_t, key: String) -> UInt16? {
        guard let cf = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() else { return nil }
        if let n = cf as? NSNumber { return n.uint16Value }
        return nil
    }
    
    private func propertyUInt32(_ service: io_service_t, key: String) -> UInt32? {
        guard let cf = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() else { return nil }
        if let n = cf as? NSNumber { return n.uint32Value }
        return nil
    }
}

// MARK: - Constants that are sometimes missing from Swift overlays

private let kUSBVendorID = "idVendor"
private let kUSBProductID = "idProduct"
private let kUSBSerialNumberString = "USB Serial Number"
private let kUSBDevicePropertyLocationID = "locationID"
