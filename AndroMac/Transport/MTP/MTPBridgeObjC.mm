#import "MTPBridgeObjC.h"

/*
 Real libmtp integration boundary (Mac Starter Kit).
 Deliberately fails rather than silently using a mock.
 On a Mac: brew install libmtp, link libmtp + libusb, replace the bodies
 with LIBMTP_Detect_Raw_Devices / Open_Raw_Device_Uncached / etc.
*/

static NSString * const MTPBridgeErrorDomain = @"com.andromac.mtp";

@implementation MTPBridgeObjC

- (NSArray<NSDictionary *> *)enumerateDevices:(NSError **)error {
    if (error) {
        *error = [NSError errorWithDomain:MTPBridgeErrorDomain
                                     code:1
                                 userInfo:@{NSLocalizedDescriptionKey:
            @"Real libmtp is not linked/configured yet."}];
    }
    return @[];
}

- (BOOL)connectToDeviceIdentifier:(NSString *)identifier error:(NSError **)error {
    (void)identifier;
    if (error) {
        *error = [NSError errorWithDomain:MTPBridgeErrorDomain
                                     code:2
                                 userInfo:@{NSLocalizedDescriptionKey:
            @"Real libmtp connection is not implemented yet."}];
    }
    return NO;
}

- (BOOL)disconnect:(NSError **)error {
    (void)error;
    return YES;
}

@end
