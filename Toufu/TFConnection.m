//
//  TFConnection.m
//  Toufu
//
//  Created by 段清伦 on 15/11/29.
//  Copyright © 2015年 duanyu. All rights reserved.
//

#import "TFConnection.h"

NSString * TFConnectionDidCloseNotification = @"TFConnectionDidCloseNotification";

@interface TFConnection () <NSStreamDelegate>
@end

@implementation TFConnection

@synthesize inputStream  = _inputStream;
@synthesize outputStream = _outputStream;

- (id)initWithInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream
{
    self = [super init];
    if (self != nil) {
        _inputStream = inputStream;
        _outputStream = outputStream;
    }
    return self;
}

- (BOOL)open {
    [self.inputStream  setDelegate:self];
    [self.outputStream setDelegate:self];
    [self.inputStream  scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.inputStream  open];
    [self.outputStream open];
    return YES;
}

- (void)close {
    [self.inputStream  setDelegate:nil];
    [self.outputStream setDelegate:nil];
    [self.inputStream  close];
    [self.outputStream close];
    [self.inputStream  removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [(NSNotificationCenter *)[NSNotificationCenter defaultCenter] postNotificationName:TFConnectionDidCloseNotification object:self];
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)streamEvent {
    assert(aStream == self.inputStream || aStream == self.outputStream);
    
    switch(streamEvent) {
        case NSStreamEventHasBytesAvailable: {
            uint8_t inputBuffer[2048];
            NSInteger actuallyRead = [self.inputStream read:(uint8_t *)inputBuffer maxLength:sizeof(inputBuffer)];
            if (actuallyRead > 0) {
                
                NSString *request = [[NSString alloc] initWithBytes:inputBuffer length:actuallyRead encoding:NSUTF8StringEncoding];
                NSLog(@"request:\n%@", request);
                
                NSString *response = @"HTTP/1.1 200 OK\n\
                Server: Toufu\n\
                Connection: keep-alive\n\
                Content-Type: text/html; charset=utf-8\n\
                Content-Language: zh-CN,zh\n\
                \n\
                <html><body><h1>It works!</h1></body></html>";
                
                NSUInteger numberOfBytes = [response lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
                uint8_t outputBuffer[numberOfBytes];
                NSUInteger usedLength = 0;
                NSRange range = NSMakeRange(0, [response length]);
                [response getBytes:outputBuffer maxLength:numberOfBytes usedLength:&usedLength encoding:NSUTF8StringEncoding options:0 range:range remainingRange:NULL];
//                    NSLog(@"%@", [[NSString alloc] initWithBytes:outputBuffer length:numberOfBytes encoding:NSUTF8StringEncoding]);
                
                NSInteger actuallyWritten = [self.outputStream write:outputBuffer maxLength:(NSUInteger)numberOfBytes];
                NSLog(@"Echoed %zd bytes.", (ssize_t) actuallyWritten);
                [self close];
            } else {
                // A non-positive value from -read:maxLength: indicates either end of file (0) or
                // an error (-1).  In either case we just wait for the corresponding stream event
                // to come through.
            }
        } break;
        case NSStreamEventEndEncountered:
        case NSStreamEventErrorOccurred: {
            [self close];
        } break;
        case NSStreamEventHasSpaceAvailable:
        case NSStreamEventOpenCompleted:
        default: {
            // do nothing
        } break;
    }
}

@end