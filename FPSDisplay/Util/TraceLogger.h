//
//  TraceLogger.h
//  FPSDisplay
//
//  Created by kangya on 11/10/2018.
//  Copyright © 2018 kangya. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TraceLogger : NSObject

// get thread count
+(int)getThreadCount;

// get the traceInfo of the thread
+(NSString *)czb_backtraceOfNSThread:(NSThread *)thread;

// get the traceInfo of all threads
+(NSString *)czb_backtraceOfAllThread:(NSThread *)thread;

@end
