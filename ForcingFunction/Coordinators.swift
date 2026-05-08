//
//  Coordinators.swift
//  ForcingFunction
//

import Foundation
import UserNotifications

protocol NotificationCoordinator {
    func scheduleCompletionNotification(remainingSeconds: Int, sessionType: SessionType)
    func cancelAllPendingNotifications()
}

protocol LiveActivityCoordinator {
    var hasActiveActivity: Bool { get }
    func start(sessionId: UUID, sessionType: SessionType, totalDurationSeconds: Int, remainingSeconds: Int, startTime: Date, pausedDuration: TimeInterval)
    func update(remainingSeconds: Int, timerState: TimerState, sessionType: SessionType, startTime: Date, pausedDuration: TimeInterval)
    func reconnectOrStart(sessionId: UUID, sessionType: SessionType, totalDurationSeconds: Int, remainingSeconds: Int, startTime: Date, pausedDuration: TimeInterval, timerState: TimerState)
    func end()
}

protocol BackgroundTaskCoordinator {
    func startBackgroundUpdates(_ handler: @escaping () -> Void)
    func stopBackgroundUpdates()
}

protocol WidgetSyncCoordinator {
    func updateWidgetData()
}

// MARK: - Default adapters (wrap existing singletons)

final class DefaultNotificationCoordinator: NotificationCoordinator {
    func scheduleCompletionNotification(remainingSeconds: Int, sessionType: SessionType) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let content = UNMutableNotificationContent()
        content.title = "Session complete"
        content.body = sessionType == .work
            ? "Focus session complete. Take a break."
            : "Break over. Ready for the next session?"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, remainingSeconds)), repeats: false)
        let request = UNNotificationRequest(identifier: "pomodoro-timer", content: content, trigger: trigger)
        center.add(request) { error in
            if let error { print("Notification scheduling error: \(error)") }
        }
    }

    func cancelAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

final class DefaultLiveActivityCoordinator: LiveActivityCoordinator {
    private let impl: LiveActivityManager
    init(_ impl: LiveActivityManager = .shared) { self.impl = impl }

    var hasActiveActivity: Bool { impl.hasActiveActivity }

    func start(sessionId: UUID, sessionType: SessionType, totalDurationSeconds: Int, remainingSeconds: Int, startTime: Date, pausedDuration: TimeInterval) {
        impl.startActivity(
            sessionId: sessionId,
            sessionType: sessionType,
            totalDurationSeconds: totalDurationSeconds,
            remainingSeconds: remainingSeconds,
            startTime: startTime,
            pausedDuration: pausedDuration
        )
    }

    func update(remainingSeconds: Int, timerState: TimerState, sessionType: SessionType, startTime: Date, pausedDuration: TimeInterval) {
        impl.updateActivity(
            remainingSeconds: remainingSeconds,
            timerState: timerState,
            sessionType: sessionType,
            startTime: startTime,
            pausedDuration: pausedDuration
        )
    }

    func reconnectOrStart(sessionId: UUID, sessionType: SessionType, totalDurationSeconds: Int, remainingSeconds: Int, startTime: Date, pausedDuration: TimeInterval, timerState: TimerState) {
        impl.reconnectOrStartActivity(
            sessionId: sessionId,
            sessionType: sessionType,
            totalDurationSeconds: totalDurationSeconds,
            remainingSeconds: remainingSeconds,
            startTime: startTime,
            pausedDuration: pausedDuration,
            timerState: timerState
        )
    }

    func end() {
        impl.endActivity()
    }
}

final class DefaultBackgroundTaskCoordinator: BackgroundTaskCoordinator {
    private let impl: BackgroundTaskManager
    init(_ impl: BackgroundTaskManager = .shared) { self.impl = impl }

    func startBackgroundUpdates(_ handler: @escaping () -> Void) {
        impl.startBackgroundUpdates(updateHandler: handler)
    }

    func stopBackgroundUpdates() {
        impl.stopBackgroundUpdates()
    }
}

struct DefaultWidgetSyncCoordinator: WidgetSyncCoordinator {
    func updateWidgetData() {
        WidgetDataManager.shared.updateWidgetData()
    }
}

