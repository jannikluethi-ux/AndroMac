import Foundation
import CryptoKit

public enum Integrity {
    
    public static func sha256(ofFile url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    public static func verify(local a: URL, matches b: URL) throws -> Bool {
        let ha = try sha256(ofFile: a)
        let hb = try sha256(ofFile: b)
        return ha == hb
    }
}
