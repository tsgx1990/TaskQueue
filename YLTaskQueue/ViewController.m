//
//  ViewController.m
//  YLTaskQueue
//
//  Created by guanglong on 2019/6/24.
//  Copyright © 2019 guanglong. All rights reserved.
//

#import "ViewController.h"
#import "YLBlockTask.h"
#import "YLBaseTaskQueue.h"
#import "TaskStartup.h"

@interface ViewController ()

@property (nonatomic, strong) UIScrollView *scrollView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    UIEdgeInsets insets = UIEdgeInsetsMake(UIApplication.sharedApplication.statusBarFrame.size.height, 0, 0, 0);
    if (@available(iOS 11.0, *)) {
        insets = UIApplication.sharedApplication.keyWindow.safeAreaInsets;
    }
    self.scrollView = [[UIScrollView alloc] initWithFrame:UIEdgeInsetsInsetRect(self.view.bounds, insets)];
    self.scrollView.backgroundColor = UIColor.orangeColor;
    [self.view addSubview:self.scrollView];
    
    [self test];
}

- (void)appendText:(NSString *)text
{
    static UILabel *lastLabel = nil;
    
    UILabel *lbl = UILabel.new;
    lbl.backgroundColor = UIColor.whiteColor;
    lbl.numberOfLines = 0;
    lbl.textColor = UIColor.redColor;
    lbl.font = [UIFont systemFontOfSize:15];
    lbl.text = text;
    CGSize textSize = [lbl sizeThatFits:CGSizeMake(self.scrollView.frame.size.width, 0)];
    lbl.frame = CGRectMake(0, self.scrollView.contentSize.height, self.scrollView.frame.size.width, textSize.height);
    
    lastLabel = lbl;
    [self.scrollView addSubview:lbl];
    self.scrollView.contentSize = CGSizeMake(self.scrollView.frame.size.width, CGRectGetMaxY(lbl.frame) + 10);
    CGFloat offsetY = self.scrollView.contentSize.height - self.scrollView.frame.size.height;
    if (offsetY < 0) {
        offsetY = 0;
    }
    [self.scrollView setContentOffset:CGPointMake(0, offsetY) animated:YES];
}

- (void)test
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self _test];
    });
}

- (void)_test
{
    YLSerialTaskQueue *seriQ = [self testSerialQueue];
    YLParallelTaskQueue *paraQ = [self testParallelQueue];
    
    seriQ.priority = 10;
    seriQ.name = @"a";
    seriQ.actionWhenCovered = YLBaseTaskActionWhenCoveredPause;
    paraQ.priority = 20;
    paraQ.name = @"b";
    paraQ.actionWhenCovered = YLBaseTaskActionWhenCoveredPause;
    
    YLSerialTaskQueue *sq = [[YLSerialTaskQueue alloc] initWithCompletion:^(YLBaseTaskQueue *queue, YLTaskResult *result) {
        NSString *str = [[result.data description] stringByAppendingFormat:@"\n%@", queue.description];
        [self appendText:str];
    }];
//    sq.completeMode = YLParallelTaskQueueCompleteAny;
    sq.name = @"mix";
//    sq.startImmediately = NO;
    [sq addTask:seriQ withMode:YLBaseTaskAcceptModeReplace];
    [sq addTask:paraQ withMode:YLBaseTaskAcceptModeReplace];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        [seriQ startWithData:@(2)];
//        [paraQ startWithData:@(1)];
//        [sq startWithData:@(1)];
    });
}

- (YLSerialTaskQueue *)testSerialQueue
{
    YLSerialTaskQueue *serialQueue = [[YLSerialTaskQueue alloc] initWithCompletion:^(YLBaseTaskQueue *queue, YLTaskResult *result) {
        NSLog(@"SerialQueueCompleteWithresult: %@\n%@", result, queue);
        NSString *str = [[result.data description] stringByAppendingFormat:@"\n%@", queue.description];
        [self appendText:str];
    }];
    serialQueue.name = @"THIS-IS-A-SERIAL-QUEUE";
    serialQueue.startImmediately = NO;
    
    int i = 10000;
    while (i < 10005) {
        YLBaseTask *task0 = [self taskWithTag:i priority:YLBaseTaskPriorityMedium];
        task0.onMainThread = YES;
        [serialQueue addTask:task0 withMode:YLBaseTaskAcceptModeReject];
        i++;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            YLBaseTask *task1 = [self taskWithTag:i priority:YLBaseTaskPriorityMedium];
            task1.onMainThread = YES;
            [serialQueue addTask:task1 withMode:YLBaseTaskAcceptModeReject];
        });
        i++;
        
        YLBaseTask *task2 = [self taskWithTag:i priority:YLBaseTaskPriorityMedium];
        task2.onMainThread = YES;
        [serialQueue addTask:task2 withMode:YLBaseTaskAcceptModeReject];
        i++;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            YLBaseTask *task3 = [self taskWithTag:i priority:YLBaseTaskPriorityMedium];
            task3.onMainThread = YES;
            [serialQueue addTask:task3 withMode:YLBaseTaskAcceptModeReject];
        });
        i++;
    }
