//
//  TFServer.m
//  Toufu
//
//  Created by 段清伦 on 15/11/29.
//  Copyright © 2015年 duanyu. All rights reserved.
//

#import "TFServer.h"
#import "TFConnection.h"
#import "TFClient.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

@interface TFServer () <TFConnectionDelegate>

@property (nonatomic, assign) NSUInteger port;
@property (nonatomic, assign) BOOL isProxy;

@property (nonatomic, strong, readonly) NSMutableSet *connections;
@property (nonatomic, strong) TFClient *client;

@end

@implementation TFServer {
    CFSocketRef _ipv4socket;
    CFSocketRef _ipv6socket;
}

@synthesize port = _port;
@synthesize isProxy = _isProxy;
@synthesize connections = _connections;
@synthesize client = _client;

- (id)init
{
    self = [super init];
    if (self != nil) {
        _connections = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void)dealloc {
    [self stop];
}

- (void)acceptConnection:(CFSocketNativeHandle)nativeSocketHandle
{
    CFReadStreamRef readStream = NULL;
    CFWriteStreamRef writeStream = NULL;
    CFStreamCreatePairWithSocket(kCFAllocatorDefault, nativeSocketHandle, &readStream, &writeStream);
    if (readStream && writeStream) {
        CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
        CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
        
        TFConnection *connection = [[TFConnection alloc] initWithInputStream:(__bridge NSInputStream *)readStream outputStream:(__bridge NSOutputStream *)writeStream delegate:self];
        [self.connections addObject:connection];
        [connection open];
        NSLog(@"Added connection.");
    } else {
        // On any failure, we need to destroy the CFSocketNativeHandle
        // since we are not going to use it any more.
        (void) close(nativeSocketHandle);
    }
    if (readStream) CFRelease(readStream);
    if (writeStream) CFRelease(writeStream);
}

// This function is called by CFSocket when a new connection comes in.
static void TFServerAcceptCallBack(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
    assert(type == kCFSocketAcceptCallBack);
    
    TFServer *server = (__bridge TFServer *)info;
    assert(socket == server->_ipv4socket || socket == server->_ipv6socket);
    
    // For an accept callback, the data parameter is a pointer to a CFSocketNativeHandle.
    [server acceptConnection:*(CFSocketNativeHandle *)data];
}

- (BOOL)startOnPort:(NSUInteger)port proxy:(BOOL)isProxy
{
    assert(_ipv4socket == NULL && _ipv6socket == NULL);       // don't call -start twice!
    assert(port > 0 && port < 65536);
    
    self.port = port;
    self.isProxy = isProxy;
    
    if (isProxy) {
        TFClient *client = [[TFClient alloc] init];
        self.client = client;
    }
    
    CFSocketContext socketCtxt = {0, (__bridge void *) self, NULL, NULL, NULL};
    _ipv4socket = CFSocketCreate(kCFAllocatorDefault, AF_INET,  SOCK_STREAM, 0, kCFSocketAcceptCallBack, &TFServerAcceptCallBack, &socketCtxt);
    _ipv6socket = CFSocketCreate(kCFAllocatorDefault, AF_INET6, SOCK_STREAM, 0, kCFSocketAcceptCallBack, &TFServerAcceptCallBack, &socketCtxt);
    
    if (NULL == _ipv4socket || NULL == _ipv6socket) {
        [self stop];
        return NO;
    }
    
    static const int yes = 1;
    (void) setsockopt(CFSocketGetNative(_ipv4socket), SOL_SOCKET, SO_REUSEADDR, (const void *) &yes, sizeof(yes));
    (void) setsockopt(CFSocketGetNative(_ipv6socket), SOL_SOCKET, SO_REUSEADDR, (const void *) &yes, sizeof(yes));
    
    // Set up the IPv4 listening socket;
    struct sockaddr_in addr4;
    memset(&addr4, 0, sizeof(addr4));
    addr4.sin_len = sizeof(addr4);
    addr4.sin_family = AF_INET;
    addr4.sin_port = htons(port);
    addr4.sin_addr.s_addr = htonl(INADDR_ANY);
    if (kCFSocketSuccess != CFSocketSetAddress(_ipv4socket, (__bridge CFDataRef) [NSData dataWithBytes:&addr4 length:sizeof(addr4)])) {
        [self stop];
        return NO;
    }
    
    // Set up the IPv6 listening socket.
    struct sockaddr_in6 addr6;
    memset(&addr6, 0, sizeof(addr6));
    addr6.sin6_len = sizeof(addr6);
    addr6.sin6_family = AF_INET6;
    addr6.sin6_port = htons(self.port);
    memcpy(&(addr6.sin6_addr), &in6addr_any, sizeof(addr6.sin6_addr));
    if (kCFSocketSuccess != CFSocketSetAddress(_ipv6socket, (__bridge CFDataRef) [NSData dataWithBytes:&addr6 length:sizeof(addr6)])) {
        [self stop];
        return NO;
    }
    
    // Set up the run loop sources for the sockets.
    CFRunLoopSourceRef source4 = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _ipv4socket, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source4, kCFRunLoopCommonModes);
    CFRelease(source4);
    
    CFRunLoopSourceRef source6 = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _ipv6socket, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source6, kCFRunLoopCommonModes);
    CFRelease(source6);
    
    return YES;
}

