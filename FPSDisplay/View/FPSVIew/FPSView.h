//
//  FPSView.h
//  FPSDisplay
//
//  Created by kangya on 09/10/2018.
//  Copyright © 2018 kangya. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "TraceLogger.h"
#import "YYWeakProxy.h"
#import <mach/mach.h>


static NSString *threadCellId = @"threadCellId";

@interface FPSView : UIView {
    CFRunLoopObserverRef _observer;
    double _lastRecordTime;
    NSMutableArray *_backtrace;
}

@property (nonatomic, strong) NSArray *threadDataSource;

@end
