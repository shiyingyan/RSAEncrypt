

//
//  RSAEncryptor.m
//  DingDing
//
//  Created by ShiYing Yan on 12/4/15.
//  Copyright © 2015 Cstorm. All rights reserved.
//

#import "RSAEncryptor.h"

@interface RSAEncryptor ()

@property (nonatomic) SecKeyRef publicKey;
@property (nonatomic) SecKeyRef privateKey;

@end

@implementation RSAEncryptor


#pragma mark - Encrypt

-(NSString*) rsaEncryptString:(NSString*)string{
    NSData* data = [string dataUsingEncoding:NSUTF8StringEncoding];
    NSData* encryptedData = [self rsaEncryptData: data];
    NSString* base64EncryptedString = [encryptedData base64EncodedStringEncoding_Ext:NSUTF8StringEncoding];
    return base64EncryptedString;
}

// 加密的大小受限于SecKeyEncrypt函数，SecKeyEncrypt要求明文和密钥的长度一致，如果要加密更长的内容，需要把内容按密钥长度分成多份，然后多次调用SecKeyEncrypt来实现
-(NSData*) rsaEncryptData:(NSData*)data{
    SecKeyRef key = self.publicKey;
    size_t cipherBufferSize = SecKeyGetBlockSize(key);
    uint8_t *cipherBuffer = malloc(cipherBufferSize * sizeof(uint8_t));
    size_t blockSize = cipherBufferSize - 11;       // 分段加密
    size_t blockCount = (size_t)ceil([data length] / (double)blockSize);
    NSMutableData *encryptedData = [[NSMutableData alloc] init] ;
    for (int i=0; i<blockCount; i++) {
        int bufferSize = (int)MIN(blockSize,[data length] - i * blockSize);
        NSData *buffer = [data subdataWithRange:NSMakeRange(i * blockSize, bufferSize)];
        OSStatus status = SecKeyEncrypt(key, kSecPaddingPKCS1, (const uint8_t *)[buffer bytes], [buffer length], cipherBuffer, &cipherBufferSize);
        if (status == noErr){
            NSData *encryptedBytes = [[NSData alloc] initWithBytes:(const void *)cipherBuffer length:cipherBufferSize];
            [encryptedData appendData:encryptedBytes];
        }else{
            if (cipherBuffer) {
                free(cipherBuffer);
            }
            return nil;
        }
    }
    if (cipherBuffer){
        free(cipherBuffer);
    }
    return encryptedData;
}

#pragma mark - Decrypt

-(NSString*) rsaDecryptString:(NSString*)string{
    NSData *data = [string dataFromBase64String];
    NSData* decryptData = [self rsaDecryptData: data];
    NSString* result = [[NSString alloc] initWithData: decryptData encoding:NSUTF8StringEncoding];
    return result;
}

//解密的大小通加密一样，受限于SeckeyDecrypt函数SecKeyDecrypt要求密文和密钥的长度一致，如果解密更长的内容，需要把内容按密钥长度分成多份，然后多次调用SeckeyDecrypt来实现
-(NSData*) rsaDecryptData:(NSData*)data{
    SecKeyRef key = self.privateKey;
    size_t plainBufferSize = SecKeyGetBlockSize(key);
    uint8_t *plainBuffer = malloc(plainBufferSize * sizeof(uint8_t));
    size_t blockSize = plainBufferSize;      //分段解密
    size_t blockCount = (size_t)ceil([data length]/(double)blockSize);
    NSMutableData *decryptedData = [NSMutableData data];
    for (int i=0; i<blockCount; i++) {
        int bufferSize = (int)MIN(blockSize, [data length]-i*blockSize);
        NSData *buffer = [data subdataWithRange:NSMakeRange(i*blockSize, bufferSize)];
        OSStatus status = SecKeyDecrypt(key, kSecPaddingPKCS1, (const uint8_t *)[buffer bytes], [buffer length], plainBuffer, &plainBufferSize);
        if( status==noErr ){
            NSData *decryptedBytes = [[NSData alloc] initWithBytes:(const void *)plainBuffer length:plainBufferSize];
            [decryptedData appendData:decryptedBytes];
        }else{
            if( plainBuffer ){
                free(plainBuffer);
            }
            return nil;
        }
    }
    if( plainBuffer ){
        free(plainBuffer);
    }
    
    return decryptedData;

//    SecKeyRef key = self.privateKey;
//    size_t cipherLen = [data length];
//    void *cipher = malloc(cipherLen);
//    [data getBytes:cipher length:cipherLen];
//    size_t plainLen = SecKeyGetBlockSize(key) - 12;
//    void *plain = malloc(plainLen);
//    OSStatus status = SecKeyDecrypt(key, kSecPaddingPKCS1, cipher, cipherLen, plain, &plainLen);
//    NSLog(@"status = %d",status);
//    if (status != noErr) {
//        if( cipher )  free(cipher);
//        if( plain ) free(plain);
//        return nil;
//    }
//    
//    NSData *decryptedData = [[NSData alloc] initWithBytes:(const void *)plain length:plainLen];
//    
//    if( cipher )  free(cipher);
//    if( plain ) free(plain);
//
//    
//    return decryptedData;
}

