//
//  Created by krzysztof.zablocki on 3/23/12.
//
//
//

#import "NSNotificationCenter+SFObservers.h"
#import <objc/runtime.h>
#import <objc/message.h>

static NSString const *NSNotificationCenterSFObserversArrayKey = @"NSNotificationCenterSFObserversArrayKey";
static NSString const *NSNotificationCenterSFObserversAllowMethodForwardingKey = @"NSNotificationCenterSFObserversAllowMethodForwardingKey";

static NSString *NSNotificationCenterSFObserversAddSelector = @"sf_original_addObserver:selector:name:object:";
static NSString *NSNotificationCenterSFObserversRemoveSelector = @"sf_original_removeObserver:";
static NSString *NSNotificationCenterSFObserversRemoveSpecificSelector = @"sf_original_removeObserver:name:object:";

@interface __SFObserversNotificationObserverInfo : NSObject
@property(nonatomic, copy) NSString *name;
@property(nonatomic, AH_WEAK) id object;
@property(nonatomic, assign) void *blockKey;
@end

@implementation __SFObserversNotificationObserverInfo
@synthesize name;
@synthesize object;
@synthesize blockKey;


- (void)dealloc
{
  AH_RELEASE(name);
  AH_SUPER_DEALLOC;
}

@end

@implementation NSNotificationCenter (SFObservers)

+ (void)sf_swapSelector:(SEL)aOriginalSelector withSelector:(SEL)aSwappedSelector
{
  Method originalMethod = class_getInstanceMethod(self, aOriginalSelector);
  Method swappedMethod = class_getInstanceMethod(self, aSwappedSelector);

  SEL newSelector = NSSelectorFromString([NSString stringWithFormat:@"sf_original_%@", NSStringFromSelector(aOriginalSelector)]);
  class_addMethod([self class], newSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
  class_replaceMethod([self class], aOriginalSelector, method_getImplementation(swappedMethod), method_getTypeEncoding(swappedMethod));
}

+ (void)load
{
  //! swap methods
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    @autoreleasepool {
      [self sf_swapSelector:@selector(addObserver:selector:name:object:) withSelector:@selector(sf_addObserver:selector:name:object:)];
      [self sf_swapSelector:@selector(removeObserver:) withSelector:@selector(sf_removeObserver:)];
      [self sf_swapSelector:@selector(removeObserver:name:object:) withSelector:@selector(sf_removeObserver:name:object:)];
    }
  });
}

- (BOOL)allowMethodForwarding
{
  NSNumber *state = objc_getAssociatedObject(self, AH_BRIDGE(NSNotificationCenterSFObserversAllowMethodForwardingKey));
  return [state boolValue];
}

- (void)setAllowMethodForwarding:(BOOL)allowForwarding
{
  objc_setAssociatedObject(self, AH_BRIDGE(NSNotificationCenterSFObserversAllowMethodForwardingKey), [NSNumber numberWithBool:allowForwarding], OBJC_ASSOCIATION_RETAIN);
}

- (void)sf_addObserver:(id)observer selector:(SEL)aSelector name:(NSString *)aName object:(id)anObject
{
  //! store info into our observer structure
  NSMutableDictionary *registeredNotifications = (NSMutableDictionary *)objc_getAssociatedObject(observer, AH_BRIDGE(NSNotificationCenterSFObserversArrayKey));
  if (!registeredNotifications) {
    registeredNotifications = [NSMutableDictionary dictionary];
    objc_setAssociatedObject(observer, AH_BRIDGE(NSNotificationCenterSFObserversArrayKey), registeredNotifications, OBJC_ASSOCIATION_RETAIN);
  }

  NSMutableArray *observerInfos = [registeredNotifications objectForKey:NSStringFromSelector(aSelector)];
  if (!observerInfos) {
    observerInfos = [NSMutableArray array];
    [registeredNotifications setObject:observerInfos forKey:NSStringFromSelector(aSelector)];
  }
  __block __SFObserversNotificationObserverInfo *observerInfo = nil;

  //! don't allow to add many times the same observer
  [observerInfos enumerateObjectsUsingBlock:^void(id obj, NSUInteger idx, BOOL *stop) {
    __SFObserversNotificationObserverInfo *info = obj;
    if ([info.name isEqualToString:aName] && info.object == anObject) {
      observerInfo = info;
      *stop = YES;
    }
  }];

  if (!observerInfo) {
    observerInfo = [[__SFObserversNotificationObserverInfo alloc] init];
    [observerInfos addObject:observerInfo];
    AH_RELEASE(observerInfo);
  } else {
    //! don't register twice so skip this
    //NSAssert(NO, @"You shouldn't register twice for same notification, selector, name, object");
    return;
  }

  observerInfo.name = aName;
  observerInfo.object = anObject;

  //! Add auto remove when observer is going to be deallocated
  __unsafe_unretained __block id weakSelf = self;
  __unsafe_unretained __block id weakObserver = observer;
  __unsafe_unretained __block id weakObject = anObject;

  void *key = [observer performBlockOnDealloc:^{
    if ([weakSelf sf_removeObserver:weakObserver name:aName object:weakObject registeredNotifications:registeredNotifications]) {
      [self setAllowMethodForwarding:YES];
#if SF_OBSERVERS_LOG_ORIGINAL_METHODS
      NSLog(@"Calling original method %@ with parameters %@ %@ %@", NSNotificationCenterSFObserversRemoveSpecificSelector, weakObserver, aName, weakObject);
#endif
      objc_msgSend(weakSelf, NSSelectorFromString(NSNotificationCenterSFObserversRemoveSpecificSelector), weakObserver, aName, weakObject);
      [self setAllowMethodForwarding:NO];
    }
  }];

  //! remember the block key
  observerInfo.blockKey = key;

  //! call originalMethod
#if SF_OBSERVERS_LOG_ORIGINAL_METHODS
  NSLog(@"Calling original method %@ with parameters %@ %@ %@ %@", NSNotificationCenterSFObserversAddSelector, observer, NSStringFromSelector(aSelector), aName, anObject);
#endif
  objc_msgSend(self, NSSelectorFromString(NSNotificationCenterSFObserversAddSelector), observer, aSelector, aName, anObject);
}


