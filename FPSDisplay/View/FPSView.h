//
//  FPSView.h
//  FPSDisplay
//
//  Created by kangya on 09/10/2018.
//  Copyright © 2018 kangya. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "TraceLogger.h"

#import <mach/mach.h>
#include <sys/sysctl.h>
#include <libkern/OSAtomic.h>
#include <execinfo.h>

@interface FPSView : UIView {
    CFRunLoopObserverRef _observer;
    double _lastRecordTime;
    NSMutableArray *_backtrace;
}

@end
