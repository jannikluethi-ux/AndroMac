# Engineering Checklist

## Architecture
- [ ] File Provider is the Finder-facing layer
- [ ] Transport abstraction isolates MTP and ADB
- [ ] XPC boundary is explicit
- [ ] Swift concurrency is used consistently
- [ ] No polling loop as primary device discovery
- [ ] Device identity is stable

## Finder
- [ ] Device appears under Locations
- [ ] Enumeration works
- [ ] Read works
- [ ] Write works
- [ ] Rename works
- [ ] Move works
- [ ] Delete works
- [ ] Folder creation works
- [ ] Errors are human-readable

## Transfers
- [ ] Streaming I/O
- [ ] Progress
- [ ] Cancellation
- [ ] Large files
- [ ] Temporary destination
- [ ] Integrity verification
- [ ] Interrupted transfer recovery

## Android
- [ ] Pixel
- [ ] Samsung
- [ ] OnePlus
- [ ] Motorola
- [ ] Xiaomi
- [ ] Sony
- [ ] Multiple Android versions

## macOS
- [ ] Apple Silicon
- [ ] Intel
- [ ] Current supported macOS
- [ ] Previous supported macOS
- [ ] Sleep/wake
- [ ] Finder restart

## Security
- [ ] Hardened Runtime
- [ ] Developer ID signing
- [ ] Notarization
- [ ] Least privilege
- [ ] No file-content telemetry
- [ ] No cloud dependency

## UX
- [ ] No terminal required
- [ ] No Android Studio required
- [ ] No mandatory companion app
- [ ] Clear File Transfer guidance
- [ ] Menu-bar status
- [ ] Diagnostics export
