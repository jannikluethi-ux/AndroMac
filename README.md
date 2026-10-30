# AndroMac

Native macOS app: Android phone → Finder → Locations over USB.

**Primary device:** Motorola Edge 70 (VID `0x22b8`, Android 16).

## Targets

| Target | Role |
|--------|------|
| AndroMac | Host app, DeviceManager, UI |
| AndroMacFileProvider | Finder File Provider (XPC client) |
| AndroMacXPC | Bridge service (owns transports) |
| AndroMacTests | Unit tests |
| AndroMacIntegrationTests | Hardware tests (manual) |

## Build (Mac)

```bash
brew install xcodegen libmtp
cd AndroMac
chmod +x bootstrap-mac.sh scripts/*.sh
./scripts/preflight.sh
./bootstrap-mac.sh
open AndroMac.xcodeproj
```

First-run details: `docs/MAC_FIRST_RUN.md`

Hard milestone: Xcode build → app launches → Edge 70 detected → real MTP → Finder Locations → verified file round-trip.

Do not treat mock MTP as a physical pass.

## Architecture

```
Finder → File Provider → XPC → ConnectionSession → MTP | ADB
```

See `BUILDER_2_STATUS.md` for AndroMac_2 task status.
