//
//  LJMemoryCache.m
//  LJCache
//
//  Created by blue on 2017/11/2.
//  Copyright © 2017年 LJ. All rights reserved.
//

#import "LJMemoryCache.h"
#import "pthread.h"
#import <UIKit/UIKit.h>

static inline dispatch_queue_t LJMemoryCacheGetReleaseQueue() {
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
}

@interface _LJLinkedMapNode :NSObject{
    @package
    __unsafe_unretained _LJLinkedMapNode *_prev;
    __unsafe_unretained _LJLinkedMapNode *_next;
    id _key;
    id _value;
    NSUInteger _cost;
    NSTimeInterval _time;
}
@end

@implementation _LJLinkedMapNode
@end


@interface _LJLinkedMap :NSObject{
    @package
    CFMutableDictionaryRef _dic;
    NSUInteger _totalCost;
    NSUInteger _totalCount;
    _LJLinkedMapNode *_head;
    _LJLinkedMapNode *_tail;
    BOOL _releaseOnMainThread;
    BOOL _releaseAsynchronously;
}

- (void)insertNodeAtHead:(_LJLinkedMapNode *)node;
- (void)bringNodeToHead:(_LJLinkedMapNode *)node;
- (void)removeNode:(_LJLinkedMapNode *)node;
- (_LJLinkedMapNode *)removeTailNode;
- (void)removeAll;

@end

@implementation _LJLinkedMap

- (instancetype)init{
    self = [super init];
    _dic = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);// 0 - 没有提示，词典的实际容量只受到地址空间和可用内存限制
    _releaseOnMainThread = NO;
    _releaseAsynchronously = YES;
    return self;
}
- (void)dealloc{
    CFRelease(_dic);
}

- (void)insertNodeAtHead:(_LJLinkedMapNode *)node{
    CFDictionarySetValue(_dic, (__bridge const void *)(node->_key), CFBridgingRetain(node));//两种桥梁方式
    _totalCost += node->_cost;
    _totalCount++;
    if (_head) {
        node->_next = _head;
        _head->_prev = node;
        _head = node;
    }else{
        _head = _tail = node;
    }
}

- (void)bringNodeToHead:(_LJLinkedMapNode *)node{
    if (_head == node) return;
    
    //*先从列表中挖出来--------------------
    if (_tail == node) {
        _tail = node->_prev;
        _tail->_next = nil;
    }else{
        node->_prev->_next = node->_next;
        node->_next->_prev = node->_prev;
    }
    //-----------------------------------
    
    node->_next = _head;
    _head->_prev = node;
    node->_prev = nil;
    _head = node;
}
- (void)removeNode:(_LJLinkedMapNode *)node{
    CFDictionaryRemoveValue(_dic, (__bridge const void *)(node->_key));
    _totalCost -= node->_cost;
    _totalCount--;
    if (node->_prev) node->_prev->_next = node->_next;
    if (node->_next) node->_next->_prev = node->_prev;
    if (_head == node) _head = node->_next;
    if (_tail == node) _tail = node->_prev;
}

- (_LJLinkedMapNode *)removeTailNode{
    if (!_tail) return nil;
    
    _LJLinkedMapNode *tail = _tail;
    CFDictionaryRemoveValue(_dic, (__bridge const void *)(_tail->_key));
    _totalCost -= tail->_cost;
    _totalCount--;
    if (_tail == _head) {
        _tail = _head = nil;
    }else{
        _tail = _tail->_prev;
        _tail->_next = nil;
    }
    return tail;
}

- (void)removeAll{
    _totalCount = 0;
    _totalCost = 0;
    _head = nil;
    _tail = nil;
    if (CFDictionaryGetCount(_dic)>0) {
        CFMutableDictionaryRef holder = _dic;
        _dic = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        
        if (_releaseAsynchronously) {
            dispatch_queue_t queue = _releaseOnMainThread? dispatch_get_main_queue():LJMemoryCacheGetReleaseQueue();
            dispatch_async(queue, ^{
                CFRelease(holder);
            });
        }else if (_releaseOnMainThread && !pthread_main_np()) { /*pthread_main_np() -> returns non-zero if the current thread is the main thread */
            dispatch_async(dispatch_get_main_queue(), ^{
                CFRelease(holder);
            });
        }else{
            CFRelease(holder);
        }
    }
}

@end

@implementation LJMemoryCache {
    pthread_mutex_t _lock;
    _LJLinkedMap *_lru;
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
        [self _trimToCount:self->_countLimit];
        [self _trimToCost:self->_costLimit];
        [self _trimToAge:self->_ageLimit];
    });
}

#pragma mark - public