//    NSLog(@"expect value: %@", @(i * (i-1) / 2));
    
    return serialQueue;
}

- (void)performInBackgroundWithBlock:(void(^)(void))block
{
    [self performSelectorInBackground:@selector(_performBlock:) withObject:block];
}

- (void)_performBlock:(void(^)(void))block
{
    block();
}

- (YLParallelTaskQueue *)testParallelQueue
{
    YLParallelTaskQueue *parallelQueue = [[YLParallelTaskQueue alloc] initWithCompletion:^(YLBaseTaskQueue *queue, YLTaskResult *result) {
//        NSLog(@"ParallelQueueCompleteWithresult:%@ \ncount: %@\n%@", result.data, @([result.data count]), queue);
//        NSLog(@"ParallelQueueCompleteWithresult:%@ \n%@", result.data, queue);
        NSString *str = [[result.data description] stringByAppendingFormat:@"\n%@", queue.description];
        [self appendText:str];
    }];
    parallelQueue.name = @"THIS-IS-A-PARALLEL-QUEUE";
    parallelQueue.startImmediately = NO;
    parallelQueue.completeMode = YLParallelTaskQueueCompleteAll;
    
    int i = 20000;
    while (i < 20005) {
        YLBaseTask *task0 = [self taskWithTag:i priority:YLBaseTaskPriorityMedium];
        task0.onMainThread = YES;
        [parallelQueue addTask:task0 withMode:YLBaseTaskAcceptModeReject];
        i++;
        
        [self performInBackgroundWithBlock:^{
            YLBaseTask *task1 = [self taskWithTag:i priority:YLBaseTaskPriorityMedium];
            task1.onMainThread = YES;
            [parallelQueue addTask:task1 withMode:YLBaseTaskAcceptModeReject];
        }];
        i++;
        
        YLBaseTask *task2 = [self taskWithTag:i priority:YLBaseTaskPriorityMedium];
        task2.onMainThread = YES;
        [parallelQueue addTask:task2 withMode:YLBaseTaskAcceptModeReject];
        i++;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            YLBaseTask *task3 = [self taskWithTag:i priority:YLBaseTaskPriorityMedium];
            task3.onMainThread = YES;
            [parallelQueue addTask:task3 withMode:YLBaseTaskAcceptModeReject];
        });
        i++;
    }
//    NSLog(@"expect value: %@", @(i));
    return parallelQueue;
}

- (YLBaseTask *)taskWithTag:(int)tag priority:(int)priority
{
    NSString *taskTag = [NSString stringWithFormat:@"TASK(%@)", @(tag)];
    
    YLBlockTask *task = [YLBlockTask taskWithStart:^id(YLBlockTask *task, BOOL forResume, YLTaskResult *result) {
        
        NSLog(@"START [%@] forResume:[%@] result:[%@] \n%@", taskTag, @(forResume), result, task);
        
        id receiveData = result.data;
        if ([receiveData isKindOfClass:NSArray.class]) {
            receiveData = [[result.data lastObject] data];
        }
        NSString *rece = [NSString stringWithFormat:@" [%@] 收到数据：%@", taskTag, receiveData];
        [self appendText:rece];
        
        TaskStartup *startup = TaskStartup.new;
        startup.completeBlock = ^(TaskStartup *startup) {
            
            int sendData = [receiveData integerValue] + tag;
            NSString *send = [NSString stringWithFormat:@" [%@] 发送数据：%@", taskTag, @(sendData)];
            [self appendText:send];
            
            NSLog(@"[%@] COMPLETE!", taskTag);
            [task completeWithData:@(sendData) error:nil];
        };
        [startup start];
        NSLog(@"startup: %@\n%@", startup, task);
        return startup;
        
    } andStop:^(YLBlockTask *task, BOOL forPause, TaskStartup *startupObj) {
        NSLog(@"STOP [%@] forPause:[%@] startupObj:[%@] \n%@", taskTag, @(forPause), startupObj, task);
        [startupObj stop];
        [task complete];
    }];
    task.name = taskTag;
    task.priority = priority;
    
    return task;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    NSLog(@"1111");
}

@end
