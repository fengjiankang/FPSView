//
//  FPSView.m
//  FPSDisplay
//
//  Created by kangya on 09/10/2018.
//  Copyright © 2018 kangya. All rights reserved.
//

#import "FPSView.h"

@interface FPSView()

// dispalylink
@property (strong, nonatomic) CADisplayLink *link;

// calculate count, recored the tick count of one second
@property (assign, nonatomic) NSUInteger count;

// last time
@property (assign, nonatomic) CFTimeInterval lastTime;

@property (strong, nonatomic) UILabel* fpsLabel;

@end

@implementation FPSView

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
        float fps = self.count / delta;
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
}

-(UILabel *)fpsLabel {
    if (!_fpsLabel) {
        _fpsLabel = [[UILabel alloc]initWithFrame:self.frame];
        _fpsLabel.textAlignment = NSTextAlignmentCenter;
        _fpsLabel.textColor = [UIColor whiteColor];
        _fpsLabel.font = [UIFont systemFontOfSize: 20];
    }
    return _fpsLabel;
}

@end
