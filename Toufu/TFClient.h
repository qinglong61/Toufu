//
//  TFClient.h
//  Toufu
//
//  Created by 段清伦 on 15/12/5.
//  Copyright © 2015年 duanyu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TFClient : NSObject

@property (nonatomic, strong, readonly) NSString *hostName;
@property (nonatomic, assign, readonly) NSUInteger port;

- (BOOL)connectToHost:(NSString *)hostName onPort:(NSUInteger)port;
- (void)sendRequest:(NSData *)requestData withResponseHandler:(void (^)(NSData *responseData))handler;

@end
