//
//  TFConnection.m
//  Toufu
//
//  Created by 段清伦 on 15/11/29.
//  Copyright © 2015年 duanyu. All rights reserved.
//

#import "TFConnection.h"

@interface TFConnection () <NSStreamDelegate>
@end

@implementation TFConnection

@synthesize inputStream  = _inputStream;
@synthesize outputStream = _outputStream;
@synthesize delegate = _delegate;

- (id)initWithInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream delegate:(id<TFConnectionDelegate>)delegate
{
    self = [super init];
    if (self != nil) {
        _inputStream = inputStream;
        _outputStream = outputStream;
        _delegate = delegate;
    }
    return self;
}

- (BOOL)open
{
    [self.inputStream  setDelegate:self];
    [self.outputStream setDelegate:self];
    [self.inputStream  scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.inputStream  open];
    [self.outputStream open];
    return YES;
}

- (void)close
{
    [self closeWithError:nil];
}

- (void)closeWithError:(NSError *)error
{
    if ([self.delegate respondsToSelector:@selector(connectionWillClose:WithError:)]) {
        [self.delegate connectionWillClose:self WithError:error];
    }
    
    [self.inputStream  setDelegate:nil];
    [self.outputStream setDelegate:nil];
    [self.inputStream  close];
    [self.outputStream close];
    [self.inputStream  removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

    if ([self.delegate respondsToSelector:@selector(connectionDidClose:WithError:)]) {
        [self.delegate connectionDidClose:self WithError:error];
    }
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)streamEvent
{
    if (aStream == self.inputStream || aStream == self.outputStream) {
        switch(streamEvent) {
            case NSStreamEventOpenCompleted: {
                if ([self.delegate respondsToSelector:@selector(connectionDidOpen:)]) {
                    [self.delegate connectionDidOpen:self];
                }
            } break;
            case NSStreamEventHasSpaceAvailable: {
                if ([self.delegate respondsToSelector:@selector(connectionCanWrite:)]) {
                    [self.delegate connectionCanWrite:self];
                }
            } break;
            case NSStreamEventHasBytesAvailable: {
                uint8_t buffer[2048];
                NSInteger actuallyRead = [self.inputStream read:(uint8_t *)buffer maxLength:sizeof(buffer)];
                if (actuallyRead > 0) {
                    if ([self.delegate respondsToSelector:@selector(connection:didReceiveData:)]) {
                        NSData *data = [[NSData alloc] initWithBytes:buffer length:actuallyRead];
                        [self.delegate connection:self didReceiveData:data];
                    }
                } else {
                    // A non-positive value from -read:maxLength: indicates either end of file (0) or
                    // an error (-1).  In either case we just wait for the corresponding stream event
                    // to come through.
                }
            } break;
            case NSStreamEventEndEncountered:
            case NSStreamEventErrorOccurred: {
                if (aStream.streamStatus != NSStreamStatusClosed && aStream.streamStatus != NSStreamStatusNotOpen) {
                    [self closeWithError:[aStream streamError]];
                }
            } break;
            default: {
                // do nothing
            } break;
        }
    }
}

@end