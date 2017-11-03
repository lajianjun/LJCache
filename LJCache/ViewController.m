//
//  ViewController.m
//  LJCache
//
//  Created by blue on 2017/11/2.
//  Copyright © 2017年 LJ. All rights reserved.
//

#import "ViewController.h"
#import "LJMemoryCache.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    LJMemoryCache  *cache = [[LJMemoryCache alloc]init];
    [cache setObject:@"lalala" forKey:@"uuu"];
    [cache setObject:@"valar" forKey:@"aaa"];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"%@",[cache objectForKey:@"aaa"]);
        NSLog(@"%@",[cache objectForKey:@"uuu"]);
    });
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
