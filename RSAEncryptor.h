//
//  RSAEncryptor.h
//  DingDing
//
//  Created by ShiYing Yan on 12/4/15.
//  Copyright © 2015 Cstorm. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RSAEncryptor : NSObject

-(NSString*) rsaEncryptString:(NSString*)string;
-(NSData*) rsaEncryptData:(NSData*)data;

-(NSString*) rsaDecryptString:(NSString*)string;
-(NSData*) rsaDecryptData:(NSData*)data;

@end