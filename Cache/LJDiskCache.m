//
//  LJDiskCache.m
//  LJCache
//
//  Created by blue on 2017/11/3.
//  Copyright © 2017年 LJ. All rights reserved.
//

#import "LJDiskCache.h"

#define Lock()
#define Unlock()

/**
 NSMapTable is a dictionary-like collection
 NSMapTable 是类似于字典的集合，
*/
static NSMapTable *_globalInstances;
/**
 dispatch_semaphore is the semaphore, but it can also be used as a lock when the total number of semaphores is set to one. It performs better than pthread_mutex when there is no wait, but performance drops a lot once there is a wait. Its advantage over OSSpinLock is that it does not consume CPU resources while waiting. For disk caching, it is more appropriate.
 dispatch_semaphore 是信号量，但当信号总量设为 1 时也可以当作锁来。在没有等待情况出现时，它的性能比 pthread_mutex 还要高，但一旦有等待情况出现时，性能就会下降许多。相对于 OSSpinLock 来说，它的优势在于等待时不会消耗 CPU 资源。对磁盘缓存来说，它比较合适。
*/
static dispatch_semaphore_t _globalInstancesLock;

static void _LJDiskCacheInitGlobal () {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _globalInstancesLock = dispatch_semaphore_create(1);
        _globalInstances = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory capacity:0];
    });
}

static LJDiskCache *_LJDiskCacheGetGlobal (NSString *path){
    if (path.length == 0) return nil;
    _LJDiskCacheInitGlobal();
    dispatch_semaphore_wait(_globalInstancesLock, DISPATCH_TIME_FOREVER);
    id cache = [_globalInstances objectForKey:path];
    dispatch_semaphore_signal(_globalInstancesLock);
    return cache;
}

static void _LJDiskCacheSetGlobal (LJDiskCache *cache){
    if (cache.path.length == 0) return ;
    _LJDiskCacheInitGlobal();
    dispatch_semaphore_wait(_globalInstancesLock, DISPATCH_TIME_FOREVER);
    [_globalInstances setObject:cache forKey:cache.path];
    dispatch_semaphore_signal(_globalInstancesLock);
}

@implementation LJDiskCache {
    dispatch_semaphore_t _lock;
    dispatch_queue_t _queue;
}

- (void)_trimRecursively{
    __weak typeof(self) _self = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_autoTrimInterval * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        __strong typeof(_self) self = _self;
        if (!self) return ;
        [self _trimInBackground];
        [self _trimRecursively];
    });
}

- (void)_trimInBackground{
    dispatch_async(_queue, ^{
        
    });
}

#pragma mark - public

- (instancetype)init {
    @throw [NSException exceptionWithName:@"LJDiskCache init error" reason:@"LJDiskCache must be initialized with a path. Use 'initWithPath:' or 'initWithPath:inlineThreshold:' instead." userInfo:nil];
    return [self initWithPath:@"" inlineThreshold:0];
}
- (void)dealloc{
    
}
- (instancetype)initWithPath:(NSString *)path{
    return [self initWithPath:path inlineThreshold:20*1024]; //20kb
}

- (instancetype)initWithPath:(NSString *)path inlineThreshold:(NSUInteger)threshold{
    self = [super init];
    if (!self) return nil;
    
    LJDiskCache *globalCache = _LJDiskCacheGetGlobal(path);
    if (globalCache) return globalCache;
    
    _lock = dispatch_semaphore_create(1);
    _queue = dispatch_queue_create("com.blue.cache.disk", DISPATCH_QUEUE_CONCURRENT);
    _path = path;
    _inlineThreshold = threshold;
    _countLimit = NSUIntegerMax;
    _costLimit = NSUIntegerMax;
    _ageLimit = DBL_MAX;
    _freeDiskSpaceLimit = 0;
    _autoTrimInterval = 60;
    
    _LJDiskCacheSetGlobal(self);
    
    return self;
}
@end

