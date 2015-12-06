//
//  TFConnection.h
//  Toufu
//
//  Created by 段清伦 on 15/11/29.
//  Copyright © 2015年 duanyu. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TFConnection;

@protocol TFConnectionDelegate <NSObject>

@optional
- (void)connectionDidOpen:(TFConnection *)connection;
- (void)connection:(TFConnection *)connection didReceiveData:(NSData *)data;
- (void)connectionCanWrite:(TFConnection *)connection;
- (void)connectionWillClose:(TFConnection *)connection WithError:(NSError *)error;
- (void)connectionDidClose:(TFConnection *)connection WithError:(NSError *)error;

//- (NSURLRequest *)connection:(TFConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response;
//
//- (void)connection:(TFConnection *)connection didReceiveResponse:(NSData *)response;

//- (NSInputStream *)connection:(TFConnection *)connection needNewBodyStream:(NSURLRequest *)request;
//
//- (void)connection:(TFConnection *)connection didSendBodyData:(NSInteger)bytesWritten
// totalBytesWritten:(NSInteger)totalBytesWritten
//totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite;
//
//- (NSCachedURLResponse *)connection:(TFConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse;
//
//- (void)connectionDidFinishLoading:(TFConnection *)connection;

@end

@interface TFConnection : NSObject

- (id)initWithInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream delegate:(id<TFConnectionDelegate>)delegate;

@property (nonatomic, strong, readonly) NSInputStream *inputStream;
@property (nonatomic, strong, readonly) NSOutputStream *outputStream;
@property (nonatomic, assign) id<TFConnectionDelegate> delegate;

- (BOOL)open;
- (void)close;

@end
