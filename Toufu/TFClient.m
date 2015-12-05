//
//  TFClient.m
//  Toufu
//
//  Created by 段清伦 on 15/12/5.
//  Copyright © 2015年 duanyu. All rights reserved.
//

#import "TFClient.h"

@interface TFClient () <NSStreamDelegate>

@property (nonatomic, strong) NSString *hostName;
@property (nonatomic, assign) UInt32 port;
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) NSOutputStream *outputStream;
@property (nonatomic, strong) NSMutableData *inputBuffer;
@property (nonatomic, strong) NSMutableData *outputBuffer;

@end

@implementation TFClient

@synthesize hostName = _hostName;
@synthesize port = _port;
@synthesize inputStream  = _inputStream;
@synthesize outputStream = _outputStream;
@synthesize inputBuffer  = _inputBuffer;
@synthesize outputBuffer = _outputBuffer;

- (BOOL)getInputStream:(out NSInputStream **)inputStreamPtr
          outputStream:(out NSOutputStream **)outputStreamPtr
{
    BOOL                result;
    CFReadStreamRef     readStream;
    CFWriteStreamRef    writeStream;
    
    result = NO;
    
    readStream = NULL;
    writeStream = NULL;
    
    if ( (inputStreamPtr != NULL) || (outputStreamPtr != NULL) ) {
        CFStreamCreatePairWithSocketToHost(
                                           NULL,
                                           (__bridge CFStringRef)self.hostName,
                                           self.port,
                                           ((inputStreamPtr  != nil) ? &readStream  : NULL),
                                           ((outputStreamPtr != nil) ? &writeStream : NULL)
                                           );
        
        // We have failed if the client requested an input stream and didn't
        // get one, or requested an output stream and didn't get one.  We also
        // fail if the client requested neither the input nor the output
        // stream, but we don't get here in that case.
        
        result = ! ((( inputStreamPtr != NULL) && ( readStream == NULL)) ||
                    ((outputStreamPtr != NULL) && (writeStream == NULL)));
    }
    if (inputStreamPtr != NULL) {
        *inputStreamPtr  = CFBridgingRelease(readStream);
    }
    if (outputStreamPtr != NULL) {
        *outputStreamPtr = CFBridgingRelease(writeStream);
    }
    
    return result;
}

- (BOOL)openStreamsToHost:(NSString *)hostname
                     onPort:(UInt32)port
{
    NSInputStream * istream;
    NSOutputStream * ostream;
    
    [self closeStreams];
    
    if ([self getInputStream:&istream outputStream:&ostream]) {
        self.inputStream = istream;
        self.outputStream = ostream;
        [self.inputStream  setDelegate:self];
        [self.outputStream setDelegate:self];
        [self.inputStream  scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.inputStream  open];
        [self.outputStream open];
        return YES;
    }
    return NO;
}

- (void)closeStreams {
    [self.inputStream  setDelegate:nil];
    [self.outputStream setDelegate:nil];
    [self.inputStream  close];
    [self.outputStream close];
    [self.inputStream  removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    self.inputStream  = nil;
    self.outputStream = nil;
    self.inputBuffer  = nil;
    self.outputBuffer = nil;
}

- (void)startOutput
{
    assert([self.outputBuffer length] != 0);
    
    NSInteger actuallyWritten = [self.outputStream write:[self.outputBuffer bytes] maxLength:[self.outputBuffer length]];
    if (actuallyWritten > 0) {
        [self.outputBuffer replaceBytesInRange:NSMakeRange(0, (NSUInteger) actuallyWritten) withBytes:NULL length:0];
        // If we didn't write all the bytes we'll continue writing them in response to the next
        // has-space-available event.
    } else {
        // A non-positive result from -write:maxLength: indicates a failure of some form; in this
        // simple app we respond by simply closing down our connection.
        [self closeStreams];
    }
}

- (void)outputText:(NSString *)text
{
    NSData * dataToSend = [text dataUsingEncoding:NSUTF8StringEncoding];
    if (self.outputBuffer != nil) {
        BOOL wasEmpty = ([self.outputBuffer length] == 0);
        [self.outputBuffer appendData:dataToSend];
        if (wasEmpty) {
            [self startOutput];
        }
    }
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)streamEvent {
    assert(aStream == self.inputStream || aStream == self.outputStream);
    switch(streamEvent) {
        case NSStreamEventOpenCompleted: {
            // We don't create the input and output buffers until we get the open-completed events.
            // This is important for the output buffer because -outputText: is a no-op until the
            // buffer is in place, which avoids us trying to write to a stream that's still in the
            // process of opening.
            if (aStream == self.inputStream) {
                self.inputBuffer = [[NSMutableData alloc] init];
            } else {
                self.outputBuffer = [[NSMutableData alloc] init];
            }
        } break;
        case NSStreamEventHasSpaceAvailable: {
            if ([self.outputBuffer length] != 0) {
                [self startOutput];
            }
        } break;
        case NSStreamEventHasBytesAvailable: {
            uint8_t buffer[2048];
            NSInteger actuallyRead = [self.inputStream read:buffer maxLength:sizeof(buffer)];
            if (actuallyRead > 0) {
                [self.inputBuffer appendBytes:buffer length:(NSUInteger)actuallyRead];
                // If the input buffer ends with CR LF, show it to the user.
                if ([self.inputBuffer length] >= 2 && memcmp((const char *) [self.inputBuffer bytes] + [self.inputBuffer length] - 2, "\r\n", 2) == 0) {
                    NSString * string = [[NSString alloc] initWithData:self.inputBuffer encoding:NSUTF8StringEncoding];
                    if (string == nil) {
//                        [self.responseField setStringValue:@"response not UTF-8"];
                    } else {
//                        [self.responseField setStringValue:string];
                    }
                    [self.inputBuffer setLength:0];
                }
            } else {
                // A non-positive value from -read:maxLength: indicates either end of file (0) or
                // an error (-1).  In either case we just wait for the corresponding stream event
                // to come through.
            }
        } break;
        case NSStreamEventErrorOccurred:
        case NSStreamEventEndEncountered: {
            [self closeStreams];
        } break;
        default:
            break;
    }
}

@end
