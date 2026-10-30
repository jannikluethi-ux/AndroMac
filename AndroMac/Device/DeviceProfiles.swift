import Foundation

/// Known device quirks and display defaults.
public struct DeviceProfile: Sendable {
    public let manufacturerMatch: String?
    public let modelMatch: String?
    public let vendorID: UInt16?
    public let displayNameTemplate: String
    public let prefersADB: Bool
    public let notes: String
    
    public init(
        manufacturerMatch: String? = nil,
        modelMatch: String? = nil,
        vendorID: UInt16? = nil,
        displayNameTemplate: String,
        prefersADB: Bool = true,
        notes: String = ""
    ) {
        self.manufacturerMatch = manufacturerMatch
        self.modelMatch = modelMatch
        self.vendorID = vendorID
        self.displayNameTemplate = displayNameTemplate
        self.prefersADB = prefersADB
        self.notes = notes
    }
    
    public static let catalog: [DeviceProfile] = [
        DeviceProfile(
            manufacturerMatch: "motorola",
            modelMatch: "edge 70",
            vendorID: 0x22b8,
            displayNameTemplate: "Motorola Edge 70",
            prefersADB: true,
            notes: """
            Android 16, Snapdragon 7 Gen 4, USB-C 2.0 only.
            Default USB mode is charging — user must choose File transfer (MTP).
            PID changes with USB mode; identify by serial + VID 0x22b8.
            No microSD. Single internal storage.
            """
        ),
        DeviceProfile(
            manufacturerMatch: "motorola",
            vendorID: 0x22b8,
            displayNameTemplate: "Motorola Device",
            prefersADB: true,
            notes: "Generic Motorola. Apply Android MTP bug flags when using libmtp."
        ),
        DeviceProfile(
            manufacturerMatch: "google",
            vendorID: 0x18d1,
            displayNameTemplate: "Pixel",
            prefersADB: true
        ),
        DeviceProfile(
            manufacturerMatch: "samsung",
            vendorID: 0x04e8,
            displayNameTemplate: "Samsung Galaxy",
            prefersADB: true
        ),
    ]
    
    /// Match order: (1) model + manufacturer/VID, (2) manufacturer, (3) VID only.
    public static func match(
        manufacturer: String?,
        model: String?,
        vendorID: UInt16?
    ) -> DeviceProfile? {
        let mfr = manufacturer?.lowercased() ?? ""
        let mdl = model?.lowercased() ?? ""
        
        // 1) Specific model match (e.g. "edge 70")
        if !mdl.isEmpty {
            for profile in catalog {
                guard let pm = profile.modelMatch, mdl.contains(pm) else { continue }
                if let pman = profile.manufacturerMatch, !mfr.isEmpty, !mfr.contains(pman) {
                    continue
                }
                if let vid = profile.vendorID, let vendorID, vid != vendorID {
                    continue
                }
                return profile
            }
        }
        
        // 2) Manufacturer string
        if !mfr.isEmpty {
            for profile in catalog where profile.modelMatch == nil {
                if let pman = profile.manufacturerMatch, mfr.contains(pman) {
                    return profile
                }
            }
        }
        
        // 3) Vendor ID only
        if let vendorID {
            for profile in catalog where profile.modelMatch == nil {
                if profile.vendorID == vendorID {
                    return profile
                }
            }
        }
        
        return nil
    }
}
