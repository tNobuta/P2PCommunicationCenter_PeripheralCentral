//
//  BLECommunicationCenter.h
//  BluetoothChatDemo
//
//  Created by tmy on 14-6-30.
//  Copyright (c) 2014年 hurray. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreLocation/CoreLocation.h>
#import "P2PDevice.h"
#import "P2PMessage.h"


typedef enum {
    BLECommunicationStateUnsupported,
    BLECommunicationStateUnauthorized,
    BLECommunicationStatePowerOff,
    BLECommunicationStatePowerOn
}BLECommunicationState;


@protocol P2PCommunicationCenterDelegate;

@interface P2PCommunicationCenter : NSObject<CBCentralManagerDelegate, CBPeripheralManagerDelegate, CBPeripheralDelegate, CLLocationManagerDelegate>

@property (nonatomic, strong) NSString *advertiseName;
@property (nonatomic, strong) NSString *iBeaconUUID;
@property (nonatomic, strong) NSString *iBeaconIdentifier;
@property (nonatomic, weak) id<P2PCommunicationCenterDelegate> delegate;
@property (nonatomic, readonly) NSString *deviceIdentifier;
@property (nonatomic, strong) NSString *serviceIdentifier;
@property (nonatomic) BOOL  shouldSpreadMessages; // 是否开启转播模式，默认关闭
@property (nonatomic) BOOL  iBeaconEnabled; //是否开启iBeacon功能, 默认关闭
@property (nonatomic) BOOL  shouldConnectViaiBeacon; //是否在被iBeacon唤醒后进行蓝牙连接操作，默认关闭

+ (instancetype)sharedCenter;

- (void)setupChatInfo:(NSDictionary *)chatInfo;
- (void)startCommunication;
- (void)stopCommunication;
- (void)sendMessage:(P2PMessage *)message;
- (void)disconnect;
- (void)disconnectToDevice:(NSString *)deviceIdentifier;

@end


@protocol P2PCommunicationCenterDelegate <NSObject>

@optional
- (BOOL)P2PCommunicationCenter:(P2PCommunicationCenter *)center didDiscoverDevice:(P2PDevice *)newDevice;

- (void)P2PCommunicationCenter:(P2PCommunicationCenter *)center didConnectDevice:(P2PDevice *)connectedDevice error:(NSError *)error;

- (void)P2PCommunicationCenter:(P2PCommunicationCenter *)center didDisconnectDevice:(P2PDevice *)device;

- (void)P2PCommunicationCenter:(P2PCommunicationCenter *)center newDeviceDidEnter:(P2PDevice *)device;

- (void)P2PCommunicationCenter:(P2PCommunicationCenter *)center deviceDidExit:(P2PDevice *)device;

- (void)P2PCommunicationCenter:(P2PCommunicationCenter *)center didReceiveMessage:(P2PMessage *)message;

- (void)P2PCommunicationCenterDidDiscoverDeviceViaIBeacon:(P2PCommunicationCenter *)center;

@end