//
//  main.m
//  Toufu
//
//  Created by 段清伦 on 15/11/29.
//  Copyright © 2015年 duanyu. All rights reserved.
//

#import "TFServer.h"
#import "TFClient.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        TFServer *server = [[TFServer alloc] init];
        TFClient *client = [[TFClient alloc] init];
        if ( [server startOnPort:8080] ) {
            NSLog(@"Started server on port %zu.", (size_t)[server port]);
            [client openStreamsToHost:@"127.0.0.1" onPort:8080];
            [[NSRunLoop currentRunLoop] run];
        } else {
            NSLog(@"Error starting server");
        }
    }
    return EXIT_SUCCESS;
}