- (void)sf_removeObserver:(id)observer
{
  if ([self allowMethodForwarding]) {
#if SF_OBSERVERS_LOG_ORIGINAL_METHODS
      NSLog(@"Calling original method %@ with parameters %@", NSNotificationCenterSFObserversRemoveSelector, observer);
#endif
    objc_msgSend(self, NSSelectorFromString(NSNotificationCenterSFObserversRemoveSelector), observer);
    return;
  }

  NSMutableDictionary *registeredNotifications = (NSMutableDictionary *)objc_getAssociatedObject(observer, AH_BRIDGE(NSNotificationCenterSFObserversArrayKey));
  if ([self sf_removeObserver:observer name:nil object:nil registeredNotifications:registeredNotifications]) {
#if SF_OBSERVERS_LOG_ORIGINAL_METHODS
      NSLog(@"Calling original method %@ with parameters %@", NSNotificationCenterSFObserversRemoveSelector, observer);
#endif
    [self setAllowMethodForwarding:YES];
    objc_msgSend(self, NSSelectorFromString(NSNotificationCenterSFObserversRemoveSelector), observer);
    [self setAllowMethodForwarding:NO];
  }

}

- (void)sf_removeObserver:(id)observer name:(NSString *)aName object:(id)anObject
{
  if ([self allowMethodForwarding]) {
#if SF_OBSERVERS_LOG_ORIGINAL_METHODS
      NSLog(@"Calling original method %@ with parameters %@ %@ %@", NSNotificationCenterSFObserversRemoveSpecificSelector, observer, aName, anObject);
#endif
    objc_msgSend(self, NSSelectorFromString(NSNotificationCenterSFObserversRemoveSpecificSelector), observer, aName, anObject);
    return;
  }

  NSMutableDictionary *registeredNotifications = (NSMutableDictionary *)objc_getAssociatedObject(observer, AH_BRIDGE(NSNotificationCenterSFObserversArrayKey));
  if ([self allowMethodForwarding] || [self sf_removeObserver:observer name:aName object:anObject registeredNotifications:registeredNotifications]) {
    [self setAllowMethodForwarding:YES];
#if SF_OBSERVERS_LOG_ORIGINAL_METHODS
      NSLog(@"Calling original method %@ with parameters %@ %@ %@", NSNotificationCenterSFObserversRemoveSpecificSelector, observer, aName, anObject);
#endif
    objc_msgSend(self, NSSelectorFromString(NSNotificationCenterSFObserversRemoveSpecificSelector), observer, aName, anObject);
    [self setAllowMethodForwarding:NO];
  }

}

- (BOOL)sf_removeObserver:(id)observer name:(NSString *)aName object:(id)anObject registeredNotifications:(NSMutableDictionary *)registeredNotifications
{
  __block BOOL result = NO;

  if (aName == nil && anObject == nil) {
    //! don't need to execute block on dealloc so cleanup
    [registeredNotifications enumerateKeysAndObjectsUsingBlock:^void(id key, id obj, BOOL *stop) {
      NSMutableArray *observerInfos = obj;
      [observerInfos enumerateObjectsUsingBlock:^void(id innerObj, NSUInteger idx, BOOL *innerStop) {
        __SFObserversNotificationObserverInfo *info = innerObj;
        [observer cancelDeallocBlockWithKey:info.blockKey];
      }];
    }];
    [registeredNotifications removeAllObjects];

    return YES;
  } else {
    [registeredNotifications enumerateKeysAndObjectsUsingBlock:^void(id key, id obj, BOOL *stop) {
      NSMutableArray *observerInfos = obj;
      NSMutableArray *objectsToRemove = [NSMutableArray array];
      [observerInfos enumerateObjectsUsingBlock:^void(id innerObj, NSUInteger idx, BOOL *innerStop) {
        __SFObserversNotificationObserverInfo *info = innerObj;

        if ((!aName || [aName isEqualToString:info.name]) && (!anObject || (anObject == info.object))) {
          //! remove this info
          [objectsToRemove addObject:innerObj];

          //! cancel dealloc blocks
          [innerObj cancelDeallocBlockWithKey:info.blockKey];
        }
      }];

      //! remove all collected objects
      if ([objectsToRemove count] > 0) {
        [observerInfos removeObjectsInArray:objectsToRemove];
        result = YES;
      }
    }];
  }

  return result;
}
@end