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

#import "Public/NotifeeCore.h"

#import <UIKit/UIKit.h>
#import "Private/NotifeeCore+UNUserNotificationCenter.h"
#import "Private/NotifeeCoreDelegateHolder.h"
#import "Private/NotifeeCoreExtensionHelper.h"
#import "Private/NotifeeCoreUtil.h"

@implementation NotifeeCore

#pragma mark - Library Methods

+ (void)setCoreDelegate:(id<NotifeeCoreDelegate>)coreDelegate {
  [NotifeeCoreDelegateHolder instance].delegate = coreDelegate;
}

/**
 * Cancel a currently displayed or pending trigger notification.
 *
 * @param notificationId NSString id of the notification to cancel
 * @param block notifeeMethodVoidBlock
 */
+ (void)cancelNotification:(NSString *)notificationId
      withNotificationType:(NSInteger)notificationType
                 withBlock:(notifeeMethodVoidBlock)block {
  UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
  // cancel displayed notification
  if (notificationType == NotifeeCoreNotificationTypeDisplayed ||
      notificationType == NotifeeCoreNotificationTypeAll)
    [center removeDeliveredNotificationsWithIdentifiers:@[ notificationId ]];

  // cancel trigger notification
  if (notificationType == NotifeeCoreNotificationTypeTrigger ||
      notificationType == NotifeeCoreNotificationTypeAll)
    [center removePendingNotificationRequestsWithIdentifiers:@[ notificationId ]];
  block(nil);
}

/**
 * Cancel all currently displayed or pending trigger notifications.
 *
 * @param notificationType NSInteger
 * @param block notifeeMethodVoidBlock
 */
+ (void)cancelAllNotifications:(NSInteger)notificationType withBlock:(notifeeMethodVoidBlock)block {
  UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];

  // cancel displayed notifications
  if (notificationType == NotifeeCoreNotificationTypeDisplayed ||
      notificationType == NotifeeCoreNotificationTypeAll)
    [center removeAllDeliveredNotifications];

  // cancel trigger notifications
  if (notificationType == NotifeeCoreNotificationTypeTrigger ||
      notificationType == NotifeeCoreNotificationTypeAll)
    [center removeAllPendingNotificationRequests];
  block(nil);
}

/**
 * Cancel currently displayed or pending trigger notifications by ids.
 *
 * @param notificationType NSInteger
 * @param ids NSInteger
 * @param block notifeeMethodVoidBlock
 */
+ (void)cancelAllNotificationsWithIds:(NSInteger)notificationType
                              withIds:(NSArray<NSString *> *)ids
                            withBlock:(notifeeMethodVoidBlock)block {
  UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];

  // cancel displayed notifications
  if (notificationType == NotifeeCoreNotificationTypeDisplayed ||
      notificationType == NotifeeCoreNotificationTypeAll)
    [center removeDeliveredNotificationsWithIdentifiers:ids];

  // cancel trigger notifications
  if (notificationType == NotifeeCoreNotificationTypeTrigger ||
      notificationType == NotifeeCoreNotificationTypeAll)
    [center removePendingNotificationRequestsWithIdentifiers:ids];
  block(nil);
}

+ (void)getDisplayedNotifications:(notifeeMethodNSArrayBlock)block {
  UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
  NSMutableArray *triggerNotifications = [[NSMutableArray alloc] init];
  [center getDeliveredNotificationsWithCompletionHandler:^(
              NSArray<UNNotification *> *_Nonnull deliveredNotifications) {
    for (UNNotification *deliveredNotification in deliveredNotifications) {
      NSMutableDictionary *triggerNotification = [NSMutableDictionary dictionary];
      triggerNotification[@"id"] = deliveredNotification.request.identifier;

      triggerNotification[@"date"] =
          [NotifeeCoreUtil convertToTimestamp:deliveredNotification.date];
      triggerNotification[@"notification"] =
          deliveredNotification.request.content.userInfo[kNotifeeUserInfoNotification];
      triggerNotification[@"trigger"] =
          deliveredNotification.request.content.userInfo[kNotifeeUserInfoTrigger];

      if (triggerNotification[@"notification"] == nil) {
        // parse remote notification
        triggerNotification[@"notification"] =
            [NotifeeCoreUtil parseUNNotificationRequest:deliveredNotification.request];
      }

      [triggerNotifications addObject:triggerNotification];
    }
    block(nil, triggerNotifications);
  }];
}

