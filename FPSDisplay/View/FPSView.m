//
//  FPSView.m
//  FPSDisplay
//
//  Created by kangya on 09/10/2018.
//  Copyright © 2018 kangya. All rights reserved.
//

#import "FPSView.h"
#include <sys/sysctl.h>
#import <mach/mach.h>

@interface FPSView()

// dispalylink
@property (strong, nonatomic) CADisplayLink *link;

// calculate count, recored the tick count of one second
@property (assign, nonatomic) NSUInteger count;

// last time
@property (assign, nonatomic) CFTimeInterval lastTime;

// fpsLabel
@property (strong, nonatomic) UILabel* fpsLabel;

// memoryLabel
@property (strong, nonatomic) UILabel* memoryLabel;

CFRunLoopObserverRef _observer;

@end

@implementation FPSView

static double _waitStartTime;

-(instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

/**
 init setup
 */
-(void)setup {
    [self initCADisplaylink];
    [self initCountText];
    [self initMemoryText];
    
    [self startMonitor];
    
}

#pragma mark runloop observer
-(void)addMainThreadObserver {
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            NSRunLoop *loop = [NSRunLoop currentRunLoop];
            
            // 设置Runloop observer的运行环境
            CFRunLoopObserverContext context = {0, (__bridge void*)(self), NULL, NULL, NULL};
    
            //创建Run loop observer对象
            // 表示observer如何分配内存
            // runloop 要监听的事件
            // 该observer是在第一次进入run loop时执行还是每次进入run loop处理时均执行
            // 优先级别
            // 设置回调
            // observer's context
            
            _observer = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopAllActivities, YES, 0, &myRunLoopObserver, &context);
            
            if (_observer) {
                CFRunLoopRef cfRunloop = [loop getCFRunLoop];
                CFRunLoopAddObserver(cfRunloop, _observer, kCFRunLoopDefaultMode);
            }
        }
    });
}

void myRunLoopObserver(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    switch (activity) {
        case kCFRunLoopEntry:
            NSLog(@"runloop entry");
            break;
        case kCFRunLoopBeforeTimers:
            NSLog(@"run loop before timers");
            break;
        case kCFRunLoopBeforeSources:
            NSLog(@"run loop before sources");
            break;
        case kCFRunLoopBeforeWaiting:
            _waitStartTime = 0;
            NSLog(@"run loop before waiting");
            break;
        case kCFRunLoopAfterWaiting:
            _waitStartTime = [[NSDate date] timeIntervalSince1970];
            NSLog(@"run loop after waiting");
            break;
        case kCFRunLoopExit:
            NSLog(@"run loop exit");
            break;
        default:
            break;
    }
}

-(void)startMonitor {
    [self addMainThreadObserver];
}

-(void)initCADisplaylink {
    self.lastTime = 0;
    self.link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    [self.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

// tick
-(void)tick:(CADisplayLink *)link {
    if (self.lastTime == 0) {
        self.lastTime = link.timestamp;
        return;
    }
    self.count += 1;
    NSTimeInterval delta = link.timestamp - self.lastTime;
    
    if (delta >= 1) {
        self.lastTime = link.timestamp;
        float fps = round(self.count / delta);
        self.count = 0;
        [self updateDisplayLabelText:fps];
    }
}

-(void)initCountText {
    [self addSubview:self.fpsLabel];
}

// update fps text
-(void)updateDisplayLabelText:(float)count {
    self.fpsLabel.text = [NSString stringWithFormat:@"fps: %@", [NSNumber numberWithFloat:count]];
    
    [self calculateMemorySize];
}

-(UILabel *)fpsLabel {
    if (!_fpsLabel) {
        CGRect frame = CGRectMake(0, 0, 100, 50);
        _fpsLabel = [[UILabel alloc]initWithFrame:frame];
        _fpsLabel.textAlignment = NSTextAlignmentCenter;
        _fpsLabel.textColor = [UIColor whiteColor];
        _fpsLabel.font = [UIFont systemFontOfSize: 20];
    }
    return _fpsLabel;
}

-(UILabel *)memoryLabel {
    if (!_memoryLabel) {
        CGRect frame = CGRectMake(0, 50, 100, 50);
        _memoryLabel = [[UILabel alloc]initWithFrame:frame];
        _memoryLabel = [[UILabel alloc]initWithFrame:frame];
        _memoryLabel.textAlignment = NSTextAlignmentCenter;
        _memoryLabel.textColor = [UIColor whiteColor];
        _memoryLabel.font = [UIFont systemFontOfSize: 14];
    }
    return _memoryLabel;
}

-(void)initMemoryText {
    [self addSubview:self.memoryLabel];
}

-(void)calculateMemorySize {
    int64_t size = [self memoryUsage] / 1024 / 1024;
    self.memoryLabel.text = [NSString stringWithFormat:@"内存：%lldM", size];
    NSLog(@"size is %lld", size);
}

- (int64_t)memoryUsage {
    int64_t memoryUsageInByte = 0;
    task_vm_info_data_t vmInfo;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t kernelReturn = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t) &vmInfo, &count);
    if(kernelReturn == KERN_SUCCESS) {
        memoryUsageInByte = (int64_t) vmInfo.phys_footprint;
        NSLog(@"Memory in use (in bytes): %lld", memoryUsageInByte);
    } else {
        NSLog(@"Error with task_info(): %s", mach_error_string(kernelReturn));
    }
    return memoryUsageInByte;
}

@end
