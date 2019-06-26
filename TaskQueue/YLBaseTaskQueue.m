//
//  YLBaseTaskQueue.m
//  App
//
//  Created by guanglong on 2019/6/21.
//  Copyright © 2019 guanglong. All rights reserved.
//

#import "YLBaseTaskQueue.h"
#import <objc/runtime.h>

@interface YLBaseTask (override_to_writable_for_queue_use)

@property (nonatomic, assign) YLBaseTaskState state;
@property (nonatomic, copy) void(^completeCallback)(YLBaseTask *task, YLTaskResult *result);
@property (nonatomic, copy) void(^cancelCallback)(YLBaseTask *task);

@property (nonatomic, strong) YLTaskResult *taskResult;

@end

@implementation YLBaseTask (_sync_perform_task_)

- (void)setTaskResult:(YLTaskResult *)taskResult
{
    objc_setAssociatedObject(self, @selector(taskResult), taskResult, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (YLTaskResult *)taskResult
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)_syncPerformWithBlock:(void(^)(YLBaseTask *task))block
{
    if (!self.onMainThread || NSThread.isMainThread) {
        block(self);
    }
    else {
        [self performSelectorOnMainThread:_cmd withObject:block waitUntilDone:YES];
    }
}

- (id)_syncStartForResume:(BOOL)resume withResult:(YLTaskResult *)result
{
    __block id startup = nil;
    [self _syncPerformWithBlock:^(YLBaseTask *task) {
        startup = [task startForResume:resume withResult:result];
    }];
    return startup;
}

- (void)_syncStopForPause:(BOOL)pause
{
    [self _syncPerformWithBlock:^(YLBaseTask *task) {
        [task stopForPause:pause];
    }];
}

@end


#pragma mark - - YLBaseTaskQueue

@protocol _YLBaseTaskQueueShouldOverrideProtocol <NSObject>

@optional
- (id)_startForResume:(BOOL)resume withResult:(YLTaskResult *)result;
- (void)_stopForPause:(BOOL)pause;

- (void)_addTask:(YLBaseTask *)task withMode:(YLBaseTaskAcceptMode)mode;
- (void)_removeTask:(YLBaseTask *)task;
- (void)_removeTaskNamed:(NSString *)name;

@end

@interface YLBaseTaskQueue () <_YLBaseTaskQueueShouldOverrideProtocol>

@property (nonatomic, strong, readonly) NSMutableArray *currentTaskQueue;
@property (nonatomic, copy) void(^queueCompleteCallback)(YLBaseTaskQueue *, YLTaskResult *);
@property (nonatomic, strong) dispatch_queue_t serialPerformQueue;

- (void)performSeriallyWithBlock:(dispatch_block_t)block;
- (void)pauseRunningTask:(YLBaseTask *)task;
- (void)resetTask:(YLBaseTask *)task;

@end

@implementation YLBaseTaskQueue
{
    @public NSMutableArray *_currentTaskQueue;
}
@synthesize actionWhenCovered = _actionWhenCovered;

- (instancetype)init
{
    if (self = [super init]) {
        NSString *queueLabel = [NSString stringWithFormat:@"com.lgl.task-queue.%@", NSStringFromClass(self.class)];
        _serialPerformQueue = dispatch_queue_create(queueLabel.UTF8String, DISPATCH_QUEUE_CONCURRENT);
        self.startImmediately = YES;
        self.actionWhenCovered = YLBaseTaskActionWhenCoveredNone;
    }
    return self;
}

- (instancetype)initWithCompletion:(void (^)(YLBaseTaskQueue *, YLTaskResult *))completion
{
    if (self = [self init]) {
        self.queueCompleteCallback = completion;
    }
    return self;
}

- (NSMutableArray *)currentTaskQueue
{
    if (!_currentTaskQueue) {
        _currentTaskQueue = [NSMutableArray arrayWithCapacity:3];
    }
    return _currentTaskQueue;
}

- (void)setActionWhenCovered:(YLBaseTaskActionWhenCovered)actionWhenCovered
{
    assert(self.state == YLBaseTaskStateInitial);
    if (actionWhenCovered == YLBaseTaskActionWhenCoveredStop) {
        NSLog(@"%@ 的 actionWhenCovered 属性不能设置为 'YLBaseTaskActionWhenCoveredStop'，将自动转为 'YLBaseTaskActionWhenCoveredPause' ！", self);
        _actionWhenCovered = YLBaseTaskActionWhenCoveredPause;
    }
    else {
        _actionWhenCovered = actionWhenCovered;
    }
}

- (void)performSeriallyWithBlock:(dispatch_block_t)block
{
    static void *taskQueueDispatchSpecific = &taskQueueDispatchSpecific;
    if (dispatch_get_specific(taskQueueDispatchSpecific) == taskQueueDispatchSpecific) {
        block();
        return;
    }
    if (!dispatch_queue_get_specific(self.serialPerformQueue, taskQueueDispatchSpecific)) {
        dispatch_queue_set_specific(_serialPerformQueue, taskQueueDispatchSpecific, taskQueueDispatchSpecific, NULL);
    }
    dispatch_barrier_sync(self.serialPerformQueue, block);
}

- (void)pauseRunningTask:(YLBaseTask *)task
{
    NSLog(@"Pause task: %@", task);
    if (task.state != YLBaseTaskStateRunning) {
        return;
    }
    YLBaseTaskActionWhenCovered coveredAction = task.actionWhenCovered;
    if (coveredAction == YLBaseTaskActionWhenCoveredPause) {
        task.state = YLBaseTaskStatePausing;
        [task _syncStopForPause:YES];
    }
    else if (coveredAction == YLBaseTaskActionWhenCoveredStop) {
        task.state = YLBaseTaskStatePausing;
        [task _syncStopForPause:NO];
    }
    else {
        NSLog(@"Pause: do nothing！%@", task);
//        task.state = YLBaseTaskStatePaused;
    }
}

- (void)resetTask:(YLBaseTask *)task
{
    task.state = YLBaseTaskStateInitial;
    task.completeCallback = nil;
    task.cancelCallback = nil;
}

#pragma mark - - startup
- (void)startWithData:(id)data
{
    YLTaskResult *result = data;
    if (![result isKindOfClass:YLTaskResult.class]) {
        result = [YLTaskResult resultWithData:data error:nil];
    }
    [self _syncStartForResume:NO withResult:result];
}

#pragma mark - - override
- (id)startForResume:(BOOL)resume withResult:(YLTaskResult *)result
{
    __block id startup = nil;
    [self performSeriallyWithBlock:^{
        startup = [self _startForResume:resume withResult:result];
    }];
    return startup;
}

- (void)stopForPause:(BOOL)pause
{
    [self performSeriallyWithBlock:^{
        [self _stopForPause:pause];
    }];
}

#pragma mark - - methods perform serially
- (void)addTask:(YLBaseTask *)task withMode:(YLBaseTaskAcceptMode)mode
{
    if (task) {
        [self performSeriallyWithBlock:^{
            [self _addTask:task withMode:mode];
        }];
    }
}

- (void)removeTask:(YLBaseTask *)task
{
    [self performSeriallyWithBlock:^{
        [self _removeTask:task];
    }];
}

- (void)removeTaskNamed:(NSString *)name
{
    [self performSeriallyWithBlock:^{
        [self _removeTaskNamed:name];
    }];
}

@end


#pragma mark - -  YLSerialTaskQueue

@interface YLSerialTaskQueue ()

@end

@implementation YLSerialTaskQueue

#pragma mark - - override
- (id)_startForResume:(BOOL)resume withResult:(YLTaskResult *)result
{
    [self _startWithResult:result andPauseTask:nil];
    return self;
}

- (void)_stopForPause:(BOOL)pause
{
    if (pause) {
        [self _pause];
    }
    else {
        [self _stop];
    }
}

- (void)_addTask:(YLBaseTask *)task withMode:(YLBaseTaskAcceptMode)mode
{
    NSLog(@"Will add task: %@", task);
    // reject模式下，如果已经有name相同的任务，则 task 将不会加入队列
    if (mode == YLBaseTaskAcceptModeReject) {
        for (YLBaseTask *tk in _currentTaskQueue) {
            if ([tk.name isEqualToString:task.name]) {
                NSLog(@"存在相同name的task：%@", tk);
                return;
            }
        }
    }
    // replace模式下，先将队列中相同name的任务取消掉
    if (mode == YLBaseTaskAcceptModeReplace) {
        [self _removeTaskNamed:task.name only:YES];
    }
    // accept模式下，允许队列中有相同name的任务

    // 如果有更高优先级的task加入队列，可能需要暂停当前正在运行的任务
    YLBaseTask *runningTask = nil;
    BOOL taskInserted = NO;
    for (NSInteger i=_currentTaskQueue.count-1; i>=0; i--) {
        YLBaseTask *tk = _currentTaskQueue[i];
        if (task.priority <= tk.priority) {
            taskInserted = YES;
            [self.currentTaskQueue insertObject:task atIndex:i+1];
            break;
        }
        if (tk.state == YLBaseTaskStateRunning) {
            runningTask = tk;
        }
    }
    if (!taskInserted) {
        [self.currentTaskQueue insertObject:task atIndex:0];
    }

    task.state = YLBaseTaskStatePending;
    // 有意将task和taskQueue之间形成循环引用，是为了防止在任务执行完成之前task或taskQueue的释放
    task.completeCallback = ^(YLBaseTask *task, YLTaskResult *result) {
        [self dequeueTask:task withResult:result];
    };
    task.cancelCallback = ^(YLBaseTask *task) {
        [self removeTask:task];
    };
    if (self.startImmediately) {
        [self _startWithResult:nil andPauseTask:runningTask];
    }
}

- (void)_removeTask:(YLBaseTask *)task
{
    [self resetTask:task];
    [task _syncStopForPause:NO];
    [_currentTaskQueue removeObject:task];
    [self _startWithResult:nil andPauseTask:nil];
}

- (void)_removeTaskNamed:(NSString *)name
{
    [self _removeTaskNamed:name only:NO];
}

#pragma mark - - private
- (void)_startWithResult:(YLTaskResult *)result andPauseTask:(YLBaseTask *)pauseTask
{
    // 因为 taskQueue 也是一个task，所以需要考虑该 task 是一个 taskQueue 的情况
    YLBaseTask *task = _currentTaskQueue.firstObject;
    if (!task) {
        NSLog(@"当前队列已执行完毕：%@", self);
        [self completeWithResult:result];
        if (self.queueCompleteCallback) {
            self.queueCompleteCallback(self, result);
        }
        return;
    }
    
    if (self.state == YLBaseTaskStatePausing || self.state == YLBaseTaskStatePaused) {
        NSLog(@"任务无法启动！%@ \n当前队列正处于暂停状态：%@", task, self);
        return;
    }
    
    if (task.state == YLBaseTaskStateRunning) {
        NSLog(@"任务无法启动！因为任务正在运行：%@", task);
        return;
    }
    
    // 当正处于 pausing 状态时，不需要强行启动task；
    // 当它由 pausing 变成 paused 时（如果这时处于队列的第一位）会自行启动
    if (task.state == YLBaseTaskStatePausing) {
        NSLog(@"任务无法启动！因为任务正在暂停，等暂停完毕会自行启动：%@", task);
        return;
    }
    
    BOOL startForResume = NO;
    if (task.state == YLBaseTaskStatePaused
        && task.actionWhenCovered == YLBaseTaskActionWhenCoveredPause) {
        startForResume = YES;
    }
    
    task.state = YLBaseTaskStateRunning;
    NSLog(@"Will start task: %@", task);
    if (![task _syncStartForResume:startForResume withResult:result]) {
        NSLog(@"Task Startup Cancelled: %@", task);
        [self _dequeueTask:task withResult:result];
        return;
    }
    
    if (pauseTask) {
        [self pauseRunningTask:pauseTask];
    }
}

- (void)_pause
{
    YLBaseTask *task = _currentTaskQueue.firstObject;
    [self pauseRunningTask:task];
    [self complete];
}

- (void)_stop
{
    for (YLBaseTask *task in _currentTaskQueue) {
        [self resetTask:task];
        [task _syncStopForPause:NO];
    }
    [_currentTaskQueue removeAllObjects];
    [self complete];
    if (self.queueCompleteCallback) {
        self.queueCompleteCallback(self, nil);
    }
}

- (void)dequeueTask:(YLBaseTask *)task withResult:(YLTaskResult *)result
{
    [self performSeriallyWithBlock:^{
        [self _dequeueTask:task withResult:result];
    }];
}

// 只有 [task complete] 的时候会调用该方法
- (void)_dequeueTask:(YLBaseTask *)task withResult:(YLTaskResult *)result
{
    // 此时当task处于 pausing 状态时，先将状态转换为 paused，然后尝试启动队列第一位的 task
    if (task.state == YLBaseTaskStatePausing) {
        task.state = YLBaseTaskStatePaused;
        [self _startWithResult:nil andPauseTask:nil];
    }
    else {
        [self resetTask:task];
        [self.currentTaskQueue removeObject:task];
        [self _startWithResult:result andPauseTask:nil];
    }
}

- (void)_removeTaskNamed:(NSString *)name only:(BOOL)only
{
    for (NSInteger i=_currentTaskQueue.count-1; i>=0; i--) {
        YLBaseTask *task = _currentTaskQueue[i];
        if ([task.name isEqualToString:name]) {
            [self resetTask:task];
            [task _syncStopForPause:NO];
            [_currentTaskQueue removeObjectAtIndex:i];
        }
    }
    if (!only) {
        [self _startWithResult:nil andPauseTask:nil];
    }
}

@end


#pragma mark - - YLParallelTaskQueue

@interface YLParallelTaskQueue ()

@end

@implementation YLParallelTaskQueue
{
    NSInteger taskCompleteCount;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.completeMode = YLParallelTaskQueueCompleteAll;
    }
    return self;
}

