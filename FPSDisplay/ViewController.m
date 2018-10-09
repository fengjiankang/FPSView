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

    [FPSViewManager show];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
