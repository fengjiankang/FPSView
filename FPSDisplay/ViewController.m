//
//  ViewController.m
//  FPSDisplay
//
//  Created by kangya on 09/10/2018.
//  Copyright © 2018 kangya. All rights reserved.
//

#import "ViewController.h"
#import "FPSViewManager.h"
#import "AppDelegate.h"

@interface ViewController ()

@property (strong, nonatomic) UIWindow *fpsWindow;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
//    [self makeCFRunloop];
    
    [FPSViewManager show];
}

-(void)makeCFRunloop {
    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(CFAllocatorGetDefault(), kCFRunLoopAllActivities, YES, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        switch (activity) {
            case kCFRunLoopEntry:
                NSLog(@"Runloop 进入");
                break;
            case kCFRunLoopBeforeTimers:
                NSLog(@"Runloop 要处理timers了");
                break;
            case kCFRunLoopBeforeSources:
                NSLog(@"Runloop 要处理sources了");
                break;
            case kCFRunLoopBeforeWaiting:
                NSLog(@"Runloop 要休息了");
                break;
            case kCFRunLoopAfterWaiting:
                NSLog(@"Runloop 醒来了");
                break;
            case kCFRunLoopExit:
                NSLog(@"Runloop 退出了");
                break;
            default:
                break;
        }
    });
    
    CFRunLoopAddObserver(CFRunLoopGetCurrent(), observer, kCFRunLoopDefaultMode);
    
    /*
     CF的内存管理（Core Foundation）
     凡是带有Create、Copy、Retain等字眼的函数，创建出来的对象，都需要在最后做一次release
     GCD本来在iOS6.0之前也是需要我们释放的，6.0之后GCD已经纳入到了ARC中，所以我们不需要管了
     */
    CFRelease(observer);
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
