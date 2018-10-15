//
//  FPSView+TraceLogger.m
//  FPSDisplay
//
//  Created by kangya on 2018/10/13.
//  Copyright © 2018年 kangya. All rights reserved.
//

#import "FPSView+TraceLogger.h"
#include <sys/sysctl.h>
#include <libkern/OSAtomic.h>
#include <execinfo.h>

@implementation FPSView (TraceLogger)

static NSString * MonitorThreadName = @"MonitorThreadName";

static double _waitStartTime = 0;
static double StumbleCritical = 2.0;

// start monitor
-(void)startMonitor {
    // add main thread runloop observer
    [self addMainThreadObserver];
    // add  background monitor thread
    [self addTimerThreadAndObserver];
}

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
            
            self->_observer = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopAllActivities, YES, 0, &myRunLoopObserver, &context);
            
            if (self->_observer) {
                CFRunLoopRef cfRunloop = [loop getCFRunLoop];
                CFRunLoopAddObserver(cfRunloop, self->_observer, kCFRunLoopDefaultMode);
            }
        }
    });
}

void myRunLoopObserver(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    switch (activity) {
        case kCFRunLoopEntry:
            break;
        case kCFRunLoopBeforeTimers:
            break;
        case kCFRunLoopBeforeSources:
            break;
        case kCFRunLoopBeforeWaiting:
            _waitStartTime = 0;
            break;
        case kCFRunLoopAfterWaiting:
            _waitStartTime = [[NSDate date] timeIntervalSince1970];
            break;
        case kCFRunLoopExit:
            break;
        default:
            break;
    }
}

#pragma mark addTimerThreadAndObserver

// monitor thread
-(NSThread *)timerThread {
    static NSThread *_timerThread = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _timerThread = [[NSThread alloc]initWithTarget:self selector:@selector(networkRequestThreadEntryPoint:) object:nil];
        [_timerThread start];
    });
    return _timerThread;
}

// add the mach port to keep the loop stay and prevent the thread from exiting
-(void)networkRequestThreadEntryPoint:(id)__unused object {
    @autoreleasepool {
        [[NSThread currentThread] setName: MonitorThreadName];
        NSRunLoop *loop = [NSRunLoop currentRunLoop];
        [loop addPort:[NSMachPort port] forMode:NSRunLoopCommonModes];
        [loop run];
    }
}

// add timer thread
-(void)addTimerThreadAndObserver {
    NSThread *thread = [self timerThread];
    [self performSelector:@selector(addMonitorTimer) onThread:thread withObject:nil waitUntilDone:YES];
}

// add monitor timer
-(void)addMonitorTimer {
    // timer can retain the self, and self retain the runloop, runloop retain the timer, can result the circle retain, will optimize soon.
    // optimize method: 1: block, 2: NSProxy
    NSTimer *timer = [NSTimer timerWithTimeInterval:0.5 target:self selector:@selector(timerFired:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
}

// monitor timer call out
-(void)timerFired:(NSTimer *)timer {
    if (_waitStartTime < 1) return;
    double currentTime = [[NSDate date] timeIntervalSince1970];
    double timeDiff = currentTime - _waitStartTime;
    if (timeDiff > StumbleCritical) {
        if (_lastRecordTime - _waitStartTime < 0.001 && _lastRecordTime != 0){
            NSLog(@"last time no :%f %f",timeDiff, _waitStartTime);
            return;
        }
        [self logStack];
    }
}


// log stack stumble informatotion
-(void)logStack {
    NSLog(@"主线程发生了卡顿");
    
    void* callstack[128];
    int frames = backtrace(callstack, 128);
    char **strs = backtrace_symbols(callstack, frames);
    int i;
    _backtrace = [NSMutableArray arrayWithCapacity:frames];
    NSMutableString *traceStr = [NSMutableString string];
    for ( i = 0 ; i < frames ; i++ ){
        [_backtrace addObject:[NSString stringWithUTF8String:strs[i]]];
        [traceStr appendString:[NSString stringWithUTF8String:strs[i]]];
    }
    NSLog(@"traceStr is %@", traceStr);
    free(strs);
}

@end