- (void)stop
{
    // Closes all the open connections.  The TFConnectionDidCloseNotification notification will ensure
    // that the connection gets removed from the self.connections set.  To avoid mututation under iteration
    // problems, we make a copy of that set and iterate over the copy.
    for (TFConnection *connection in [self.connections copy]) {
        [connection close];
    }
    if (_ipv4socket != NULL) {
        CFSocketInvalidate(_ipv4socket);
        CFRelease(_ipv4socket);
        _ipv4socket = NULL;
    }
    if (_ipv6socket != NULL) {
        CFSocketInvalidate(_ipv6socket);
        CFRelease(_ipv6socket);
        _ipv6socket = NULL;
    }
}

#pragma mark - private

void extractHostPortFromRequest(NSString *request, NSString **host, NSUInteger *port)
{
    for (NSString *header in [request componentsSeparatedByString:@"\r\n"]) {
        if ([header hasPrefix:@"Host: "]) {
            NSString *hostAndPort = [header substringFromIndex:@"Host: ".length];
            NSArray *arr = [hostAndPort componentsSeparatedByString:@":"];
            *host = arr[0];
            if (arr.count == 2) {
                *port = [arr[1] integerValue];   
            }
            return;
        }
    }
}

#pragma mark - TFConnectionDelegate

- (void)connectionDidOpen:(TFConnection *)connection
{
    NSLog(@"server connection opened.");
}

- (void)connection:(TFConnection *)connection didReceiveData:(NSData *)data
{
    NSString *request = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"server received request:\n%@", request);
    
    __block NSString *response = @"HTTP/1.1 200 OK\r\n\
Server: Toufu\r\n\
Connection: keep-alive\r\n\
Content-Type: text/html; charset=utf-8\r\n\
Content-Language: zh-CN,zh\r\n\
\r\n\
<html><body><h1>This is Toufu!</h1></body></html>\r\n";
    
    if (self.isProxy) {
        
        NSString *host;
        NSUInteger port = 80;
        extractHostPortFromRequest(request, &host, &port);
        
        if ([self.client connectToHost:host onPort:port]) {
            [self.client sendRequest:data withResponseHandler:^(NSData *responseData) {
                
                NSUInteger numberOfBytes = [responseData length];
                uint8_t outputBuffer[numberOfBytes];
                [responseData getBytes:outputBuffer length:numberOfBytes];
                
                NSInteger actuallyWritten = [connection.outputStream write:outputBuffer maxLength:(NSUInteger)numberOfBytes];
                NSLog(@"server responsed %zd bytes.", (ssize_t) actuallyWritten);
                [connection close];
            }];
        }
    } else {
        const uint8_t *buffer = [[response dataUsingEncoding:NSUTF8StringEncoding] bytes];
        NSInteger actuallyWritten = [connection.outputStream write:buffer maxLength:response.length];
        NSLog(@"server responsed %zd bytes.", (ssize_t) actuallyWritten);
        [connection close];
    }
}

- (void)connectionCanWrite:(TFConnection *)connection
{

}

- (void)connectionDidClose:(TFConnection *)connection WithError:(NSError *)error
{
    [self.connections removeObject:connection];
    if (error) {
        NSLog(@"server connection closed with Error:\n%@", error);
    } else {
        NSLog(@"server connection closed.");
    }
}

@end