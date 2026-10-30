# AndroMac_2 execution status

## Tasks completed (source-level)

| Task | Status | Notes |
|------|--------|-------|
| 01 Xcode project structure | ✅ | `project.yml` for XcodeGen; target folders created |
| 02 Compile under targets | ⬜ | Requires Mac + `xcodegen generate` + Xcode |
| 03 Fix test module name | ✅ | `@testable import AndroMac` |
| 04 Entitlements / Info.plist | ✅ | Config/*.plist + entitlement rationale |
| 05 XPC service + typed API | ✅ | `AndroidBridgeXPCProtocol`, client, `BridgeXPCService` |
| 06 Session ownership | ✅ | `ConnectionSession` + `ConnectionSessionStore` |
| 07 File Provider via XPC | ✅ | `AndroMacFileProvider` uses XPC only |
| 08 Delete mock enumeration | ✅ | `LiveEnumerator` replaces mock folders |
| 09 Live enumeration | ✅ | Lists via XPC → transport |
| 10 Real MTP (libmtp) | ⬜ | Still MockMTPSession / LibMTPSession stub |
| 11–13 Physical Finder slice | ⬜ | No Mac/hardware in this environment |
| 14–22 Transfers / recovery / multi-device | partial | Coordinator + Integrity SHA-256 ready |

## Architecture now

```
Finder → AndroMacFileProvider → XPC (com.andromac.bridge)
              → BridgeXPCService → ConnectionSessionStore
                    → MTPTransport | ADBTransport
```

## How to build on a Mac

```bash
brew install xcodegen
cd AndroMac
xcodegen generate
open AndroMac.xcodeproj
# Sign with your team, run AndroMac
# Edge 70: unlock, File transfer mode
```

## Blockers (honest)

1. **Linux sandbox** — cannot run `xcodebuild`, IOKit, File Provider, or USB.
2. **libmtp not linked** — production MTP still needs C bridge + packaging review.
3. **Physical device tests** — Edge 70 not reachable from this environment.
4. **Domain ID encoding** — deviceID `serial:…` is sanitized with `-` for domain id; reverse mapping is best-effort.

## Technical debt

- XPC uses JSON Data blobs for Codable arrays (simple, not optimal).
- ADB push still temp-file based (behind transport boundary).
- Mock MTP remains default until libmtp wired.
- No full `.xcodeproj` checked in (generated via XcodeGen).
- File Provider domain ID ↔ DeviceID round-trip needs hardening for all ID formats.

## Stop gate (Task 13)

Cannot complete physical Finder vertical slice here. Next step is on a Mac with Edge 70.
