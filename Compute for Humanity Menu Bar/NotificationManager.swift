//
//  NotificationManager.swift
//  Compute for Humanity
//
//  Created by Jacob Evelyn on 2/7/16.
//  Copyright © 2016 Jacob Evelyn. All rights reserved.
//

class NotificationManager: NSObject, NSUserNotificationCenterDelegate {
    let notificationThrottleInterval: NSTimeInterval = 6
    
    var nextNotificationDeliveryDate = NSDate()
    
    // Sends a notification with the given title and subtitle. The notification
    // is guaranteed to be displayed, even if the app is in focus.
    func sendNotification(title: String, subtitle: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.subtitle = subtitle
        notification.soundName = NSUserNotificationDefaultSoundName
        notification.deliveryDate = nextNotificationDeliveryDate
        NSUserNotificationCenter.defaultUserNotificationCenter().scheduleNotification(notification)
        
        // There doesn't appear to be a way to open the status menu
        // programmatically (and thus open it when the notification is
        // clicked), but that would be nice if it becomes possible in
        // the future. This would allow users to see their achievements/etc.
        // by clicking the alert.
        
        // Update the time the next notification should be delivered at, by taking the
        // later of the next notification delivery date and the current time, and adding
        // our delay interval.
        nextNotificationDeliveryDate = (nextNotificationDeliveryDate.laterDate(NSDate())).dateByAddingTimeInterval(notificationThrottleInterval)
    }
    
    // We want all notifications to be visible, always.
    func userNotificationCenter(center: NSUserNotificationCenter, shouldPresentNotification notification: NSUserNotification) -> Bool {
        return true
    }
}