#pragma mark - - override
- (id)_startForResume:(BOOL)resume withResult:(YLTaskResult *)result
{
    [self _startWithResult:result];
    return self;
}

- (void)_stopForPause:(BOOL)pause
{
    if (pause) {
        [self _pause];
    }
    else {
        [self _stop];
    }
}

- (void)_addTask:(YLBaseTask *)task withMode:(YLBaseTaskAcceptMode)mode
{
    NSLog(@"Will add task: %@", task);
    // reject模式下，如果已经有name相同的任务，则 task 将不会加入队列
    if (mode == YLBaseTaskAcceptModeReject) {
        for (YLBaseTask *tk in _currentTaskQueue) {
            if ([tk.name isEqualToString:task.name]) {
                NSLog(@"存在相同name的task：%@", tk);
                return;
            }
        }
    }
    // replace模式下，先将队列中相同name的任务取消掉
    if (mode == YLBaseTaskAcceptModeReplace) {
        [self _removeTaskNamed:task.name only:YES];
    }
    // accept模式下，允许队列中有相同name的任务
    
    [self.currentTaskQueue addObject:task];
    task.taskResult = nil;
    task.state = YLBaseTaskStatePending;
    // 有意将task和taskQueue之间形成循环引用，是为了防止在任务执行完成之前task或taskQueue的释放
    task.completeCallback = ^(YLBaseTask *task, YLTaskResult *result) {
        [self dequeueTask:task withResult:result];
    };
    task.cancelCallback = ^(YLBaseTask *task) {
        [self removeTask:task];
    };
    if (self.startImmediately) {
        [self _startWithResult:nil];
    }
}

