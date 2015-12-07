//
//  TFClient.m
//  Toufu
//
//  Created by 段清伦 on 15/12/5.
//  Copyright © 2015年 duanyu. All rights reserved.
//

#import "TFClient.h"
#import "TFConnection.h"

@interface TFClient () <TFConnectionDelegate>

@property (nonatomic, strong) NSString *hostName;
@property (nonatomic, assign) NSUInteger port;

@property (nonatomic, strong) TFConnection *connection;
@property (nonatomic, strong) NSMutableData *inputBuffer;
@property (nonatomic, strong) NSMutableData *outputBuffer;
@property (nonatomic, copy) void (^responseHandler)(NSData *responseData);

@end

@implementation TFClient

@synthesize hostName = _hostName;
@synthesize port = _port;
@synthesize connection = _connection;
@synthesize inputBuffer = _inputBuffer;
@synthesize outputBuffer = _outputBuffer;
@synthesize responseHandler = _responseHandler;

- (id)init
{
    if (self = [super init]) {
        self.inputBuffer = [[NSMutableData alloc] init];
        self.outputBuffer = [[NSMutableData alloc] init];
    }
    return self;
}

- (void)dealloc
{
    self.inputBuffer = nil;
    self.outputBuffer = nil;
}

- (BOOL)connectToHost:(NSString *)hostname
               onPort:(NSUInteger)port
{
    BOOL result;
    self.hostName = hostname;
    self.port = port;
    
    CFReadStreamRef readStream = NULL;
    CFWriteStreamRef writeStream = NULL;
    CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (__bridge CFStringRef)self.hostName, (UInt32)self.port, &readStream, &writeStream);
    
    if (readStream && writeStream) {
        CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
        CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
        
        TFConnection *connection = [[TFConnection alloc] initWithInputStream:(__bridge NSInputStream *)readStream outputStream:(__bridge NSOutputStream *)writeStream delegate:self];
        [self.connection close];
        self.connection = connection;
        [connection open];
        result = YES;
    }
    if (readStream) CFRelease(readStream);
    if (writeStream) CFRelease(writeStream);
    return result;
}

- (void)startOutput
{
    assert([self.outputBuffer length] != 0);
    
    NSInteger actuallyWritten = [self.connection.outputStream write:[self.outputBuffer bytes] maxLength:[self.outputBuffer length]];
    if (actuallyWritten > 0) {
        [self.outputBuffer replaceBytesInRange:NSMakeRange(0, (NSUInteger) actuallyWritten) withBytes:NULL length:0];
        // If we didn't write all the bytes we'll continue writing them in response to the next
        // has-space-available event.
    } else {
        // A non-positive result from -write:maxLength: indicates a failure of some form; in this
        // simple app we respond by simply closing down our connection.
        [self.connection close];
    }
}

- (void)sendRequest:(NSData *)requestData withResponseHandler:(void (^)(NSData *))handler
{
    self.responseHandler = handler;
    
    BOOL wasEmpty = ([self.outputBuffer length] == 0);
    [self.outputBuffer appendData:requestData];
    if (wasEmpty) {
        [self startOutput];
    }
}

#pragma mark - TFConnectionDelegate

- (void)connectionDidOpen:(TFConnection *)connection
{
    NSLog(@"client connection opened.");
}

- (void)connectionCanWrite:(TFConnection *)connection
{
//    if ([self.outputBuffer length] != 0) {
//        [self startOutput];
//    }
}

- (void)connection:(TFConnection *)connection didReceiveData:(NSData *)data
{
    [self.inputBuffer appendData:data];
    // If the input buffer ends with CR LF, show it to the user.
//    if ([self.inputBuffer length] >= 2 && memcmp((const char *) [self.inputBuffer bytes] + [self.inputBuffer length] - 2, "\r\n", 2) == 0) {
        NSString *string = [[NSString alloc] initWithData:self.inputBuffer encoding:NSUTF8StringEncoding]?:@"response not UTF-8";
        NSLog(@"client received response:\n%@", string);
        if (self.responseHandler) {
            self.responseHandler(self.inputBuffer);
        }
        [self.inputBuffer setLength:0];
//    }
}

- (void)connectionDidClose:(TFConnection *)connection WithError:(NSError *)error
{
    self.connection = nil;
    if (error) {
        NSLog(@"client connection closed with Error:\n%@", error);
    } else {
        NSLog(@"client connection closed.");
    }
}

@end