+ (void)getTriggerNotifications:(notifeeMethodNSArrayBlock)block {
  UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];

  [center getPendingNotificationRequestsWithCompletionHandler:^(
              NSArray<UNNotificationRequest *> *_Nonnull requests) {
    NSMutableArray *triggerNotifications = [[NSMutableArray alloc] init];

    for (UNNotificationRequest *request in requests) {
      NSMutableDictionary *triggerNotification = [NSMutableDictionary dictionary];

      triggerNotification[@"notification"] = request.content.userInfo[kNotifeeUserInfoNotification];
      triggerNotification[@"trigger"] = request.content.userInfo[kNotifeeUserInfoTrigger];

      [triggerNotifications addObject:triggerNotification];
    }

    block(nil, triggerNotifications);
  }];
}

/**
 * Retrieve a NSArray of pending UNNotificationRequest for the application.
 * Resolves a NSArray of UNNotificationRequest identifiers.
 *
 * @param block notifeeMethodNSArrayBlock
 */
+ (void)getTriggerNotificationIds:(notifeeMethodNSArrayBlock)block {
  UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
  [center getPendingNotificationRequestsWithCompletionHandler:^(
              NSArray<UNNotificationRequest *> *_Nonnull requests) {
    NSMutableArray<NSString *> *idsArray = [[NSMutableArray alloc] init];

    for (UNNotificationRequest *request in requests) {
      NSString *notificationId = request.identifier;
      [idsArray addObject:notificationId];
    }

    block(nil, idsArray);
  }];
}

/**
 * Display a local notification immediately.
 *
 * @param notification NSDictionary representation of
 * UNMutableNotificationContent
 * @param block notifeeMethodVoidBlock
 */
+ (void)displayNotification:(NSDictionary *)notification withBlock:(notifeeMethodVoidBlock)block {
  UNMutableNotificationContent *content = [self buildNotificationContent:notification
                                                             withTrigger:nil];

  UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:notification[@"id"]
                                                                        content:content
                                                                        trigger:nil];
  UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];

  NSMutableDictionary *notificationDetail = [notification mutableCopy];
  notificationDetail[@"remote"] = @NO;

  [center addNotificationRequest:request
           withCompletionHandler:^(NSError *error) {
             if (error == nil) {
               [[NotifeeCoreDelegateHolder instance] didReceiveNotifeeCoreEvent:@{
                 @"type" : @(NotifeeCoreEventTypeDelivered),
                 @"detail" : @{
                   @"notification" : notificationDetail,
                 }
               }];
             }
             block(error);
           }];
}

/* Create a trigger notification .
 *
 * @param notification NSDictionary representation of
 * UNMutableNotificationContent
 * @param block notifeeMethodVoidBlock
 */
+ (void)createTriggerNotification:(NSDictionary *)notification
                      withTrigger:(NSDictionary *)trigger
                        withBlock:(notifeeMethodVoidBlock)block {
  UNMutableNotificationContent *content = [self buildNotificationContent:notification
                                                             withTrigger:trigger];
  UNNotificationTrigger *unTrigger = [NotifeeCoreUtil triggerFromDictionary:trigger];

  if (unTrigger == nil) {
    // do nothing if trigger is null
    return block(nil);
  }

  UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:notification[@"id"]
                                                                        content:content
                                                                        trigger:unTrigger];
  UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];

  NSMutableDictionary *notificationDetail = [notification mutableCopy];
  notificationDetail[@"remote"] = @NO;

  [center addNotificationRequest:request
           withCompletionHandler:^(NSError *error) {
             if (error == nil) {
               [[NotifeeCoreDelegateHolder instance] didReceiveNotifeeCoreEvent:@{
                 @"type" : @(NotifeeCoreEventTypeTriggerNotificationCreated),
                 @"detail" : @{
                   @"notification" : notificationDetail,
                 }
               }];
             }
             block(error);
           }];
}

/**
 * Builds a UNMutableNotificationContent from a NSDictionary.
 *
 * @param notification NSDictionary representation of UNNotificationContent
 */

