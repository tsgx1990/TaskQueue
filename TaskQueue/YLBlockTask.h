//
//  YLBlockTask.h
//  YLTaskQueue
//
//  Created by guanglong on 2019/6/24.
//  Copyright © 2019 guanglong. All rights reserved.
//

#import "YLBaseTask.h"

@class YLBlockTask;

typedef id(^YLStartTaskBlock)(YLBlockTask *task, BOOL forResume, YLTaskResult *result);
typedef void(^YLStopTaskBlock)(YLBlockTask *task, BOOL forPause, id startupObj);


@interface YLBlockTask : YLBaseTask

- (instancetype)initWithStart:(YLStartTaskBlock)start andStop:(YLStopTaskBlock)stop;

+ (instancetype)taskWithStart:(YLStartTaskBlock)start andStop:(YLStopTaskBlock)stop;

@end
