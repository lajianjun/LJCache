//
//  LJCache.m
//  LJCache
//
//  Created by blue on 2017/12/1.
//  Copyright © 2017年 LJ. All rights reserved.
//

#import "LJCache.h"
#import "LJMemoryCache.h"
#import "LJDiskCache.h"

@implementation LJCache

- (instancetype)init{
    @throw [NSException exceptionWithName:@"LJCache init error" reason:@"Please use the designated initializer and pass the 'name'. Use \"initWithName\" or \"initWithPath\" to create LJCache instance." userInfo:nil];
    return [self initWithName:@""];
}

- (nullable instancetype)initWithName:(NSString *)name{
    if (!name) return nil;
    NSString *cacheFolder = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *path = [cacheFolder stringByAppendingPathComponent:name];
    return [self initWithPath:path];
}

- (nullable instancetype)initWithPath:(NSString *)path{
    if (path.length == 0) return nil;
    LJDiskCache *diskCache = [[LJDiskCache alloc] initWithPath:path];
    if (!diskCache) return nil;
    NSString *name = [path lastPathComponent];
    LJMemoryCache *memoryCache = [[LJMemoryCache alloc] init];
    memoryCache.name = name;
    
    self = [super init];
    _name = name;
    _memoryCache = memoryCache;
    _diskCache = diskCache;
    return self;
}

+ (nullable instancetype)cacheWithName:(NSString *)name{
    return [[self alloc] initWithName:name];
}

+ (nullable instancetype)cacheWithPath:(NSString *)path{
    return [[self alloc] initWithPath:path];
}

- (BOOL)containsObjectForKey:(NSString *)key{
    return [_memoryCache containsObjectForKey:key] || [_diskCache containsObjectForKey:key];
}

- (void)containsObjectForKey:(NSString *)key withBlock:(nullable void(^)(NSString *key, BOOL contains))block{
    if (block) block(key,[self containsObjectForKey:key]);
}

- (nullable id<NSCoding>)objectForKey:(NSString *)key{
    if (!key) return nil;
    id object = [_memoryCache objectForKey:key];
    if (!object) {
        object = [_diskCache objectForKey:key];
    }
    return object;
}

- (void)objectForKey:(NSString *)key withBlock:(nullable void(^)(NSString *key, id<NSCoding> object))block{
    if (!block) return;
    id<NSCoding> object = [_memoryCache objectForKey:key];
    if (object) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            block(key, object);
        });
    }else{
        [_diskCache objectForKey:key withBlock:^(NSString * _Nonnull key, id<NSCoding>  _Nullable object) {
            if (object && [_memoryCache objectForKey:key]) { //Focus
                [_memoryCache setObject:object forKey:key];
            }
            block(key, object);
        }];
    }
}

- (void)setObject:(nullable id<NSCoding>)object forKey:(NSString *)key{
    [_memoryCache setObject:object forKey:key];
    [_diskCache setObject:object forKey:key];
}

- (void)setObject:(nullable id<NSCoding>)object forKey:(NSString *)key withBlock:(nullable void(^)(void))block{
    [_memoryCache setObject:object forKey:key];
    [_diskCache setObject:object forKey:key withBlock:block];
}

- (void)removeObjectForKey:(NSString *)key{
    [_memoryCache removeObjectForKey:key];
    [_diskCache removeObjectForKey:key];
}

- (void)removeObjectForKey:(NSString *)key withBlock:(nullable void(^)(NSString *key))block{
    [_memoryCache removeObjectForKey:key];
    [_diskCache removeObjectForKey:key withBlock:block];
}

- (void)removeAllObjects{
    [_memoryCache removeAllObjects];
    [_diskCache removeAllObjects];
}

- (void)removeAllObjectsWithBlock:(void(^)(void))block{
    [_memoryCache removeAllObjects];
    [_diskCache removeAllObjectsWithBlock:block];
}

- (void)removeAllObjectsWithProgressBlock:(nullable void(^)(int removedCount, int totalCount))progress
                                 endBlock:(nullable void(^)(BOOL error))end{
    [_memoryCache removeAllObjects];
    [_diskCache removeAllObjectsWithProgressBlock:progress endBlock:end];
}

@end
