# Hardware Test Matrix

Primary target: **Motorola Edge 70** (VID 0x22b8, Android 16, USB 2.0).

| Vendor | Device | Android | USB | MTP | ADB | Finder | Read | Write | Reconnect |
|---|---|---|---|---|---|---|---|---|---|
| Motorola | Edge 70 | 16 | USB-C 2.0 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Google | Pixel | TBD | USB-C | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Samsung | Galaxy | TBD | USB-C | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| OnePlus | TBD | TBD | USB-C | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Xiaomi | TBD | TBD | USB-C | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Sony | Xperia | TBD | USB-C | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |

## Transfer cases
- 100 MB
- 1 GB
- 4 GB
- 10 GB
- 50 GB+

## Failure cases
- cable removal
- phone lock
- phone sleep
- phone reboot
- USB mode change (charge ↔ File transfer)
- ADB authorization revoked
- MTP session failure
- Mac sleep/wake
- Finder restart
- app restart
- Unicode filenames
- huge directories

## Edge 70 specific
- Confirm File transfer mode required (default is charge-only)
- USB 2.0 speed expectations
- Single internal storage only