- (instancetype)init{
    self = super.init;
    pthread_mutex_init(&_lock, NULL);
    _lru = [_LJLinkedMap new];
    _queue = dispatch_queue_create("com.blue.cache.memory", DISPATCH_QUEUE_SERIAL);
    
    _costLimit = NSUIntegerMax;
    _countLimit = NSUIntegerMax;
    _ageLimit = DBL_MAX;
    _autoTrimInterval = 5.0;
    _shouldRemoveAllObjectsOnMemoryWarning = YES;
    _shouldRemoveAllObjectsWhenEnteringBackground = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_appDidReceiveMemoryWarningNotification) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_appDidEnterBackgroundNotification) name:UIApplicationDidEnterBackgroundNotification object:nil];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [_lru removeAll];
    pthread_mutex_destroy(&_lock);
}

- (void)_appDidReceiveMemoryWarningNotification {
    if (self.didReceiveMemoryWarningBlock) {
        self.didReceiveMemoryWarningBlock(self);
    }
    if (self.shouldRemoveAllObjectsOnMemoryWarning) {
        [self removeAllObjects];
    }
}

- (void)_appDidEnterBackgroundNotification {
    if (self.didEnterBackgroundBlock) {
        self.didEnterBackgroundBlock(self);
    }
    if (self.shouldRemoveAllObjectsWhenEnteringBackground) {
        [self removeAllObjects];
    }
}
- (NSUInteger)totalCost{
    pthread_mutex_lock(&_lock);
    NSUInteger cost = _lru->_totalCost;
    pthread_mutex_unlock(&_lock);
    return cost;
}

- (NSUInteger)totalCount{
    pthread_mutex_lock(&_lock);
    NSUInteger count = _lru->_totalCount;
    pthread_mutex_unlock(&_lock);
    return count;
}

- (void)setReleaseOnMainThread:(BOOL)releaseOnMainThread{
    pthread_mutex_lock(&_lock);
    _lru->_releaseOnMainThread = releaseOnMainThread;
    pthread_mutex_unlock(&_lock);
}
- (BOOL)releaseOnMainThread{
    pthread_mutex_lock(&_lock);
    BOOL onMainThread = _lru->_releaseOnMainThread;
    pthread_mutex_unlock(&_lock);
    return onMainThread;
}

- (void)setReleaseAsynchronously:(BOOL)releaseAsynchronously{
    pthread_mutex_lock(&_lock);
    _lru->_releaseAsynchronously = releaseAsynchronously;
    pthread_mutex_unlock(&_lock);
}
- (BOOL)releaseAsynchronously{
    pthread_mutex_lock(&_lock);
    BOOL asynchronously = _lru->_releaseAsynchronously;
    pthread_mutex_unlock(&_lock);
    return asynchronously;
}

- (BOOL)containsObjectForKey:(id)key{
    if (!key) return NO;
    pthread_mutex_lock(&_lock);
    BOOL contains = CFDictionaryContainsKey(_lru->_dic, (__bridge const void*)(key));
    pthread_mutex_unlock(&_lock);
    return contains;
}

- (nullable id)objectForKey:(id)key{
    if (!key) return nil;
    pthread_mutex_lock(&_lock);
    _LJLinkedMapNode *node = CFDictionaryGetValue(_lru->_dic, (__bridge const void*)(key));
    if (node) {
        node->_time = CACurrentMediaTime();
        [_lru bringNodeToHead:node];
    }
    pthread_mutex_unlock(&_lock);
    return node? node->_value:nil;
}

- (void)setObject:(nullable id)object forKey:(id)key{
    [self setObject:object forKey:key withCost:0];
}

- (void)setObject:(nullable id)object forKey:(id)key withCost:(NSUInteger)cost{
    if (!key) return;
    if (!object) {
        [self removeObjectForKey:key];
        return;
    }
    
    pthread_mutex_lock(&_lock);
    _LJLinkedMapNode *node = CFDictionaryGetValue(_lru->_dic, (__bridge const void*)(key));
    NSTimeInterval now = CACurrentMediaTime();
    if (node) {
        _lru->_totalCost -= node->_cost;
        _lru->_totalCost += cost;
        node->_time = now;
        node->_cost = cost;
        node->_value = object;
        [_lru bringNodeToHead:node];
    }else{
        node = [_LJLinkedMapNode new];
        node->_time = now;
        node->_cost = cost;
        node->_key = key;
        node->_value = object;
        [_lru insertNodeAtHead:node];
    }
    if (_lru->_totalCost > _costLimit) {
        dispatch_async(_queue, ^{
            [self trimToCost:_costLimit];
        });
    }
    if (_lru->_totalCount > _countLimit) {
        _LJLinkedMapNode *node = [_lru removeTailNode];
        if (_lru->_releaseAsynchronously) {
            dispatch_queue_t queue = _lru->_releaseOnMainThread? dispatch_get_main_queue():LJMemoryCacheGetReleaseQueue();
            dispatch_async(queue, ^{
                [node class]; //hold and release in queue
            });
        } else if (_lru->_releaseOnMainThread && !pthread_main_np()) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [node class]; //hold and release in queue
            });
        }
    }
    
    pthread_mutex_unlock(&_lock);
}