- (void)_removeTask:(YLBaseTask *)task
{
    [self resetTask:task];
    NSUInteger taskIndex = [_currentTaskQueue indexOfObject:task];
    if (taskIndex == NSNotFound) {
        return;
    }
    [_currentTaskQueue removeObjectAtIndex:taskIndex];
    [self _syncStopTaskIfNecessary:task];
    [self _handleQueueCompleteWithResult:nil];
}

- (void)_removeTaskNamed:(NSString *)name
{
    [self _removeTaskNamed:name only:NO];
}

- (void)completeWithResult:(YLTaskResult *)result
{
    taskCompleteCount = 0;
    [super completeWithResult:result];
    if (self.queueCompleteCallback) {
        self.queueCompleteCallback(self, result);
    }
}

#pragma mark - - private
- (void)_startWithResult:(YLTaskResult *)result
{
    if (!_currentTaskQueue.count) {
        [self completeWithResult:result];
        return;
    }
    if (self.state == YLBaseTaskStatePausing || self.state == YLBaseTaskStatePaused) {
        NSLog(@"任务无法启动！\n当前队列正处于暂停状态：%@", self);
        return;
    }
    
    for (__block NSInteger i=0; i<_currentTaskQueue.count; i++) {
        YLBaseTask *tk = _currentTaskQueue[i];
        [self _startTask:tk withResult:result cancelBlock:^{
            [self resetTask:tk];
            [self.currentTaskQueue removeObjectAtIndex:i];
            i--;
        }];
    }
    if (!_currentTaskQueue.count) {
        [self completeWithResult:result];
    }
}

