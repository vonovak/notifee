/**
 * Copyright (c) 2016-present Invertase Limited & Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this library except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

#import "Private/NotifeeCore+UNUserNotificationCenter.h"

#import "Private/NotifeeCoreDelegateHolder.h"
#import "Private/NotifeeCoreUtil.h"

@implementation NotifeeCoreUNUserNotificationCenter
struct {
  unsigned int willPresentNotification : 1;
  unsigned int didReceiveNotificationResponse : 1;
  unsigned int openSettingsForNotification : 1;
} originalUNCDelegateRespondsTo;

+ (instancetype)instance {
  static dispatch_once_t once;
  __strong static NotifeeCoreUNUserNotificationCenter *sharedInstance;
  dispatch_once(&once, ^{
    sharedInstance = [[NotifeeCoreUNUserNotificationCenter alloc] init];
    sharedInstance.initialNotification = nil;
  });
  return sharedInstance;
}

- (void)observe {
  static dispatch_once_t once;
  __weak NotifeeCoreUNUserNotificationCenter *weakSelf = self;
  dispatch_once(&once, ^{
    NotifeeCoreUNUserNotificationCenter *strongSelf = weakSelf;
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    if (center.delegate != nil) {
      _originalDelegate = center.delegate;
      originalUNCDelegateRespondsTo.openSettingsForNotification = (unsigned int)[_originalDelegate
          respondsToSelector:@selector(userNotificationCenter:openSettingsForNotification:)];
      originalUNCDelegateRespondsTo.willPresentNotification = (unsigned int)[_originalDelegate
          respondsToSelector:@selector(userNotificationCenter:
                                      willPresentNotification:withCompletionHandler:)];
      originalUNCDelegateRespondsTo.didReceiveNotificationResponse =
          (unsigned int)[_originalDelegate
              respondsToSelector:@selector(userNotificationCenter:
                                     didReceiveNotificationResponse:withCompletionHandler:)];
    }
    center.delegate = strongSelf;
  });
}

- (nullable NSDictionary *)getInitialNotification {
  if (_initialNotification != nil) {
    NSDictionary *initialNotificationCopy = [_initialNotification copy];
    _initialNotification = nil;
    return initialNotificationCopy;
  }

  return nil;
}

#pragma mark - UNUserNotificationCenter Delegate Methods

// The method will be called on the delegate only if the application is in the
// foreground. If the the handler is not called in a timely manner then the
// notification will not be presented. The application can choose to have the
// notification presented as a sound, badge, alert and/or in the notification
// list. This decision should be based on whether the information in the
// notification is otherwise visible to the user.
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:
             (void (^)(UNNotificationPresentationOptions options))completionHandler {
  NSDictionary *notifeeNotification =
      notification.request.content.userInfo[kNotifeeUserInfoNotification];

  // we only care about notifications created through notifee
  if (notifeeNotification != nil) {
    UNNotificationPresentationOptions presentationOptions = 0;
    NSDictionary *foregroundPresentationOptions =
        notifeeNotification[@"ios"][@"foregroundPresentationOptions"];

    BOOL alert = [foregroundPresentationOptions[@"alert"] boolValue];
    BOOL badge = [foregroundPresentationOptions[@"badge"] boolValue];
    BOOL sound = [foregroundPresentationOptions[@"sound"] boolValue];

    if (badge) {
      presentationOptions |= UNNotificationPresentationOptionBadge;
    }

    if (sound) {
      presentationOptions |= UNNotificationPresentationOptionSound;
    }

    if (alert) {
      presentationOptions |= UNNotificationPresentationOptionAlert;
    }

    NSDictionary *notifeeTrigger = notification.request.content.userInfo[kNotifeeUserInfoTrigger];
    if (notifeeTrigger != nil) {
      // post DELIVERED event
      [[NotifeeCoreDelegateHolder instance] didReceiveNotifeeCoreEvent:@{
        @"type" : @(NotifeeCoreEventTypeDelivered),
        @"detail" : @{
          @"notification" : notifeeNotification,
        }
      }];
    }

    completionHandler(presentationOptions);

  } else if (_originalDelegate != nil && originalUNCDelegateRespondsTo.willPresentNotification) {
    [_originalDelegate userNotificationCenter:center
                      willPresentNotification:notification
                        withCompletionHandler:completionHandler];
  }
}

// The method will be called when the user responded to the notification by
// opening the application, dismissing the notification or choosing a
// UNNotificationAction. The delegate must be set before the application returns
// from application:didFinishLaunchingWithOptions:.
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
    didReceiveNotificationResponse:(UNNotificationResponse *)response
             withCompletionHandler:(void (^)(void))completionHandler {
  NSDictionary *notifeeNotification =
      response.notification.request.content.userInfo[kNotifeeUserInfoNotification];

  // we only care about notifications created through notifee
  if (notifeeNotification != nil) {
    if ([response.actionIdentifier isEqualToString:UNNotificationDismissActionIdentifier]) {
      // post DISMISSED event, only triggers if notification has a categoryId
      [[NotifeeCoreDelegateHolder instance] didReceiveNotifeeCoreEvent:@{
        @"type" : @(NotifeeCoreEventTypeDismissed),
        @"detail" : @{
          @"notification" : notifeeNotification,
        }
      }];
      return;
    }

    NSNumber *eventType;
    NSMutableDictionary *event = [NSMutableDictionary dictionary];
    NSMutableDictionary *eventDetail = [NSMutableDictionary dictionary];
    NSMutableDictionary *eventDetailPressAction = [NSMutableDictionary dictionary];

    if ([response.actionIdentifier isEqualToString:UNNotificationDefaultActionIdentifier]) {
      eventType = @1;  // PRESS
      // event.detail.pressAction.id
      eventDetailPressAction[@"id"] = @"default";
    } else {
      eventType = @2;  // ACTION_PRESS
      // event.detail.pressAction.id
      eventDetailPressAction[@"id"] = response.actionIdentifier;
    }

    if ([response isKindOfClass:UNTextInputNotificationResponse.class]) {
      // event.detail.input
      eventDetail[@"input"] = [(UNTextInputNotificationResponse *)response userText];
    }

    // event.type
    event[@"type"] = eventType;

    // event.detail.notification
    eventDetail[@"notification"] = notifeeNotification;

    // event.detail.pressAction
    eventDetail[@"pressAction"] = eventDetailPressAction;

    // event.detail
    event[@"detail"] = eventDetail;

    // store notification for getInitialNotification
    _initialNotification = [eventDetail copy];

    // post PRESS/ACTION_PRESS event
    [[NotifeeCoreDelegateHolder instance] didReceiveNotifeeCoreEvent:event];

    // TODO figure out if this is needed or if we can just complete immediately
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                     completionHandler();
                   });

  } else if (_originalDelegate != nil &&
             originalUNCDelegateRespondsTo.didReceiveNotificationResponse) {
    [_originalDelegate userNotificationCenter:center
               didReceiveNotificationResponse:response
                        withCompletionHandler:completionHandler];
  }
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
    openSettingsForNotification:(nullable UNNotification *)notification {
  if (_originalDelegate != nil && originalUNCDelegateRespondsTo.openSettingsForNotification) {
    [_originalDelegate userNotificationCenter:center openSettingsForNotification:notification];
  }
}

@end
