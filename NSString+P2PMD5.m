//
//  NSString+P2PMD5.m
//  BluetoothChatDemo
//
//  Created by tmy on 14-7-15.
//  Copyright (c) 2014年 hurray. All rights reserved.
//

#import <CommonCrypto/CommonCrypto.h>
#import "NSString+P2PMD5.h"

@implementation NSString (P2PMD5)

- (NSString *) md5ValueForP2P
{
    const char *cStr = [self UTF8String];
    unsigned char result[16];
    CC_MD5( cStr, (UInt32)strlen(cStr), result ); // This is the md5 call
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x",
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11]
            ];
}

@end
