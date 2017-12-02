//
//  ViewController.m
//  LJCache
//
//  Created by blue on 2017/11/2.
//  Copyright © 2017年 LJ. All rights reserved.
//

#import "ViewController.h"
#import "LJCache.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    // 0.初始化LJCache
    LJCache *cache = [[LJCache alloc] initWithName:@"mydb"];
    // 1.普通字符串
    [cache setObject:@"blue" forKey:@"name"];
    NSLog(@"name :%@",[cache objectForKey:@"name"]);
    
    // 2.缓存模型

    // 3.缓存数组
    NSMutableArray *array = @[@{@"icon":@"room_facebook",@"title":NSLocalizedString(@"facebook", @""),@"idx"
                                :@(1)},
                              @{@"icon":@"room_twitter",@"title":NSLocalizedString(@"twitter", @""),@"idx":@(2)},
                              @{@"icon":@"room_ins",@"title":NSLocalizedString(@"instagram", @""),@"idx":@(3)},
                              @{@"icon":@"room_whatsapp",@"title":NSLocalizedString(@"whatsapp", @""),@"idx":@(4)},
                              @{@"icon":@"room_copylink",@"title":NSLocalizedString(@"link", @""),@"idx":@(5)}].mutableCopy;
    // 异步缓存
    [cache setObject:array forKey:@"share" withBlock:^{
        // 异步回调
        NSLog(@"%@", [NSThread currentThread]);
        NSLog(@"array缓存完成....");
    }];
    // 延时读取
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 异步读取
        [cache objectForKey:@"share" withBlock:^(NSString * _Nonnull key, id<NSCoding>  _Nonnull object) {
            // 异步回调
            NSLog(@"%@", [NSThread currentThread]);
            NSLog(@"%@", object);
        }];
    });
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
