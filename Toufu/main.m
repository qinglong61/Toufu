//
//  main.m
//  Toufu
//
//  Created by 段清伦 on 15/11/29.
//  Copyright © 2015年 duanyu. All rights reserved.
//

#import "TFServer.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        TFServer *server = [[TFServer alloc] init];
        if ([server startOnPort:8989 proxy:NO]) {
            NSLog(@"Started server on port %zu.", (size_t)[server port]);
            [[NSRunLoop currentRunLoop] run];
        } else {
            NSLog(@"Error starting server");
        }
    }
    return EXIT_SUCCESS;
}
