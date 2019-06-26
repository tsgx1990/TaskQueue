//
//  TaskStartup.m
//  YLTaskQueue
//
//  Created by guanglong on 2019/6/24.
//  Copyright © 2019 guanglong. All rights reserved.
//

#import "TaskStartup.h"

@implementation TaskStartup

- (void)start
{
    float delay = 1 + arc4random() % 100 / 100.0;
    [self performSelector:@selector(complete) withObject:nil afterDelay:delay];
}

- (void)stop
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(complete) object:nil];
}

- (void)complete
{
    if (self.completeBlock) {
        self.completeBlock(self);
    }
}

@end
