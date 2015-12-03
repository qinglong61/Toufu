//
//  TFConnection.h
//  Toufu
//
//  Created by 段清伦 on 15/11/29.
//  Copyright © 2015年 duanyu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TFConnection : NSObject

- (id)initWithInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream;

@property (nonatomic, strong, readonly) NSInputStream *inputStream;
@property (nonatomic, strong, readonly) NSOutputStream *outputStream;

- (BOOL)open;
- (void)close;

extern NSString * TFConnectionDidCloseNotification;

@end
