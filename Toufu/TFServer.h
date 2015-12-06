//
//  TFServer.h
//  Toufu
//
//  Created by 段清伦 on 15/11/29.
//  Copyright © 2015年 duanyu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TFServer : NSObject

@property (nonatomic, assign, readonly) NSUInteger port;
@property (nonatomic, assign, readonly) BOOL isProxy;

- (BOOL)startOnPort:(NSUInteger)port proxy:(BOOL)isProxy;
- (void)stop;

@end
