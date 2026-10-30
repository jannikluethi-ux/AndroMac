# IOKit USB Discovery — Research Notes (Andromac M1)

## Goal
Detect Android phones over USB as soon as they appear, with stable identity, no polling.

## Recommended approach

1. Match on `kIOUSBDeviceClassName` (broad).
2. Register two notifications:
   - `kIOFirstMatchNotification` → device finished matching / ready
   - `kIOTerminatedNotification` → device gone
3. Use `IONotificationPortCreate(kIOMainPortDefault)` + run-loop source.
4. Drain the iterator in every callback (required; otherwise you only get the first event).
5. Read properties with `IORegistryEntryCreateCFProperty`:
   - `idVendor` / `idProduct`
   - `USB Serial Number`
   - `USB Vendor Name` / `USB Product Name`
   - `locationID` (stable for the current plug session; useful for detach mapping)

## Filtering Android devices

Known vendor IDs (non-exhaustive):

| Vendor     | VID    |
|------------|--------|
| Google     | 0x18d1 |
| Samsung    | 0x04e8 |
| Xiaomi     | 0x2717 |
| Qualcomm   | 0x05c6 |
| OnePlus    | 0x2a70 |
| HTC        | 0x0bb4 |
| Huawei     | 0x12d1 |
| Motorola   | 0x22b8 |
| Sony       | 0x0fce |
| ASUS       | 0x0b05 |

Also accept devices whose product/vendor string contains "Android" or "MTP".

Product ID changes with USB mode (charging / MTP / PTP / ADB / RNDIS). Do **not** rely on a fixed PID for identity. Prefer serial number.

## Identity strategy (already in `DeviceInfo`)

1. Android serial (best)
2. USB serial number
3. Fallback: `vid-pid-model`

## Important constraints

- **No App Sandbox** for full USB/IOKit access (or use carefully scoped entitlements). Hardened Runtime + Developer ID is the intended distribution path.
- Do not claim the USB interface for discovery only — discovery is read-only via the registry. Claiming interfaces is for the MTP/ADB transports later.
- `kIOMasterPortDefault` is deprecated; use `kIOMainPortDefault`.
- Always release `io_object_t` values obtained from iterators.

## What the code implements

- `USBDiscovery.swift` — pure IOKit notification + property extraction
- `DeviceManager` — maps attach/detach to stable `DeviceInfo`, notifies observers

## Next steps after this works on hardware

1. Log real VID/PID/serial from Pixel + Samsung in MTP and ADB modes.
2. Detect available interfaces (MTP vs ADB) by walking configuration descriptors if needed.
3. Hand the snapshot to transport selection (prefer ADB when authorized, else MTP).
4. Measure: plug → first event time (target < 1 s).
