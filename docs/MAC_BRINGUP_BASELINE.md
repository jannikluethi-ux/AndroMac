# Mac Bring-Up Baseline Audit

Date: 2026-09-17

## Targets (project.yml)

| Target | Type |
|--------|------|
| AndroMac | macOS app |
| AndroMacFileProvider | app extension |
| AndroMacXPC | XPC service |
| AndroMacTests | unit tests |
| AndroMacIntegrationTests | hardware tests (skipped without device) |

## Source map

| Area | Location |
|------|----------|
| App / UI | `AndroMac/App`, `AndroMac/UI` |
| Device / USB | `AndroMac/Device` |
| MTP / ADB | `AndroMac/Transport` |
| Transfer | `AndroMac/Transfer` |
| XPC protocol | `AndroMac/Shared/XPC` |
| File Provider | `AndroMacFileProvider/` |
| XPC service | `AndroMacXPC/` |
| Config | `Config/*.plist`, entitlements |
| Scripts | `scripts/preflight.sh`, `validate-mac.sh` |

## MTP

- Production: `LibMTPSession` → `MTPBridge` → libmtp (**bridge stub**)
- Tests only: `MockMTPSession`
- Factory: **no silent mock fallback** (`mode: .production`)

## ADB

- `ADBClient` + `ADBTransport` — process-based adb CLI

## XPC

- Service name: `com.andromac.bridge`
- Codable domain types only across boundary

## File Provider

- Live enumerator via XPC (no mock folder list in production path)

## Signing / entitlements

- App: sandbox off (dev), USB, user-selected files, XPC lookup
- Extension: sandbox on, app group, XPC lookup
- Hardened Runtime expected in Release on Mac

## Mocks / stubs still present

- `MockMTPSession` (tests)
- `MTPBridge.mm` returns NotSupported
- `LibMTPSession.open()` throws until bridge works
- Integration tests XCTSkip without hardware

## TODOs (software)

1. Implement MTPBridge.mm with libmtp
2. Bridging header on AndroMacXPC
3. Generate + build on Mac
4. Physical Edge 70 validation
