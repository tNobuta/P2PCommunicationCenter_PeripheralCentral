//
//  P2PMessage.h
//  BluetoothChatDemo
//
//  Created by tmy on 14-7-4.
//  Copyright (c) 2014年 hurray. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const P2PMessageFromDeviceKey;
extern NSString *const P2PMessageIdentifierKey;
extern NSString *const P2PMessageSpreadCountKey;
extern NSString *const P2PMessageContentKey;

typedef enum
{
    P2PMessageTypeChat = 1,         //content字段为聊天内容
    P2PMessageTypeSyncOnline = 2    //content字段为id|1或id|-1
}P2PMessageType;

@interface P2PMessage : NSObject<NSCopying>

@property (nonatomic, strong) NSString *messageIdentifier;
@property (nonatomic) P2PMessageType type;
@property (nonatomic, strong) NSString *fromDeviceIdentifier; //发送消息的设备识别符,转播情况下是转播设备的识别符
@property (nonatomic, strong) NSString *originDeviceIdentifier; //真正发出消息的设备识别符
@property (nonatomic, strong) NSString *toDeviceIdentifier;
@property (nonatomic) int spreadCount;
@property (nonatomic, strong) NSString *content;

//广播消息到所有连接设备
+ (instancetype)messageWithContent:(NSString *)content;

//发送消息到指定连接设备
+ (instancetype)messageWithContent:(NSString *)content toDeviceIdentifier:(NSString *)toDeviceIdentifier;

+ (instancetype)messageWithJsonData:(NSData *)data;

+ (instancetype)messageForSyncDeviceOnline:(BOOL)isOnline;

- (NSData *)dataToSend;


@end