+ (UNMutableNotificationContent *)buildNotificationContent:(NSDictionary *)notification
                                               withTrigger:(NSDictionary *)trigger {
  NSDictionary *iosDict = notification[@"ios"];
  UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];

  // title
  if (notification[@"title"] != nil) {
    content.title = notification[@"title"];
  }

  // subtitle
  if (notification[@"subtitle"] != nil) {
    content.subtitle = notification[@"subtitle"];
  }

  // body
  if (notification[@"body"] != nil) {
    content.body = notification[@"body"];
  }

  // data
  NSMutableDictionary *userInfo = [notification[@"data"] mutableCopy];

  // attach a copy of the original notification payload into the data object,
  // for internal use
  userInfo[kNotifeeUserInfoNotification] = [notification mutableCopy];
  if (trigger != nil) {
    userInfo[kNotifeeUserInfoTrigger] = [trigger mutableCopy];
  }

  content.userInfo = userInfo;

  // badgeCount - nil is an acceptable value so no need to check key existence
  content.badge = iosDict[@"badgeCount"];

  // categoryId
  if (iosDict[@"categoryId"] != nil) {
    content.categoryIdentifier = iosDict[@"categoryId"];
  }

  // launchImageName
  if (iosDict[@"launchImageName"] != nil) {
    content.launchImageName = iosDict[@"launchImageName"];
  }

  // critical, criticalVolume, sound
  if (iosDict[@"critical"] != nil) {
    UNNotificationSound *notificationSound;
    BOOL criticalSound = [iosDict[@"critical"] boolValue];
    NSNumber *criticalSoundVolume = iosDict[@"criticalVolume"];
    NSString *soundName = iosDict[@"sound"] != nil ? iosDict[@"sound"] : @"default";

    if ([soundName isEqualToString:@"default"]) {
      if (criticalSound) {
        if (@available(iOS 12.0, *)) {
          if (criticalSoundVolume != nil) {
            notificationSound = [UNNotificationSound
                defaultCriticalSoundWithAudioVolume:[criticalSoundVolume floatValue]];
          } else {
            notificationSound = [UNNotificationSound defaultCriticalSound];
          }
        } else {
          notificationSound = [UNNotificationSound defaultSound];
        }
      } else {
        notificationSound = [UNNotificationSound defaultSound];
      }
    } else {
      if (criticalSound) {
        if (@available(iOS 12.0, *)) {
          if (criticalSoundVolume != nil) {
            notificationSound =
                [UNNotificationSound criticalSoundNamed:soundName
                                        withAudioVolume:[criticalSoundVolume floatValue]];
          } else {
            notificationSound = [UNNotificationSound criticalSoundNamed:soundName];
          }
        } else {
          notificationSound = [UNNotificationSound soundNamed:soundName];
        }
      } else {
        notificationSound = [UNNotificationSound soundNamed:soundName];
      }
    }
    content.sound = notificationSound;
  } else if (iosDict[@"sound"] != nil) {
    UNNotificationSound *notificationSound;
    NSString *soundName = iosDict[@"sound"];

    if ([soundName isEqualToString:@"default"]) {
      notificationSound = [UNNotificationSound defaultSound];
    } else {
      notificationSound = [UNNotificationSound soundNamed:soundName];
    }

    content.sound = notificationSound;

  }  // critical, criticalVolume, sound

  // threadId
  if (iosDict[@"threadId"] != nil) {
    content.threadIdentifier = iosDict[@"threadId"];
  }

  if (@available(iOS 12.0, *)) {
    // summaryArgument
    if (iosDict[@"summaryArgument"] != nil) {
      content.summaryArgument = iosDict[@"summaryArgument"];
    }

    // summaryArgumentCount
    if (iosDict[@"summaryArgumentCount"] != nil) {
      content.summaryArgumentCount = [iosDict[@"summaryArgumentCount"] unsignedIntValue];
    }
  }

  if (@available(iOS 13.0, *)) {
    // targetContentId
    if (iosDict[@"targetContentId"] != nil) {
      content.targetContentIdentifier = iosDict[@"targetContentId"];
    }
  }

  // Ignore downloading attachments here if remote notifications via NSE
  BOOL remote = [notification[@"remote"] boolValue];

  if (iosDict[@"attachments"] != nil && !remote) {
    content.attachments =
        [NotifeeCoreUtil notificationAttachmentsFromDictionaryArray:iosDict[@"attachments"]];
  }

  return content;
}