- (void)_pause
{
    for (YLBaseTask *task in _currentTaskQueue) {
        [self pauseRunningTask:task];
    }
    [self complete];
}

- (void)_stop
{
    for (YLBaseTask *task in _currentTaskQueue) {
        [self resetTask:task];
        [self _syncStopTaskIfNecessary:task];
    }
    [_currentTaskQueue removeAllObjects];
    [self _handleQueueCompleteWithResult:nil];
}

- (void)dequeueTask:(YLBaseTask *)task withResult:(YLTaskResult *)result
{
    [self performSeriallyWithBlock:^{
        [self _dequeueTask:task withResult:result];
    }];
}

// 只有 [task complete] 的时候会调用该方法
- (void)_dequeueTask:(YLBaseTask *)task withResult:(YLTaskResult *)result
{
    if (task.state == YLBaseTaskStatePausing) {
        task.state = YLBaseTaskStatePaused;
        if (self.state == YLBaseTaskStatePausing || self.state == YLBaseTaskStatePaused) {
            NSLog(@"任务无法启动！%@ \n当前队列正处于暂停状态：%@", task, self);
            return;
        }
        [self _startTask:task withResult:nil cancelBlock:^{
            [self resetTask:task];
            [self.currentTaskQueue removeObject:task];
        }];
        if (!_currentTaskQueue.count) {
            [self completeWithResult:nil];
        }
        return;
    }
    
    [self resetTask:task];
    if (self.completeMode == YLParallelTaskQueueCompleteAny) {
        for (YLBaseTask *tk in _currentTaskQueue) {
            if (tk != task) {
                [self resetTask:tk];
                [tk _syncStopForPause:NO];
            }
        }
        [_currentTaskQueue removeAllObjects];
        [self _handleQueueCompleteWithResult:result];
        return;
    }
    
    task.taskResult = result ?: YLTaskResult.new;
    taskCompleteCount ++;
    [self _handleQueueCompleteWithResult:nil];
}

