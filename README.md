# LJCache

Data cache
======
example
------
// 0. initialization  <br>
LJCache *cache = [[LJCache alloc] initWithName:@"mydb"]; <br>

// 1. Ordinary string <br>
[cache setObject:@"blue" forKey:@"name"]; <br>
NSLog(@"name :%@",[cache objectForKey:@"name"]); <br>

// 2. Cached model <br>
[cache setObject:(id<NSCoding>)model forKey:@"user"]; <br>

// 3. Cache the array <br>
NSMutableArray *array = @[].mutableCopy; <br>
    *for (NSInteger i = 0; i < 10; i ++) { <br>
    *[array addObject:model]; <br>
} <br>
// 异步缓存    （Asynchronous cache）<br>
[cache setObject:array forKey:@"user" withBlock:^{ <br>
    *// 异步回调     （Asynchronous callback） <br>
    *NSLog(@"%@", [NSThread currentThread]); <br>
    *NSLog(@"array缓存完成...."); <br>
}];<br>
// 延时读取     （Delayed reading）<br>
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ <br>
    *// 异步读取      （Asynchronous read）<br>
    *[cache objectForKey:@"user" withBlock:^(NSString * _Nonnull key, id<NSCoding>  _Nonnull object) { <br>
        *// 异步回调     （Asynchronous callback） <br>
        *NSLog(@"%@", [NSThread currentThread]); <br>
        *NSLog(@"%@", object); <br>
    *}]; <br>
}); <br>

// 缓存实现，默认同时进行内存缓存与文件缓存  <br>
// Cache implementation, the default memory cache and file cache at the same time <br>
- (void)setObject:(id<NSCoding>)object forKey:(NSString *)key { <br>
    *[_memoryCache setObject:object forKey:key];  <br>
    *[_diskCache setObject:object forKey:key];  <br>
} <br>

// 如果只想内存缓存，可以直接调用`memoryCache`对象  <br>
// If you just want memory caching, you can call `memoryCache` object directly  <br>
LJCache *cache2 = [LJCache cacheWithName:@"mydb"]; <br>
[cache2.memoryCache setObject:@24 forKey:@"age"]; <br>
NSLog(@"age缓存在内存：%d", [cache2.memoryCache containsObjectForKey:@"age"]); <br>
NSLog(@"age缓存在文件：%d", [cache2.diskCache containsObjectForKey:@"age"]); <br>

