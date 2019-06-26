//
//  YLBaseTask.m
//  App
//
//  Created by guanglong on 2019/6/21.
//  Copyright © 2019 guanglong. All rights reserved.
//

#import "YLBaseTask.h"

@implementation YLTaskResult
@synthesize data = _data, error = _error;

- (instancetype)initWithData:(id)data error:(id)error
{
    if (self = [super init]) {
        _data = data;
        _error = error;
    }
    return self;
}

+ (instancetype)resultWithData:(id)data error:(id)error
{
    return [[self alloc] initWithData:data error:error];
}

- (NSString *)description
{
    NSString *desc = [NSString stringWithFormat:@"{\n  data: %@,\n  error: %@\n}", _data, _error];
    return desc;
}

@end

@interface YLBaseTask ()

@property (nonatomic, assign) YLBaseTaskState state;

@property (nonatomic, copy) void(^completeCallback)(YLBaseTask *task, YLTaskResult *result);
@property (nonatomic, copy) void(^cancelCallback)(YLBaseTask *task);

@end

@implementation YLBaseTask

- (instancetype)init
{
    if (self = [super init]) {
        self.onMainThread = NSThread.isMainThread;
        self.state = YLBaseTaskStateInitial;
        self.actionWhenCovered = YLBaseTaskActionWhenCoveredPause;
    }
    return self;
}

- (void)setName:(NSString *)name
{
    assert(self.state == YLBaseTaskStateInitial);
    _name = name.copy;
}

- (void)setPriority:(NSInteger)priority
{
    assert(self.state == YLBaseTaskStateInitial);
    _priority = priority;
}

- (void)setActionWhenCovered:(YLBaseTaskActionWhenCovered)actionWhenCovered
{
    assert(self.state == YLBaseTaskStateInitial);
    _actionWhenCovered = actionWhenCovered;
}

- (void)cancel
{
    if (self.cancelCallback) {
        self.cancelCallback(self);
    }
}

- (void)complete
{
    [self completeWithResult:nil];
}

- (void)completeWithData:(id)data error:(id)error
{
    YLTaskResult *result = [YLTaskResult resultWithData:data error:error];
    [self completeWithResult:result];
}

- (void)completeWithResult:(YLTaskResult *)result
{
    if (self.completeCallback) {
        self.completeCallback(self, result);
    }
}

- (id)startForResume:(BOOL)resume withResult:(YLTaskResult *)result
{
    NSLog(@"Do nothing! Subclass should override this method.");
    return nil;
}

- (void)stopForPause:(BOOL)pause
{
    NSLog(@"Do nothing! Subclass should override this method.");
}

- (NSString *)description
{
    NSString *stateDesc = @"Initial";
    if (self.state == YLBaseTaskStatePending) {
        stateDesc = @"Pending";
    }
    if (self.state == YLBaseTaskStateRunning) {
        stateDesc = @"Running";
    }
    if (self.state == YLBaseTaskStatePausing) {
        stateDesc = @"Pausing";
    }
    if (self.state == YLBaseTaskStatePaused) {
        stateDesc = @"Paused";
    }
    
    NSString *coverActionDesc = @"Do nothing when covered";
    if (self.actionWhenCovered == YLBaseTaskActionWhenCoveredPause) {
        coverActionDesc = @"Pause when covered";
    }
    if (self.actionWhenCovered == YLBaseTaskActionWhenCoveredStop) {
        coverActionDesc = @"Stop when covered";
    }
    
    NSString *desc = [NSString stringWithFormat:@"{\n  name: %@\n  priority: %@\n  actionWhenCovered: %@\n  state: %@\n} %@", self.name, @(self.priority), coverActionDesc, stateDesc, super.description];
    return desc;
}

- (void)dealloc
{
    NSLog(@"Task Dealloc: %@", self);
}

@end
