//
//  P2PDataPacket.m
//  BluetoothChatDemo
//
//  Created by tmy on 14-7-15.
//  Copyright (c) 2014年 hurray. All rights reserved.
//

#import "P2PDataPacket.h"

#define MAX_PACKET_SIZE 100

@implementation P2PDataPacket
{
    NSData      *_data;
    NSInteger   _currentLocation;
}

+ (instancetype)packetWithData:(NSData *)data
{
    return  [[self alloc] initWithData:data];
}

- (id)initWithData:(NSData *)data
{
    if(self = [super init]){
        _data = data;
        _currentLocation = 0;
    }
    
    return self;
}

- (NSData *)currentData
{
    if(!_data || _currentLocation > _data.length - 1){
        return nil;
    }
    
    NSData *currentData = nil;
    if(_currentLocation + MAX_PACKET_SIZE <= _data.length){
        currentData = [_data subdataWithRange:NSMakeRange(_currentLocation, MAX_PACKET_SIZE)];
        _currentLocation += MAX_PACKET_SIZE;
    }else{
        NSInteger length = _data.length - _currentLocation;
        currentData = [_data subdataWithRange:NSMakeRange(_currentLocation, length)];
        _currentLocation += length;
    }
    
    return currentData;
}

@end
