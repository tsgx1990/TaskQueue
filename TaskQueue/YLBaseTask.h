//
//  YLBaseTask.h
//  App
//
//  Created by guanglong on 2019/6/21.
//  Copyright © 2019 guanglong. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, YLBaseTaskPriority) {
    YLBaseTaskPriorityVeryHigh          = 1000,
    YLBaseTaskPriorityHigh              = 750,
    YLBaseTaskPriorityMedium            = 500,
    YLBaseTaskPriorityLow               = 250,
    YLBaseTaskPriorityVeryLow           = 0
};

typedef NS_ENUM(NSInteger, YLBaseTaskState) {
    YLBaseTaskStateInitial              = 0,
    YLBaseTaskStatePending,         // 已加入队列，尚未运行
    YLBaseTaskStateRunning,         // 运行中
    YLBaseTaskStatePausing,         // 正在暂停，尚未暂停
    YLBaseTaskStatePaused           // 已暂停
};

// 当被高优先级任务加入队列时，当前任务的行为
typedef NS_ENUM(NSInteger, YLBaseTaskActionWhenCovered) {
    YLBaseTaskActionWhenCoveredNone          = 0,    // 当前任务什么都不做
    YLBaseTaskActionWhenCoveredPause,                // 暂停当前任务
    YLBaseTaskActionWhenCoveredStop                  // 终止当前任务
};

@interface YLTaskResult : NSObject

- (instancetype)initWithData:(id)data error:(id)error;

+ (instancetype)resultWithData:(id)data error:(id)error;

@property (nonatomic, strong, readonly) id data;
@property (nonatomic, strong, readonly) id error;

@end

@interface YLBaseTask : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSInteger priority;

// 当高优先级的任务加入队列时，当前任务的行为。默认为 YLBaseTaskActionWhenCoveredPause，即执行暂停操作
@property (nonatomic, assign) YLBaseTaskActionWhenCovered actionWhenCovered;

// 当高优先级的任务加入队列时，当前任务可能会进入暂停状态
@property (nonatomic, readonly) YLBaseTaskState state;

// startForResume 和 stopForPause 方法执行时是否是在主线程；
// 如果task是在主线程创建的，则默认为YES，否则为NO
@property (nonatomic, assign) BOOL onMainThread;

// 只有任务加入队列之后，调用该方法才会起作用
- (void)cancel;

// 当前任务 stop 或者 pause 结束后必须调用
- (void)complete;
- (void)completeWithData:(id)data error:(id)error;
- (void)completeWithResult:(YLTaskResult *)result;

@end

@interface YLBaseTask (should_not_override)

@property (nonatomic, readonly) void(^completeCallback)(YLBaseTask *task, YLTaskResult *result);

@property (nonatomic, readonly) void(^cancelCallback)(YLBaseTask *task);

@end

@interface YLBaseTask (should_override)

// resume == YES，则表示任务将从暂停状态（而不是其他状态）切换到运行状态，即恢复性启动（热启动），而非冷启动；
// resume == NO，则表示冷启动
- (id)startForResume:(BOOL)resume withResult:(YLTaskResult *)result;

// pause == YES，则表示任务将从运行状态切换到暂停状态（而非直接终止任务），即暂停，而非终止；
// pause == NO，则表示直接终止
- (void)stopForPause:(BOOL)pause;

@end
