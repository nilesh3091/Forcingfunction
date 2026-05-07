//
//  NotificationDelegate.swift
//  ForcingFunction
//
//  Handles notification delivery to complete sessions when timer finishes in background
//

import Foundation
import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    private override init() {
        super.init()
    }
    
    // Called when notification is delivered while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
        
        // Post notification to trigger timer completion check
        // The TimerViewModel will handle this when it receives the notification
        NotificationCenter.default.post(name: .timerCompletedInBackground, object: nil)
    }
    
    // Called when user taps on notification or notification is delivered while app is in background
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Post notification to trigger timer completion check
        NotificationCenter.default.post(name: .timerCompletedInBackground, object: nil)
        
        completionHandler()
    }
}

extension Notification.Name {
    static let timerCompletedInBackground = Notification.Name("timerCompletedInBackground")
}

