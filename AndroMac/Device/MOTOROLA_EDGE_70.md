# Target device: Motorola Edge 70

## Hardware / software
- **OS:** Android 16
- **SoC:** Snapdragon 7 Gen 4
- **USB:** Type-C **USB 2.0** only (expect ~30–40 MB/s practical MTP peaks, not USB 3 speeds)
- **Storage:** Internal only (no microSD)
- **USB vendor ID:** `0x22b8` (Motorola)

Product ID changes with mode (charging / MTP / PTP / ADB / tethering). Do **not** hard-code a single PID. Use serial + VID.

## User steps (required every cold plug)
1. Unlock the phone.
2. Use a **data-capable** USB-C cable (charge-only cables fail silently).
3. Plug into the Mac.
4. On the phone notification / Settings → Connected devices → USB, choose **File transfer**.
5. Default is often “No data transfer” (charge only) — Andromac cannot see storage until File transfer is selected.

## Andromac behavior
- `USBDiscovery` already treats VID `0x22b8` as Android.
- `DeviceProfile` maps it to display name **Motorola Edge 70** when the product string matches.
- Transport preference: ADB if authorized, else MTP.
- Until libmtp is linked on the Mac, MTP uses `MockMTPSession` for development.

## First real-device checklist (Mac + Edge 70)

```
[ ] System Information → USB shows Motorola device, note idProduct + serial
[ ] Phone set to File transfer
[ ] Andromac detects attach < 1s
[ ] Stable DeviceID uses serial
[ ] MTP list root → Internal storage folders (DCIM, Download, …)
[ ] Browse DCIM / Camera
[ ] Stream a photo to Mac
[ ] Stream ≥ 1 GB file both directions
[ ] Unplug / replug recovers without app restart
[ ] Unicode filename (emoji / CJK) round-trip
```

## libmtp notes for Motorola
- Many Motorola entries in libmtp use `DEVICE_FLAGS_ANDROID_BUGS`.
- Prefer **uncached** open (`LIBMTP_Open_Raw_Device_Uncached`).
- Only one MTP client should own the session (quit Android File Transfer / OpenMTP / etc.).

## When you have the real PID
After the first successful plug, record:

```
VID: 0x22b8
PID (File transfer): 0x????
PID (ADB):           0x????
Serial:              ________
Android version:     16
```

Add the PID to diagnostics and optionally to libmtp’s device table if the device is unknown.
