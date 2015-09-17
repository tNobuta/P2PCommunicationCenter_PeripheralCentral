//
//  P2PMessage.m
//  BluetoothChatDemo
//
//  Created by tmy on 14-7-4.
//  Copyright (c) 2014年 hurray. All rights reserved.
//

#import "P2PMessage.h"
#import "NSString+P2PMD5.h"

NSString *const P2PMessageFromDeviceKey = @"P2PFrom";
NSString *const P2PMessageOriginDeviceKey = @"P2POrigin";
NSString *const P2PMessageToDeviceKey = @"P2PTo";
NSString *const P2PMessageIdentifierKey = @"P2PId";
NSString *const P2PMessageTypeKey = @"P2PType";
NSString *const P2PMessageSpreadCountKey = @"P2PSpread";
NSString *const P2PMessageContentKey = @"P2PContent";

@implementation P2PMessage

- (id)copyWithZone:(NSZone *)zone
{
    P2PMessage *copy = [[P2PMessage allocWithZone:zone] init];
    copy.messageIdentifier = [self.messageIdentifier copy];
    copy.type = self.type;
    copy.fromDeviceIdentifier = [self.fromDeviceIdentifier copy];
    copy.originDeviceIdentifier = [self.originDeviceIdentifier copy];
    copy.toDeviceIdentifier = [self.toDeviceIdentifier copy];
    copy.spreadCount = self.spreadCount;
    copy.content = [self.content copy];
    return copy;
}

+ (instancetype)messageWithContent:(NSString *)content
{
    P2PMessage *message = [[P2PMessage alloc] init];
    message.type = P2PMessageTypeChat;
    message.content = content && (NSNull *)content != [NSNull null]? content: @"";
    return message;
}

+ (instancetype)messageWithContent:(NSString *)content toDeviceIdentifier:(NSString *)toDeviceIdentifier
{
    P2PMessage *message = [[P2PMessage alloc] init];
    message.type = P2PMessageTypeChat;
    message.content =  content && (NSNull *)content != [NSNull null]? content: @"";
    message.toDeviceIdentifier = toDeviceIdentifier;
    return message;
}

+ (instancetype)messageWithJsonData:(NSData *)data
{
    NSDictionary *dataDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if(dataDict){
        P2PMessage *message = [[P2PMessage alloc] init];
        message.messageIdentifier = dataDict[P2PMessageIdentifierKey];
        message.type = [dataDict[P2PMessageTypeKey] intValue];
        message.fromDeviceIdentifier = dataDict[P2PMessageFromDeviceKey];
        message.originDeviceIdentifier = dataDict[P2PMessageOriginDeviceKey];
        message.toDeviceIdentifier = dataDict[P2PMessageToDeviceKey];
        message.spreadCount = [dataDict[P2PMessageSpreadCountKey] intValue];
        message.content = dataDict[P2PMessageContentKey];
        return message;
    }else{
        return nil;
    }
}

+ (instancetype)messageForSyncDeviceOnline:(BOOL)isOnline
{
    P2PMessage *message = [[P2PMessage alloc] init];
    message.type = P2PMessageTypeSyncOnline;
    message.content = [NSString stringWithFormat:@"%@", isOnline?@"1":@"0"];
    return message;
}

- (id)init
{
    if(self == [super init]){
        self.messageIdentifier = [[[NSUUID UUID] UUIDString] md5ValueForP2P];
    }
    
    return self;
}

- (NSData *)dataToSend
{
    NSMutableDictionary *dataDict = [@{
                               P2PMessageIdentifierKey: self.messageIdentifier,
                               P2PMessageTypeKey: @(self.type),
                               P2PMessageFromDeviceKey: self.fromDeviceIdentifier,
                               P2PMessageOriginDeviceKey: self.originDeviceIdentifier,
                               P2PMessageSpreadCountKey: @(self.spreadCount),
                               P2PMessageContentKey : self.content
                               } mutableCopy];
    if(self.toDeviceIdentifier){
        dataDict[P2PMessageToDeviceKey] = self.toDeviceIdentifier;
    }
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dataDict options:0 error:nil];
    return jsonData;
}

@end
