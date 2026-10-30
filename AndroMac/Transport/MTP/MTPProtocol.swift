import Foundation

// MARK: - MTP Container Types (USB still image / MTP bulk protocol)

/// MTP operation codes (subset needed for file transfer)
public enum MTPOperationCode: UInt16, Sendable {
    case getDeviceInfo        = 0x1001
    case openSession          = 0x1002
    case closeSession         = 0x1003
    case getStorageIDs        = 0x1004
    case getStorageInfo       = 0x1005
    case getNumObjects        = 0x1006
    case getObjectHandles     = 0x1007
    case getObjectInfo        = 0x1008
    case getObject            = 0x1009
    case getThumb             = 0x100A
    case deleteObject         = 0x100B
    case sendObjectInfo       = 0x100C
    case sendObject           = 0x100D
    case initiateCapture      = 0x100E
    case formatStore          = 0x100F
    case resetDevice          = 0x1010
    case selfTest             = 0x1011
    case setObjectProtection  = 0x1012
    case powerDown            = 0x1013
    case getDevicePropDesc    = 0x1014
    case getDevicePropValue   = 0x1015
    case setDevicePropValue   = 0x1016
    case resetDevicePropValue = 0x1017
    case terminateOpenCapture = 0x1018
    case moveObject           = 0x1019
    case copyObject           = 0x101A
    case getPartialObject     = 0x101B
    case initiateOpenCapture  = 0x101C
    // Android / MTP 1.1 extensions
    case getObjectPropsSupported = 0x9801
    case getObjectPropDesc       = 0x9802
    case getObjectPropValue      = 0x9803
    case setObjectPropValue      = 0x9804
    case getObjectPropList       = 0x9805
    case getObjectReferences     = 0x9810
    case setObjectReferences     = 0x9811
    case skip                    = 0x9820
}

public enum MTPResponseCode: UInt16, Sendable {
    case ok                   = 0x2001
    case generalError         = 0x2002
    case sessionNotOpen       = 0x2003
    case invalidTransactionID = 0x2004
    case operationNotSupported = 0x2005
    case parameterNotSupported = 0x2006
    case incompleteTransfer   = 0x2007
    case invalidStorageID     = 0x2008
    case invalidObjectHandle  = 0x2009
    case devicePropNotSupported = 0x200A
    case invalidObjectFormatCode = 0x200B
    case storeFull            = 0x200C
    case objectWriteProtected = 0x200D
    case storeReadOnly        = 0x200E
    case accessDenied         = 0x200F
    case noThumbnailPresent   = 0x2010
    case selfTestFailed       = 0x2011
    case partialDeletion      = 0x2012
    case storeNotAvailable    = 0x2013
    case specificationByFormatUnsupported = 0x2014
    case noValidObjectInfo    = 0x2015
    case invalidCodeFormat    = 0x2016
    case unknownVendorCode    = 0x2017
    case captureAlreadyTerminated = 0x2018
    case deviceBusy           = 0x2019
    case invalidParentObject  = 0x201A
    case invalidDevicePropFormat = 0x201B
    case invalidDevicePropValue = 0x201C
    case invalidParameter     = 0x201D
    case sessionAlreadyOpen   = 0x201E
    case transactionCancelled = 0x201F
    case specificationOfDestinationUnsupported = 0x2020
}

public enum MTPObjectFormat: UInt16, Sendable {
    case undefined            = 0x3000
    case association          = 0x3001  // folder
    case script               = 0x3002
    case executable           = 0x3003
    case text                 = 0x3004
    case html                 = 0x3005
    case dpof                 = 0x3006
    case aiff                 = 0x3007
    case wav                  = 0x3008
    case mp3                  = 0x3009
    case avi                  = 0x300A
    case mpeg                 = 0x300B
    case asf                  = 0x300C
    case defined              = 0x3800
    case exifJPEG             = 0x3801
    case tiffEP               = 0x3802
    case flashPix             = 0x3803
    case bmp                  = 0x3804
    case ciff                 = 0x3805
    case gif                  = 0x3807
    case jfif                 = 0x3808
    case pcd                  = 0x3809
    case pict                 = 0x380A
    case png                  = 0x380B
    case tiff                 = 0x380D
    case jp2                  = 0x380F
    case jpx                  = 0x3810
    case unknownImage         = 0x3800
}

public enum MTPAssociationType: UInt16, Sendable {
    case undefined            = 0x0000
    case genericFolder        = 0x0001
    case album                = 0x0002
    case timeSequence         = 0x0003
    case horizontalPanorama   = 0x0004
    case verticalPanorama     = 0x0005
    case dualPanorama         = 0x0006
    case ancillaryData        = 0x0007
}

// MARK: - Object model

public struct MTPObjectHandle: Hashable, Codable, Sendable, CustomStringConvertible {
    public let value: UInt32
    public init(_ value: UInt32) { self.value = value }
    public var description: String { String(value) }
    
    public static let rootParent = MTPObjectHandle(0xFFFFFFFF) // or 0 depending on device
}

public struct MTPStorageID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let value: UInt32
    public init(_ value: UInt32) { self.value = value }
    public var description: String { String(format: "0x%08x", value) }
}

public struct MTPObjectInfo: Sendable {
    public let handle: MTPObjectHandle
    public let storageID: MTPStorageID
    public let objectFormat: MTPObjectFormat
    public let protectionStatus: UInt16
    public let objectCompressedSize: UInt64
    public let associationType: MTPAssociationType
    public let associationDesc: UInt32
    public let parentObject: MTPObjectHandle
    public let filename: String
    public let captureDate: Date?
    public let modificationDate: Date?
    
    public var isDirectory: Bool {
        objectFormat == .association
    }
}

public struct MTPStorageInfo: Sendable {
    public let storageID: MTPStorageID
    public let storageType: UInt16
    public let filesystemType: UInt16
    public let accessCapability: UInt16
    public let maxCapacity: UInt64
    public let freeSpaceInBytes: UInt64
    public let freeSpaceInImages: UInt32
    public let storageDescription: String
    public let volumeIdentifier: String
}

// MARK: - Errors

public enum MTPError: Error, LocalizedError, Sendable {
    case notConnected
    case sessionNotOpen
    case operationFailed(MTPResponseCode)
    case invalidPath(String)
    case objectNotFound(String)
    case ioFailure(String)
    case cancelled
    case unsupported
    case backendUnavailable(String)
    
    public var errorDescription: String? {
        switch self {
        case .notConnected: return "MTP device not connected"
        case .sessionNotOpen: return "MTP session is not open"
        case .operationFailed(let code): return "MTP operation failed: \(code)"
        case .invalidPath(let p): return "Invalid path: \(p)"
        case .objectNotFound(let p): return "Object not found: \(p)"
        case .ioFailure(let m): return "MTP I/O failure: \(m)"
        case .cancelled: return "MTP operation cancelled"
        case .unsupported: return "MTP operation not supported"
        case .backendUnavailable(let m): return "MTP backend unavailable: \(m)"
        }
    }
}
