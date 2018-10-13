//
//  FPSView+CPUUsage.h
//  FPSDisplay
//
//  Created by kangya on 2018/10/13.
//  Copyright © 2018年 kangya. All rights reserved.
//

#import "FPSView.h"

NS_ASSUME_NONNULL_BEGIN

@interface FPSView (CPUUsage)

// get the cpusage of all threads;
-(double)getCpusageOfAllThread;

// get the cpusage main thread
-(double)getCpusageOfMainThread;


@end

NS_ASSUME_NONNULL_END