+ (void)getNotificationCategories:(notifeeMethodNSArrayBlock)block {
  UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
  [center getNotificationCategoriesWithCompletionHandler:^(
              NSSet<UNNotificationCategory *> *categories) {
    NSMutableArray<NSDictionary *> *categoriesArray = [[NSMutableArray alloc] init];

    for (UNNotificationCategory *notificationCategory in categories) {
      NSMutableDictionary *categoryDictionary = [NSMutableDictionary dictionary];

      categoryDictionary[@"id"] = notificationCategory.identifier;
      categoryDictionary[@"allowInCarPlay"] =
          @(((notificationCategory.options & UNNotificationCategoryOptionAllowInCarPlay) != 0));

      if (@available(iOS 11.0, *)) {
        categoryDictionary[@"hiddenPreviewsShowTitle"] =
            @(((notificationCategory.options &
                UNNotificationCategoryOptionHiddenPreviewsShowTitle) != 0));
        categoryDictionary[@"hiddenPreviewsShowSubtitle"] =
            @(((notificationCategory.options &
                UNNotificationCategoryOptionHiddenPreviewsShowSubtitle) != 0));
        if (notificationCategory.hiddenPreviewsBodyPlaceholder != nil) {
          categoryDictionary[@"hiddenPreviewsBodyPlaceholder"] =
              notificationCategory.hiddenPreviewsBodyPlaceholder;
        }
      } else {
        categoryDictionary[@"hiddenPreviewsShowTitle"] = @(NO);
        categoryDictionary[@"hiddenPreviewsShowSubtitle"] = @(NO);
      }

      if (@available(iOS 12.0, *)) {
        if (notificationCategory.categorySummaryFormat != nil) {
          categoryDictionary[@"summaryFormat"] = notificationCategory.categorySummaryFormat;
        }
      }

      if (@available(iOS 13.0, *)) {
        categoryDictionary[@"allowAnnouncement"] = @(
            ((notificationCategory.options & UNNotificationCategoryOptionAllowAnnouncement) != 0));
      } else {
        categoryDictionary[@"allowAnnouncement"] = @(NO);
      }

      categoryDictionary[@"actions"] =
          [NotifeeCoreUtil notificationActionsToDictionaryArray:notificationCategory.actions];
      categoryDictionary[@"intentIdentifiers"] =
          [NotifeeCoreUtil intentIdentifiersFromStringArray:notificationCategory.intentIdentifiers];

      [categoriesArray addObject:categoryDictionary];
    }

    block(nil, categoriesArray);
  }];
}

/**
 * Builds and replaces the existing notification categories on
 * UNUserNotificationCenter
 *
 * @param categories NSArray<NSDictionary *> *
 * @param block notifeeMethodVoidBlock
 */
+ (void)setNotificationCategories:(NSArray<NSDictionary *> *)categories
                        withBlock:(notifeeMethodVoidBlock)block {
  NSMutableSet *UNNotificationCategories = [[NSMutableSet alloc] init];

  for (NSDictionary *categoryDictionary in categories) {
    UNNotificationCategory *category;

    NSString *id = categoryDictionary[@"id"];
    NSString *summaryFormat = categoryDictionary[@"summaryFormat"];
    NSString *bodyPlaceHolder = categoryDictionary[@"hiddenPreviewsBodyPlaceholder"];

    NSArray<UNNotificationAction *> *actions =
        [NotifeeCoreUtil notificationActionsFromDictionaryArray:categoryDictionary[@"actions"]];
    NSArray<NSString *> *intentIdentifiers =
        [NotifeeCoreUtil intentIdentifiersFromNumberArray:categoryDictionary[@"intentIdentifiers"]];

    UNNotificationCategoryOptions options = UNNotificationCategoryOptionCustomDismissAction;

    if ([categoryDictionary[@"allowInCarPlay"] isEqual:@(YES)]) {
      options |= UNNotificationCategoryOptionAllowInCarPlay;
    }

    if (@available(iOS 11.0, *)) {
      if ([categoryDictionary[@"hiddenPreviewsShowTitle"] isEqual:@(YES)]) {
        options |= UNNotificationCategoryOptionHiddenPreviewsShowTitle;
      }

      if ([categoryDictionary[@"hiddenPreviewsShowSubtitle"] isEqual:@(YES)]) {
        options |= UNNotificationCategoryOptionHiddenPreviewsShowSubtitle;
      }
    }

    if (@available(iOS 13.0, *)) {
      if ([categoryDictionary[@"allowAnnouncement"] isEqual:@(YES)]) {
        options |= UNNotificationCategoryOptionAllowAnnouncement;
      }
    }

    if (@available(iOS 12.0, *)) {
      category = [UNNotificationCategory categoryWithIdentifier:id
                                                        actions:actions
                                              intentIdentifiers:intentIdentifiers
                                  hiddenPreviewsBodyPlaceholder:bodyPlaceHolder
                                          categorySummaryFormat:summaryFormat
                                                        options:options];
    } else if (@available(iOS 11.0, *)) {
      category = [UNNotificationCategory categoryWithIdentifier:id
                                                        actions:actions
                                              intentIdentifiers:intentIdentifiers
                                  hiddenPreviewsBodyPlaceholder:bodyPlaceHolder
                                                        options:options];
    } else {
      category = [UNNotificationCategory categoryWithIdentifier:id
                                                        actions:actions
                                              intentIdentifiers:intentIdentifiers
                                                        options:options];
    }

    [UNNotificationCategories addObject:category];
  }

  UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
  [center setNotificationCategories:UNNotificationCategories];
  block(nil);
}

