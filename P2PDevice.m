//
//  BLEDeviceInfo.m
//  BluetoothChatDemo
//
//  Created by tmy on 14-7-2.
//  Copyright (c) 2014年 hurray. All rights reserved.
//

#import "P2PDevice.h"

@implementation P2PDevice
 
- (BOOL)isReady
{
    return (self.relatedCentral || (self.relatedPeripheral && self.chatCharacteristicForWrite));
}
 
@end
