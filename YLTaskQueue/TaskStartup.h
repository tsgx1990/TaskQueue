//
//  TaskStartup.h
//  YLTaskQueue
//
//  Created by guanglong on 2019/6/24.
//  Copyright © 2019 guanglong. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TaskStartup : NSObject

@property (nonatomic, copy) void(^completeBlock)(TaskStartup *startup);

- (void)start;

- (void)stop;

@end
