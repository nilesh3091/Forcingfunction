//
//  LiveActivityManager.swift
//  ForcingFunction
//
//  Manages Live Activities for the Pomodoro timer
//

import Foundation
import ActivityKit

class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<ForcingFunctionWidgetAttributes>?
    
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
        remainingSeconds: Int
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
            sessionType: sessionType.displayName
        )
        
        do {
            let activity = try Activity<ForcingFunctionWidgetAttributes>.request(
                attributes: attributes,
                contentState: initialState,
                pushType: nil
            )
            
            currentActivity = activity
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
        sessionType: SessionType
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
            sessionType: sessionType.displayName
        )
        
        Task {
            await activity.update(using: updatedState)
        }
    }
    
    // MARK: - End Live Activity
    
    /// End the current Live Activity
    func endActivity() {
        guard let activity = currentActivity else {
            return
        }
        
        Task {
            await activity.end(dismissalPolicy: .immediate)
        }
        
        currentActivity = nil
        print("LiveActivityManager: Ended Live Activity")
    }
    
    // MARK: - Check Activity State
    
    /// Check if there's an active Live Activity
    var hasActiveActivity: Bool {
        return currentActivity != nil
    }
}

