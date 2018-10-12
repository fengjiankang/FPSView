//
//  FPSViewManager.m
//  FPSDisplay
//
//  Created by kangya on 09/10/2018.
//  Copyright © 2018 kangya. All rights reserved.
//

#import "FPSViewManager.h"
#import "FPSView.h"

@interface FPSViewManager()

@property (strong, nonatomic) UIWindow *fpsWindow;

@property (strong, nonatomic) FPSView *fpsView;

@end

@implementation FPSViewManager

+ (instancetype)shareInstance {
    static FPSViewManager *app;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        app = [[FPSViewManager alloc] init];
    });
    return app;
}

-(UIWindow *)fpsWindow {
    if (!_fpsWindow) {
        UIWindow * fpsWindow = [[UIWindow alloc]initWithFrame:CGRectMake(0, 0, 100, 100)];
        _fpsWindow = fpsWindow;
        fpsWindow.backgroundColor = [UIColor yellowColor];
        fpsWindow.rootViewController = [[UIViewController alloc]init];
        fpsWindow.windowLevel = 1000.0;
        fpsWindow.hidden = NO;
        [[UIApplication sharedApplication].keyWindow addSubview:fpsWindow];
        [_fpsWindow addSubview:self.fpsView];
        [self addPanGuesture];
    }
    return _fpsWindow;
}

-(void)addPanGuesture {
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(panWindow:)];
    [_fpsWindow addGestureRecognizer:pan];
}

-(void)panWindow:(UIPanGestureRecognizer *)sender {
    CGPoint point = [sender translationInView:_fpsWindow];
    sender.view.transform = CGAffineTransformTranslate(sender.view.transform, point.x, point.y);
    [sender setTranslation:CGPointZero inView:sender.view];
}

-(FPSView *)fpsView {
    if (!_fpsView) {
        _fpsView = [[FPSView alloc]initWithFrame:CGRectMake(0, 0, 100, 150)];
        _fpsView.backgroundColor = [UIColor blackColor];
    }
    return _fpsView;
}

+(void)show {
    [[UIApplication sharedApplication].keyWindow addSubview: [FPSViewManager shareInstance].fpsWindow];
}

@end
