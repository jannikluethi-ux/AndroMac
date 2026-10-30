#ifndef ANDROMAC_MTP_BRIDGE_H
#define ANDROMAC_MTP_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Opaque session handle — implemented in MTPBridge.mm with libmtp.
typedef struct MTPBridgeSession MTPBridgeSession;

/// Result codes for the C bridge (map to Swift MTPError).
typedef enum {
    MTPBridgeOK = 0,
    MTPBridgeNotFound = 1,
    MTPBridgeSessionFailed = 2,
    MTPBridgeIOError = 3,
    MTPBridgeNotSupported = 4
} MTPBridgeStatus;

/// Open first matching device (optional serial UTF-8, optional VID/PID filters).
/// Returns NULL on failure; status out-param set.
MTPBridgeSession *MTPBridgeOpen(
    const char *serialOrNull,
    uint16_t vendorIDOrZero,
    uint16_t productIDOrZero,
    MTPBridgeStatus *statusOut
);

void MTPBridgeClose(MTPBridgeSession *session);

/// List folder. parentHandle 0xFFFFFFFF = storage root.
/// Caller frees names with MTPBridgeFreeStringList.
MTPBridgeStatus MTPBridgeList(
    MTPBridgeSession *session,
    uint32_t storageID,
    uint32_t parentHandle,
    uint32_t **handlesOut,
    char ***namesOut,
    bool **isDirOut,
    int64_t **sizesOut,
    int *countOut
);

void MTPBridgeFreeStringList(char **list, int count);
void MTPBridgeFreeU32List(uint32_t *list);
void MTPBridgeFreeI64List(int64_t *list);
void MTPBridgeFreeBoolList(bool *list);

/// Stream object to a filesystem path (implementation reads in chunks).
MTPBridgeStatus MTPBridgeGetObjectToFile(
    MTPBridgeSession *session,
    uint32_t handle,
    const char *destPath
);

#ifdef __cplusplus
}
#endif

#endif
