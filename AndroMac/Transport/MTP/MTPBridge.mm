// MTPBridge.mm — real LibMTP implementation goes here on a Mac with libmtp linked.
// This file intentionally does not call libmtp until the dependency is present.
//
// Build note: only compile/link this target when LIBMTP is available, or provide
// weak stubs so Debug builds without Homebrew still compile.

#include "MTPBridge.h"
#include <stdlib.h>

// Placeholder: all operations fail until libmtp is wired.
// Replace body with LIBMTP_Detect_Raw_Devices / Open_Raw_Device_Uncached / etc.

MTPBridgeSession *MTPBridgeOpen(
    const char *serialOrNull,
    uint16_t vendorIDOrZero,
    uint16_t productIDOrZero,
    MTPBridgeStatus *statusOut
) {
    if (statusOut) *statusOut = MTPBridgeNotSupported;
    (void)serialOrNull;
    (void)vendorIDOrZero;
    (void)productIDOrZero;
    return NULL;
}

void MTPBridgeClose(MTPBridgeSession *session) {
    (void)session;
}

MTPBridgeStatus MTPBridgeList(
    MTPBridgeSession *session,
    uint32_t storageID,
    uint32_t parentHandle,
    uint32_t **handlesOut,
    char ***namesOut,
    bool **isDirOut,
    int64_t **sizesOut,
    int *countOut
) {
    (void)session; (void)storageID; (void)parentHandle;
    if (handlesOut) *handlesOut = NULL;
    if (namesOut) *namesOut = NULL;
    if (isDirOut) *isDirOut = NULL;
    if (sizesOut) *sizesOut = NULL;
    if (countOut) *countOut = 0;
    return MTPBridgeNotSupported;
}

void MTPBridgeFreeStringList(char **list, int count) {
    if (!list) return;
    for (int i = 0; i < count; i++) free(list[i]);
    free(list);
}

void MTPBridgeFreeU32List(uint32_t *list) { free(list); }
void MTPBridgeFreeI64List(int64_t *list) { free(list); }
void MTPBridgeFreeBoolList(bool *list) { free(list); }

MTPBridgeStatus MTPBridgeGetObjectToFile(
    MTPBridgeSession *session,
    uint32_t handle,
    const char *destPath
) {
    (void)session; (void)handle; (void)destPath;
    return MTPBridgeNotSupported;
}
