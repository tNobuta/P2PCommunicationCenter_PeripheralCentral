//
//  BLEDeviceInfo.h
//  BluetoothChatDemo
//
//  Created by tmy on 14-7-2.
//  Copyright (c) 2014年 hurray. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface P2PDevice : NSObject

@property (nonatomic, strong) NSString           *identifier;
@property (nonatomic, strong) CBPeripheral       *relatedPeripheral;
@property (nonatomic, strong) CBCharacteristic   *chatCharacteristicForWrite;
@property (nonatomic, strong) CBCentral          *relatedCentral;
@property (nonatomic) BOOL                       isConnected;
@property (nonatomic) BOOL                       isReady;
@property (nonatomic) NSString                   *nonce;

@end
