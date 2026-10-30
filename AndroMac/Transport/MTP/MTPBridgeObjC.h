#import <Foundation/Foundation.h>

/// Objective-C libmtp boundary from the Mac Starter Kit.
/// Swift talks to this class; raw LIBMTP types stay in the .mm file.
@interface MTPBridgeObjC : NSObject
- (NSArray<NSDictionary *> *)enumerateDevices:(NSError **)error;
- (BOOL)connectToDeviceIdentifier:(NSString *)identifier error:(NSError **)error;
- (BOOL)disconnect:(NSError **)error;
@end