- (void)_syncStopTaskIfNecessary:(YLBaseTask *)task
{
    if (!task.taskResult) {
        [task _syncStopForPause:NO];
    }
    else {
        taskCompleteCount--;
    }
}

- (void)_startTask:(YLBaseTask *)task withResult:(YLTaskResult *)result cancelBlock:(void(^)(void))cancelBlock
{
    if (task.state == YLBaseTaskStateRunning) {
        NSLog(@"任务无法启动！因为任务正在运行：%@", task);
        return;
    }
    
    if (task.state == YLBaseTaskStatePausing) {
        NSLog(@"任务无法启动！因为任务正在暂停，等暂停完毕会自行启动：%@", task);
        return;
    }
    
    BOOL startForResume = NO;
    if (task.state == YLBaseTaskStatePaused
        && task.actionWhenCovered == YLBaseTaskActionWhenCoveredPause) {
        startForResume = YES;
    }
    
    task.state = YLBaseTaskStateRunning;
    NSLog(@"Will start task: %@", task);
    if (![task _syncStartForResume:startForResume withResult:result]) {
        NSLog(@"Task Startup Cancelled: %@", task);
        cancelBlock();
    }
}

- (void)_handleQueueCompleteWithResult:(YLTaskResult *)result
{
    if (_completeMode == YLParallelTaskQueueCompleteAny) {
        [self completeWithResult:result];
        return;
    }
    
    NSAssert(_completeMode == YLParallelTaskQueueCompleteAll, @"Undefined completeMode: %@", @(_completeMode));
    
    if (!_currentTaskQueue.count) {
        [self completeWithResult:nil];
        return;
    }
    assert(taskCompleteCount <= _currentTaskQueue.count);
    if (taskCompleteCount == _currentTaskQueue.count) {
        NSArray *arr = [_currentTaskQueue valueForKey:NSStringFromSelector(@selector(taskResult))];
        YLTaskResult *tkResult = [YLTaskResult resultWithData:arr error:nil];
        [_currentTaskQueue removeAllObjects];
        [self completeWithResult:tkResult];
    }
}

- (void)_removeTaskNamed:(NSString *)name only:(BOOL)only
{
    for (NSInteger i=_currentTaskQueue.count-1; i>=0; i--) {
        YLBaseTask *task = _currentTaskQueue[i];
        if ([task.name isEqualToString:name]) {
            [self resetTask:task];
            [self _syncStopTaskIfNecessary:task];
            [_currentTaskQueue removeObjectAtIndex:i];
        }
    }
    if (!only) {
        [self _handleQueueCompleteWithResult:nil];
    }
}

@end
