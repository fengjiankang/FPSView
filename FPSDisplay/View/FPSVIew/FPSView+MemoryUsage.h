//
//  FPSView+MemoryUsage.h
//  FPSDisplay
//
//  Created by kangya on 2018/10/13.
//  Copyright © 2018年 kangya. All rights reserved.
//

#import "FPSView.h"

NS_ASSUME_NONNULL_BEGIN

@interface FPSView (MemoryUsage)

- (int64_t)memoryUsage;

@end

NS_ASSUME_NONNULL_END
