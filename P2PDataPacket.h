//
//  P2PDataPacket.h
//  BluetoothChatDemo
//
//  Created by tmy on 14-7-15.
//  Copyright (c) 2014年 hurray. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface P2PDataPacket : NSObject

+ (instancetype)packetWithData:(NSData *)data;
- (id)initWithData:(NSData *)data;
- (NSData *)currentData;

@end