#pragma mark - Private Methods

-(SecKeyRef) getPublicKeyRefrenceFromeData: (NSData*)derData
{
    SecCertificateRef myCertificate = SecCertificateCreateWithData(kCFAllocatorDefault, (__bridge CFDataRef)derData);
    SecPolicyRef myPolicy = SecPolicyCreateBasicX509();
    SecTrustRef myTrust;
    OSStatus status = SecTrustCreateWithCertificates(myCertificate,myPolicy,&myTrust);
    SecTrustResultType trustResult;
    if (status == noErr) {
        status = SecTrustEvaluate(myTrust, &trustResult);
        if( status != noErr ){
            CFRelease(myCertificate);
            CFRelease(myPolicy);
            CFRelease(myTrust);
            return nil;
        }
    }else{
        CFRelease(myCertificate);
        CFRelease(myPolicy);
        CFRelease(myTrust);
        return nil;
    }
    SecKeyRef securityKey = SecTrustCopyPublicKey(myTrust);
    CFRelease(myCertificate);
    CFRelease(myPolicy);
    CFRelease(myTrust);
    
    return securityKey;
}


-(SecKeyRef) getPrivateKeyRefrenceFromData: (NSData*)p12Data password:(NSString*)password
{
    SecKeyRef privateKeyRef = NULL;
    NSMutableDictionary * options = [[NSMutableDictionary alloc] init];
    [options setObject: password forKey:(__bridge id)kSecImportExportPassphrase];
    CFArrayRef items = CFArrayCreate(NULL, 0, 0, NULL);
    OSStatus securityError = SecPKCS12Import((__bridge CFDataRef) p12Data, (__bridge CFDictionaryRef)options, &items);
    if (securityError == noErr && CFArrayGetCount(items) > 0) {
        CFDictionaryRef identityDict = CFArrayGetValueAtIndex(items, 0);
        SecIdentityRef identityApp = (SecIdentityRef)CFDictionaryGetValue(identityDict, kSecImportItemIdentity);
        securityError = SecIdentityCopyPrivateKey(identityApp, &privateKeyRef);
        if (securityError != noErr) {
            privateKeyRef = NULL;
        }
    }
    CFRelease(items);
    
    return privateKeyRef;
}

#pragma mark - lazy loading
-(SecKeyRef)publicKey{
    NSData *derData = [NSData dataWithContentsOfFile:[self publicKeyPath]];
    return [self getPublicKeyRefrenceFromeData:derData];
}
-(SecKeyRef)privateKey{
    NSData *p12Data = [NSData dataWithContentsOfFile:[self privateKeyPath]];
    return [self getPrivateKeyRefrenceFromData:p12Data password:@"abcd1234"];
}

-(NSString *)publicKeyPath{
    return [[NSBundle mainBundle] pathForResource:@"public_key" ofType:@"der"];
}
-(NSString *)privateKeyPath{
    return [[NSBundle mainBundle] pathForResource:@"private_key" ofType:@"p12"];
}

@end