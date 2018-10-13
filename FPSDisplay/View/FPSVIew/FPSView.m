//
//  FPSView.m
//  FPSDisplay
//
//  Created by kangya on 09/10/2018.
//  Copyright © 2018 kangya. All rights reserved.
//

#import "FPSView.h"
#import "FPSView+TraceLogger.h"
#import "FPSView+Thread.h"
#import "FPSView+ThreadTableView.h"
#import "FPSView+MemoryUsage.h"
#import "FPSView+CPUUsage.h"

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

// threadCountLabel
@property (strong, nonatomic) UILabel* threadCountLabel;

// cpusageLabel
@property (strong, nonatomic) UILabel* cpusageLabel;

@property (strong, nonatomic) UITableView *threadTableView;

@end

@implementation FPSView

#pragma mark init
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
    [self initThreadCountText];
    [self initCpusageText];
    [self initTableView];
    
    [self startMonitor];
    
}


#pragma mark displaylink
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
    
    self.threadDataSource = [self allThreadInfomation];
    [self.threadTableView reloadData];
    
    [self getFPSCount:(float)count];
    
    [self getMemoryCount];
    
    [self getThreadCount];
    
    [self getCpusageCount];
    
}

#pragma mark fpsLabel
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

-(void)getFPSCount:(float)count {
    self.fpsLabel.text = [NSString stringWithFormat:@"fps: %@", [NSNumber numberWithFloat:count]];
}

#pragma mark fpsLabel
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

-(void)getMemoryCount {
    int64_t size = [self memoryUsage] / 1024 / 1024;
    self.memoryLabel.text = [NSString stringWithFormat:@"内存：%lldM", size];
}

#pragma mark threadCountText

-(UILabel *)threadCountLabel {
    if (!_threadCountLabel) {
        CGRect frame = CGRectMake(0, 100, 100, 50);
        _threadCountLabel = [[UILabel alloc]initWithFrame:frame];
        _threadCountLabel.textAlignment = NSTextAlignmentCenter;
        _threadCountLabel.textColor = [UIColor whiteColor];
        _threadCountLabel.font = [UIFont systemFontOfSize: 20];
    }
    return _threadCountLabel;
}

-(void)initThreadCountText {
    [self addSubview:self.threadCountLabel];
    [self addTapGuestureForThreadLabel];
}

-(void)addTapGuestureForThreadLabel {
    self.threadCountLabel.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapThreadLabel:)];
    [self.threadCountLabel addGestureRecognizer:tap];
}

-(void)tapThreadLabel:(UITapGestureRecognizer *)sender {
    if (self.threadTableView.superview) {
        [self.threadTableView removeFromSuperview];
    } else {
        [self addSubview: self.threadTableView];
    }
}

-(void)getThreadCount {
    self.threadCountLabel.text = [NSString stringWithFormat:@"线程：%lu", (unsigned long)self.threadDataSource.count];
}

#pragma mark cpusageLabel
-(UILabel *)cpusageLabel {
    if (!_cpusageLabel) {
        CGRect frame = CGRectMake(0, 150, 100, 50);
        _cpusageLabel = [[UILabel alloc]initWithFrame:frame];
        _cpusageLabel.textAlignment = NSTextAlignmentCenter;
        _cpusageLabel.textColor = [UIColor whiteColor];
        _cpusageLabel.font = [UIFont systemFontOfSize: 20];
    }
    return _cpusageLabel;
}

-(void)initCpusageText {
    [self addSubview:self.cpusageLabel];
}

-(void)getCpusageCount {
    self.cpusageLabel.text = [NSString stringWithFormat:@"cpu：%d", (int)round([self getCpusageOfAllThread])];
}


#pragma mark threadTableView

-(UITableView *)threadTableView {
    if (!_threadTableView) {
        CGRect frame = CGRectMake(100, 100, 300, 400);
        _threadTableView = [[UITableView alloc]initWithFrame:frame style:UITableViewStylePlain];
        _threadTableView.delegate = self;
        _threadTableView.dataSource = self;
    }

    return _threadTableView;
}

-(void)initTableView {
    [self addSubview:self.threadTableView];
}

@end
