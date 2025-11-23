//
//  LiveActivityManager.swift
//  ForcingFunction
//
//  Manages Live Activities for the Pomodoro timer
//

import Foundation
import ActivityKit
import UserNotifications

class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<ForcingFunctionWidgetAttributes>?
    private var pushToken: Data?
    private var updateTimer: Timer?
    
    private init() {}
    
    // MARK: - Authorization Check
    
    /// Check if Live Activities are available and authorized
    func isAvailable() -> Bool {
        if #available(iOS 16.1, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        return false
    }
    
    // MARK: - Start Live Activity
    
    /// Start a new Live Activity for a timer session
    func startActivity(
        sessionId: UUID,
        sessionType: SessionType,
        totalDurationSeconds: Int,
        remainingSeconds: Int,
        startTime: Date,
        pausedDuration: TimeInterval = 0
    ) {
        guard isAvailable() else {
            print("LiveActivityManager: Live Activities not available")
            return
        }
        
        // End any existing activity first
        endActivity()
        
        let attributes = ForcingFunctionWidgetAttributes(
            sessionId: sessionId.uuidString,
            totalDurationSeconds: totalDurationSeconds,
            initialSessionType: sessionType.displayName
        )
        
        let initialState = ForcingFunctionWidgetAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            timerState: "running",
            sessionType: sessionType.displayName,
            startTime: startTime,
            pausedDuration: pausedDuration
        )
        
        do {
            let activity = try Activity<ForcingFunctionWidgetAttributes>.request(
                attributes: attributes,
                contentState: initialState,
                pushType: .token
            )
            
            currentActivity = activity
            
            // Get push token for sending updates
            Task {
                for await tokenData in activity.pushTokenUpdates {
                    self.pushToken = tokenData
                    print("LiveActivityManager: Received push token: \(tokenData.map { String(format: "%02x", $0) }.joined())")
                    // Start periodic push updates
                    await self.startPeriodicPushUpdates()
                }
            }
            
            print("LiveActivityManager: Started Live Activity with ID: \(activity.id)")
        } catch {
            print("LiveActivityManager: Failed to start Live Activity: \(error)")
        }
    }
    
    // MARK: - Update Live Activity
    
    /// Update the current Live Activity with new timer state
    func updateActivity(
        remainingSeconds: Int,
        timerState: TimerState,
        sessionType: SessionType,
        startTime: Date,
        pausedDuration: TimeInterval
    ) {
        guard let activity = currentActivity else {
            print("LiveActivityManager: No active Live Activity to update")
            return
        }
        
        let stateString: String
        switch timerState {
        case .running:
            stateString = "running"
        case .paused:
            stateString = "paused"
        default:
            stateString = "running"
        }
        
        let updatedState = ForcingFunctionWidgetAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            timerState: stateString,
            sessionType: sessionType.displayName,
            startTime: startTime,
            pausedDuration: pausedDuration
        )
        
        Task {
            await activity.update(using: updatedState)
        }
    }
    
    /// Send push notification update to Live Activity
    private func sendPushUpdate(
        remainingSeconds: Int,
        timerState: String,
        sessionType: String,
        startTime: Date,
        pausedDuration: TimeInterval
    ) {
        guard let token = pushToken else {
            print("LiveActivityManager: No push token available")
            return
        }
        
        // Create push notification payload for Live Activity update
        let contentState = ForcingFunctionWidgetAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            timerState: timerState,
            sessionType: sessionType,
            startTime: startTime,
            pausedDuration: pausedDuration
        )
        
        // Encode the content state
        guard let encodedState = try? JSONEncoder().encode(contentState) else {
            print("LiveActivityManager: Failed to encode content state")
            return
        }
        
        // For local-only apps, we'll use ActivityKit's update method directly
        // Push notifications require a server, so we'll use a hybrid approach:
        // - Use pushType: .token to enable push capability
        // - Send updates via ActivityKit.update when app is active
        // - Use background tasks to send updates when backgrounded
        
        // This will be handled by the periodic update mechanism
        Task {
            await updateActivityDirectly(
                remainingSeconds: remainingSeconds,
                timerState: timerState,
                sessionType: sessionType,
                startTime: startTime,
                pausedDuration: pausedDuration
            )
        }
    }
    
    /// Update activity directly (fallback when push isn't available)
    private func updateActivityDirectly(
        remainingSeconds: Int,
        timerState: String,
        sessionType: String,
        startTime: Date,
        pausedDuration: TimeInterval
    ) async {
        guard let activity = currentActivity else { return }
        
        let updatedState = ForcingFunctionWidgetAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            timerState: timerState,
            sessionType: sessionType,
            startTime: startTime,
            pausedDuration: pausedDuration
        )
        
        await activity.update(using: updatedState)
    }
    
    /// Start periodic push updates (every 5 seconds when running)
    private func startPeriodicPushUpdates() async {
        // Stop existing timer
        updateTimer?.invalidate()
        updateTimer = nil
        
        // This will be called from TimerViewModel's tick() method
        // We don't need a separate timer here since the app's timer handles it
    }
    
    // MARK: - End Live Activity
    
    /// End the current Live Activity
    func endActivity() {
        updateTimer?.invalidate()
        updateTimer = nil
        
        guard let activity = currentActivity else {
            return
        }
        
        Task {
            await activity.end(dismissalPolicy: .immediate)
        }
        
        currentActivity = nil
        pushToken = nil
        print("LiveActivityManager: Ended Live Activity")
    }
    
    // MARK: - Check Activity State
    
    /// Check if there's an active Live Activity
    var hasActiveActivity: Bool {
        return currentActivity != nil
    }
}