- (void)removeObjectForKey:(id)key{
    if (!key) return;
    
    pthread_mutex_lock(&_lock);
    _LJLinkedMapNode *node = CFDictionaryGetValue(_lru->_dic, (__bridge const void*)(key));
    if (node) {
        [_lru removeNode:node];
        if (_lru->_releaseAsynchronously) {
            dispatch_queue_t queue = _lru->_releaseOnMainThread? dispatch_get_main_queue():LJMemoryCacheGetReleaseQueue();
            dispatch_async(queue, ^{
                [node class];
            });
        }else if (_lru->_releaseOnMainThread && !pthread_main_np()){
            dispatch_async(dispatch_get_main_queue(), ^{
                [node class];
            });
        }
    }
    pthread_mutex_unlock(&_lock);
}

- (void)removeAllObjects{
    pthread_mutex_lock(&_lock);
    [_lru removeAll];
    pthread_mutex_unlock(&_lock);
}


#pragma mark - Trim
- (void)trimToCount:(NSUInteger)count{
    if (count==0) {
        [self removeAllObjects];
        return;
    }
    [self _trimToCount:count];
}

- (void)trimToCost:(NSUInteger)cost{
    [self _trimToCost:cost];
}

- (void)trimToAge:(NSTimeInterval)age{
    [self _trimToAge:age];
}

- (void)_trimToCost:(NSUInteger)costLimit {
    BOOL finish = NO;
    pthread_mutex_lock(&_lock);
    if (costLimit==0) {
        [_lru removeAll];
        finish = YES;
    }else if (_lru->_totalCost < costLimit){
        finish = YES;
    }
    pthread_mutex_unlock(&_lock);
    if (finish) return;
    
    NSMutableArray *holder = [NSMutableArray new];
    while (!finish) {
        if (pthread_mutex_trylock(&_lock)==0) {
            if (_lru->_totalCost > costLimit) {
                _LJLinkedMapNode *node = [_lru removeTailNode];
                if (node) [holder addObject:node];
            }else{
                finish = YES;
            }
            pthread_mutex_unlock(&_lock);
        }else{
            usleep(10*1000);//10 ms
        }
    }
    if (holder.count) {
        dispatch_queue_t queue = _lru->_releaseOnMainThread? dispatch_get_main_queue():LJMemoryCacheGetReleaseQueue();
        dispatch_async(queue, ^{
            [holder count];
        });
    }
}
- (void)_trimToCount:(NSUInteger)countLimit {
    BOOL finish = NO;
    pthread_mutex_lock(&_lock);
    if (countLimit==0) {
        [_lru removeAll];
        finish = YES;
    }else if (_lru->_totalCount < countLimit){
        finish = YES;
    }
    pthread_mutex_unlock(&_lock);
    if (finish) return;
    
    NSMutableArray *holder = [NSMutableArray new];
    while (!finish) {
        if (pthread_mutex_trylock(&_lock)==0) {
            if (_lru->_totalCount > countLimit) {
                _LJLinkedMapNode *node = [_lru removeTailNode];
                if (node) [holder addObject:node];
            }else{
                finish = YES;
            }
            pthread_mutex_unlock(&_lock);
        }else{
            usleep(10*1000);//10 ms
        }
    }
    if (holder.count) {
        dispatch_queue_t queue = _lru->_releaseOnMainThread? dispatch_get_main_queue():LJMemoryCacheGetReleaseQueue();
        dispatch_async(queue, ^{
            [holder count];
        });
    }
}
- (void)_trimToAge:(NSTimeInterval)ageLimit  {
    BOOL finish = NO;
    NSTimeInterval now = CACurrentMediaTime();
    pthread_mutex_lock(&_lock);
    if (ageLimit <= 0) {
        [_lru removeAll];
        finish = YES;
    } else if (!_lru->_tail || (now - _lru->_tail->_time) <= ageLimit) {
        finish = YES;
    }
    pthread_mutex_unlock(&_lock);
    if (finish) return;
    
    NSMutableArray *holder = [NSMutableArray new];
    while (!finish) {
        if (pthread_mutex_trylock(&_lock) == 0) {
            if (_lru->_tail && (now - _lru->_tail->_time) > ageLimit) {
                _LJLinkedMapNode *node = [_lru removeTailNode];
                if (node) [holder addObject:node];
            } else {
                finish = YES;
            }
            pthread_mutex_unlock(&_lock);
        } else {
            usleep(10 * 1000); //10 ms
        }
    }
    if (holder.count) {
        dispatch_queue_t queue = _lru->_releaseOnMainThread ? dispatch_get_main_queue():LJMemoryCacheGetReleaseQueue();
        dispatch_async(queue, ^{
            [holder count]; // release in queue
        });
    }
}

- (NSString *)description {
    if (_name) return [NSString stringWithFormat:@"<%@: %p> (%@)", self.class, self, _name];
    else return [NSString stringWithFormat:@"<%@: %p>", self.class, self];
}
@end