/**
 * Request UNAuthorizationOptions for user notifications.
 * Resolves a NSDictionary representation of UNNotificationSettings.
 *
 * @param permissions NSDictionary
 * @param block NSDictionary block
 */
+ (void)requestPermission:(NSDictionary *)permissions
                withBlock:(notifeeMethodNSDictionaryBlock)block {
  UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];

  UNAuthorizationOptions options = UNAuthorizationOptionNone;

  if ([permissions[@"alert"] isEqual:@(YES)]) {
    options |= UNAuthorizationOptionAlert;
  }

  if ([permissions[@"badge"] isEqual:@(YES)]) {
    options |= UNAuthorizationOptionBadge;
  }

  if ([permissions[@"sound"] isEqual:@(YES)]) {
    options |= UNAuthorizationOptionSound;
  }

  if ([permissions[@"inAppNotificationSettings"] isEqual:@(YES)]) {
    if (@available(iOS 12.0, *)) {
      options |= UNAuthorizationOptionProvidesAppNotificationSettings;
    }
  }

  if ([permissions[@"provisional"] isEqual:@(YES)]) {
    if (@available(iOS 12.0, *)) {
      options |= UNAuthorizationOptionProvisional;
    }
  }

  if ([permissions[@"announcement"] isEqual:@(YES)]) {
    if (@available(iOS 13.0, *)) {
      options |= UNAuthorizationOptionAnnouncement;
    }
  }

  if ([permissions[@"carPlay"] isEqual:@(YES)]) {
    options |= UNAuthorizationOptionCarPlay;
  }

  if ([permissions[@"criticalAlert"] isEqual:@(YES)]) {
    if (@available(iOS 12.0, *)) {
      options |= UNAuthorizationOptionCriticalAlert;
    }
  }

  id handler = ^(BOOL granted, NSError *_Nullable error) {
    if (error != nil) {
      // TODO send error to notifeeMethodNSDictionaryBlock
    }

    [self getNotificationSettings:block];
  };

  [center requestAuthorizationWithOptions:options completionHandler:handler];
}

/**
 * Retrieve UNNotificationSettings for the application.
 * Resolves a NSDictionary representation of UNNotificationSettings.
 *
 * @param block NSDictionary block
 */
