//
//  FPSView+Thread.m
//  FPSDisplay
//
//  Created by kangya on 2018/10/13.
//  Copyright © 2018年 kangya. All rights reserved.
//

#import "FPSView+Thread.h"
#import "TraceLogger.h"

@implementation FPSView (Thread)

-(int)threadCount {
    return  [TraceLogger getThreadCount];
}

@end
