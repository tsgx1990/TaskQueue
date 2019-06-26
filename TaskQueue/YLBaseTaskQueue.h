//
//  YLBaseTaskQueue.h
//  App
//
//  Created by guanglong on 2019/6/21.
//  Copyright © 2019 guanglong. All rights reserved.
//

#import "YLBaseTask.h"

typedef NS_ENUM(NSInteger, YLBaseTaskAcceptMode) {
    YLBaseTaskAcceptModeReject           = 0,   // 如果队列中已经存在name相同的任务，则无法添加到任务队列
    YLBaseTaskAcceptModeAccept           = 1,   // 可以直接添加到任务队列，无论任务队列中是否存在name相同的任务
    YLBaseTaskAcceptModeReplace          = 2    // 如果队列中已经存在name相同的任务，则将这些任务全部移除后再添加
};


//1，任务队列本身也是一个任务
//2，对于串行队列，高优先级的任务可以向低优先级任务传递数据
//3，线程安全

@interface YLBaseTaskQueue : YLBaseTask

- (instancetype)initWithCompletion:(void(^)(YLBaseTaskQueue *queue, YLTaskResult *result))completion;

// 当有任务加入队列时，是否立即启动队列；NO表示不立即启动。默认为YES
@property (nonatomic, assign) BOOL startImmediately;

- (void)startWithData:(id)data;

- (void)addTask:(YLBaseTask *)task withMode:(YLBaseTaskAcceptMode)mode;

- (void)removeTask:(YLBaseTask *)task;

- (void)removeTaskNamed:(NSString *)name;

@end


@interface YLSerialTaskQueue : YLBaseTaskQueue

@end


typedef NS_ENUM(NSInteger, YLParallelTaskQueueCompleteMode) {
    YLParallelTaskQueueCompleteAll          = 0,    // 任务全部结束，则队列结束
    YLParallelTaskQueueCompleteAny,                 // 只要有一个任务结束，则队列结束
};

@interface YLParallelTaskQueue : YLBaseTaskQueue

@property (nonatomic, assign) YLParallelTaskQueueCompleteMode completeMode;

@end