+ (void)getNotificationSettings:(notifeeMethodNSDictionaryBlock)block {
  UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];

  [center
      getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *_Nonnull settings) {
        NSMutableDictionary *settingsDictionary = [NSMutableDictionary dictionary];

        // authorizedStatus
        NSNumber *authorizedStatus = @-1;
        if (settings.authorizationStatus == UNAuthorizationStatusNotDetermined) {
          authorizedStatus = @-1;
        } else if (settings.authorizationStatus == UNAuthorizationStatusDenied) {
          authorizedStatus = @0;
        } else if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
          authorizedStatus = @1;
        }

        if (@available(iOS 12.0, *)) {
          if (settings.authorizationStatus == UNAuthorizationStatusProvisional) {
            authorizedStatus = @2;
          }
        }

        NSNumber *showPreviews = @-1;
        if (@available(iOS 11.0, *)) {
          if (settings.showPreviewsSetting == UNShowPreviewsSettingNever) {
            showPreviews = @0;
          } else if (settings.showPreviewsSetting == UNShowPreviewsSettingAlways) {
            showPreviews = @1;
          } else if (settings.showPreviewsSetting == UNShowPreviewsSettingWhenAuthenticated) {
            showPreviews = @2;
          }
        }

        if (@available(iOS 13.0, *)) {
          settingsDictionary[@"announcement"] =
              [NotifeeCoreUtil numberForUNNotificationSetting:settings.announcementSetting];
        } else {
          settingsDictionary[@"announcement"] = @-1;
        }

        if (@available(iOS 12.0, *)) {
          settingsDictionary[@"criticalAlert"] =
              [NotifeeCoreUtil numberForUNNotificationSetting:settings.criticalAlertSetting];
        } else {
          settingsDictionary[@"criticalAlert"] = @-1;
        }

        if (@available(iOS 12.0, *)) {
          settingsDictionary[@"inAppNotificationSettings"] =
              settings.providesAppNotificationSettings ? @1 : @0;
        } else {
          settingsDictionary[@"inAppNotificationSettings"] = @-1;
        }

        settingsDictionary[@"showPreviews"] = showPreviews;
        settingsDictionary[@"authorizationStatus"] = authorizedStatus;
        settingsDictionary[@"alert"] =
            [NotifeeCoreUtil numberForUNNotificationSetting:settings.alertSetting];
        settingsDictionary[@"badge"] =
            [NotifeeCoreUtil numberForUNNotificationSetting:settings.badgeSetting];
        settingsDictionary[@"sound"] =
            [NotifeeCoreUtil numberForUNNotificationSetting:settings.soundSetting];
        settingsDictionary[@"carPlay"] =
            [NotifeeCoreUtil numberForUNNotificationSetting:settings.carPlaySetting];
        settingsDictionary[@"lockScreen"] =
            [NotifeeCoreUtil numberForUNNotificationSetting:settings.lockScreenSetting];
        settingsDictionary[@"notificationCenter"] =
            [NotifeeCoreUtil numberForUNNotificationSetting:settings.notificationCenterSetting];
        block(nil, settingsDictionary);
      }];
}

+ (void)getInitialNotification:(notifeeMethodNSDictionaryBlock)block {
  block(nil, [[NotifeeCoreUNUserNotificationCenter instance] getInitialNotification]);
}

+ (void)setBadgeCount:(NSInteger)count withBlock:(notifeeMethodVoidBlock)block {
  if (![NotifeeCoreUtil isAppExtension]) {
    // If count is 0, set to -1 instead to avoid notifications in tray being cleared
    NSInteger newCount = count == 0 ? -1 : count;
    UIApplication *application = [NotifeeCoreUtil notifeeUIApplication];
    [application setApplicationIconBadgeNumber:newCount];
  }
  block(nil);
}

+ (void)getBadgeCount:(notifeeMethodNSIntegerBlock)block {
  if (![NotifeeCoreUtil isAppExtension]) {
    UIApplication *application = [NotifeeCoreUtil notifeeUIApplication];
    NSInteger badgeCount = application.applicationIconBadgeNumber;

    block(nil, badgeCount == -1 ? 0 : badgeCount);
  }
}

+ (void)incrementBadgeCount:(NSInteger)incrementBy withBlock:(notifeeMethodVoidBlock)block {
  if (![NotifeeCoreUtil isAppExtension]) {
    UIApplication *application = [NotifeeCoreUtil notifeeUIApplication];
    NSInteger currentCount = application.applicationIconBadgeNumber;
    // If count is -1, set currentCount to 0 before incrementing
    if (currentCount == -1) {
      currentCount = 0;
    }

    NSInteger newCount = currentCount + incrementBy;

    [application setApplicationIconBadgeNumber:newCount];
    block(nil);
  }
}

+ (void)decrementBadgeCount:(NSInteger)decrementBy withBlock:(notifeeMethodVoidBlock)block {
  if (![NotifeeCoreUtil isAppExtension]) {
    UIApplication *application = [NotifeeCoreUtil notifeeUIApplication];
    NSInteger currentCount = application.applicationIconBadgeNumber;
    NSInteger newCount = currentCount - decrementBy;
    // If count is 0 or less, set to -1 instead to avoid notifications in tray being cleared
    if (newCount < 1) {
      newCount = -1;
    }
    [application setApplicationIconBadgeNumber:newCount];
  }

  block(nil);
}

+ (nullable instancetype)notifeeUIApplication {
  return [NotifeeCoreUtil notifeeUIApplication];
};

+ (void)populateNotificationContent:(UNNotificationRequest *)request
                        withContent:(UNMutableNotificationContent *)content
                 withContentHandler:(void (^)(UNNotificationContent *_Nonnull))contentHandler {
  return [[NotifeeCoreExtensionHelper instance] populateNotificationContent:request
                                                                withContent:content
                                                         withContentHandler:contentHandler];
};

@end
