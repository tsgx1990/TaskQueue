//
//  YLBlockTask.m
//  YLTaskQueue
//
//  Created by guanglong on 2019/6/24.
//  Copyright © 2019 guanglong. All rights reserved.
//

#import "YLBlockTask.h"

@interface YLBlockTask ()

@property (nonatomic, copy) YLStartTaskBlock startBlock;
@property (nonatomic, copy) YLStopTaskBlock stopBlock;

@property (nonatomic, weak) id startupObj;

@end

@implementation YLBlockTask

- (instancetype)initWithStart:(YLStartTaskBlock)start andStop:(YLStopTaskBlock)stop
{
    assert(start && stop);
    if (self = [super init]) {
        self.startBlock = start;
        self.stopBlock = stop;
    }
    return self;
}

+ (instancetype)taskWithStart:(YLStartTaskBlock)start andStop:(YLStopTaskBlock)stop
{
    return [self.alloc initWithStart:start andStop:stop];
}

#pragma mark - - override
- (id)startForResume:(BOOL)resume withResult:(YLTaskResult *)result
{
    self.startupObj = nil;
    self.startupObj = self.startBlock(self, resume, result);
    return self.startupObj;
}

- (void)stopForPause:(BOOL)pause
{
    self.stopBlock(self, pause, self.startupObj);
}

@end
