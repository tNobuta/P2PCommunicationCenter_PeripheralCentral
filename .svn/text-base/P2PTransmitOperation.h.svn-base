//
//  P2PTransmitOperation.h
//  BluetoothChatDemo
//
//  Created by tmy on 14-7-15.
//  Copyright (c) 2014年 hurray. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "P2PDataPacket.h"

@interface P2PTransmitOperation : NSOperation

//send as peripheral
+ (instancetype)operationWithPeripheralManager:(CBPeripheralManager *)peripheralManager characteristic:(CBMutableCharacteristic *)characteristic packet:(P2PDataPacket *)packet centrals:(NSArray *)centrals;

//send as central
+ (instancetype)operationWithPeripheral:(CBPeripheral *)peripheral characteristic:(CBCharacteristic *)characteristic packet:(P2PDataPacket *)packet;

@end
