# Mac First Run

1. Copy the `AndroMac/` folder onto the Mac.
2. In Terminal:
   ```bash
   cd AndroMac
   chmod +x bootstrap-mac.sh scripts/*.sh
   ./scripts/preflight.sh
   ./bootstrap-mac.sh
   open AndroMac.xcodeproj
   ```
3. Build the `AndroMac` target in Xcode.
4. Only after the build works, connect the physical Android phone (Edge 70).
5. Set USB mode to **File transfer**.
6. Implement/link real libmtp at `AndroMac/Transport/MTP/MTPBridge.mm`.
7. Prove physical MTP enumeration independently (`andromacctl` / logs).
8. Then confirm File Provider runtime.
9. Then verify Finder → Locations.
10. Then Android → Mac and Mac → Android transfer with SHA-256.

Do not call a mock result a physical pass.

Hard milestone:

```text
Xcode build
  → app launches
  → physical Android detected
  → real MTP enumerates storage
  → File Provider
  → Finder Locations
  → verified file round-trip
```
