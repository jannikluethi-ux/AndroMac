# Mac Bring-Up Procedure

## Goal

Edge 70 appears under **Finder → Locations** and a real file survives a verified transfer.

## Steps

### 1. Xcode
Install Xcode 15+, open once, accept license.

### 2. Command-line tools
```bash
xcode-select -p
# should point at Xcode.app
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

### 3. Homebrew tools
```bash
brew install xcodegen libmtp
# optional ADB:
brew install android-platform-tools
```

### 4. Preflight
```bash
cd AndroMac
./scripts/preflight.sh
# expect READY
```

### 5. Generate project
```bash
xcodegen generate
open AndroMac.xcodeproj
```

### 6. Signing
Select your Team on AndroMac, FileProvider, and XPC targets.

### 7. Link libmtp (AndroMacXPC)
- Header search: `$(brew --prefix)/include`
- Library search: `$(brew --prefix)/lib`
- Link: `-lmtp -lusb-1.0`
- Bridging header including `MTPBridge.h`
- Implement `MTPBridge.mm` with real `LIBMTP_*` calls

### 8. Build & unit tests
```bash
./scripts/validate-mac.sh
```

### 9. Physical Edge 70
1. Unlock phone, data cable, **File transfer**
2. Run AndroMac from Xcode
3. Confirm connection status
4. Finder → Locations → phone
5. Open DCIM — real files
6. Copy one file to Mac; SHA-256 verify
7. Unplug / replug; recovery without Finder restart

### 10. Record results
Fill `docs/HARDWARE_TEST_REPORT.md`.

## Status language

Use only: VERIFIED | UNVERIFIED | BLOCKED BY ENVIRONMENT | FAILED | PARTIALLY VERIFIED
