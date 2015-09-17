//
//  P2PTransmitOperation.m
//  BluetoothChatDemo
//
//  Created by tmy on 14-7-15.
//  Copyright (c) 2014年 hurray. All rights reserved.
//

#import "P2PTransmitOperation.h"
#import <CoreBluetooth/CoreBluetooth.h>

@implementation P2PTransmitOperation
{
    CBPeripheralManager          *_peripheralManager;
    CBPeripheral                 *_peripheral;
    CBMutableCharacteristic      *_characteristicForUpdate;
    CBCharacteristic             *_characteristicForWrite;
    P2PDataPacket                *_packet;
    NSArray                      *_centrals;
}

+ (instancetype)operationWithPeripheralManager:(CBPeripheralManager *)peripheralManager characteristic:(CBMutableCharacteristic *)characteristic packet:(P2PDataPacket *)packet centrals:(NSArray *)centrals
{
    return [[self alloc] initWithPeripheralManager:peripheralManager characteristic:characteristic packet:packet centrals:centrals];
}

+ (instancetype)operationWithPeripheral:(CBPeripheral *)peripheral characteristic:(CBCharacteristic *)characteristic packet:(P2PDataPacket *)packet
{
    return [[self alloc] initWithPeripheral:peripheral characteristic:characteristic packet:packet];
}

- (id)initWithPeripheralManager:(CBPeripheralManager *)peripheralManager characteristic:(CBMutableCharacteristic *)characteristic packet:(P2PDataPacket *)packet centrals:(NSArray *)centrals
{
    if(self = [super init]){
        _peripheralManager = peripheralManager;
        _characteristicForUpdate = characteristic;
        _packet = packet;
        _centrals = centrals;
    }
    
    return self;
}

- (id)initWithPeripheral:(CBPeripheral *)peripheral characteristic:(CBCharacteristic *)characteristic packet:(P2PDataPacket *)packet
{
    if (self = [super init]) {
        _peripheral = peripheral;
        _characteristicForWrite = characteristic;
        _packet = packet;
    }
    
    return self;
}

- (void)main
{
    if((!_peripheralManager && !_peripheral) || !_packet || (_centrals && _centrals.count == 0))
        return;
    
    NSData  *toSendData = nil;
    while (![self isCancelled] && (toSendData = [_packet currentData])) {
        if (_peripheralManager) {
            [_peripheralManager updateValue:toSendData forCharacteristic:_characteristicForUpdate onSubscribedCentrals:_centrals];
        }else if(_peripheral){
            [_peripheral writeValue:toSendData forCharacteristic:_characteristicForWrite type:CBCharacteristicWriteWithoutResponse];
        }
        
        [NSThread sleepForTimeInterval:0.05];
    }
    
    if(![self isCancelled]){
        NSData *terminatedFlagData = [@"\0" dataUsingEncoding:NSUTF8StringEncoding];
        if (_peripheralManager) {
            [_peripheralManager updateValue:terminatedFlagData forCharacteristic:_characteristicForUpdate onSubscribedCentrals:_centrals];
        }else if(_peripheral){
            [_peripheral writeValue:terminatedFlagData forCharacteristic:_characteristicForWrite type:CBCharacteristicWriteWithoutResponse];
        }
        
        [NSThread sleepForTimeInterval:0.1];
    }
}

@end
