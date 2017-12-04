# LJCache

Data cache
======
example
------
// 0. initialization  <br>
```javascript
LJCache *cache = [[LJCache alloc] initWithName:@"mydb"];
```
// 1. Ordinary string <br>
```javascript
[cache setObject:@"blue" forKey:@"name"];
NSLog(@"name :%@",[cache objectForKey:@"name"]);
```
// 2. Cached model <br>
```javascript
[cache setObject:(id<NSCoding>)model forKey:@"user"];
```
// 3. Cache the array <br>
```javascript
NSMutableArray *array = @[].mutableCopy;
    for (NSInteger i = 0; i < 10; i ++) {
    [array addObject:model];
}
// 异步缓存    （Asynchronous cache）
[cache setObject:array forKey:@"user" withBlock:^{
    // 异步回调     （Asynchronous callback）
    NSLog(@"%@", [NSThread currentThread]);
    NSLog(@"array缓存完成....");
}];
// 延时读取     （Delayed reading）
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    // 异步读取      （Asynchronous read）
    [cache objectForKey:@"user" withBlock:^(NSString * _Nonnull key, id<NSCoding>  _Nonnull object) {
        // 异步回调     （Asynchronous callback）
        NSLog(@"%@", [NSThread currentThread]);
        NSLog(@"%@", object);
    }];
});
```
// 缓存实现，默认同时进行内存缓存与文件缓存  <br>
// Cache implementation, the default memory cache and file cache at the same time <br>
```javascript
- (void)setObject:(id<NSCoding>)object forKey:(NSString *)key {
    [_memoryCache setObject:object forKey:key];
    [_diskCache setObject:object forKey:key];
}
```
// 如果只想内存缓存，可以直接调用`memoryCache`对象  <br>
// If you just want memory caching, you can call `memoryCache` object directly  <br>
```javascript
LJCache *cache2 = [LJCache cacheWithName:@"mydb"];
[cache2.memoryCache setObject:@24 forKey:@"age"];
NSLog(@"age缓存在内存：%d", [cache2.memoryCache containsObjectForKey:@"age"]);
NSLog(@"age缓存在文件：%d", [cache2.diskCache containsObjectForKey:@"age"]);
```

