//
//  LiveActivityAttributes.swift
//  ForcingFunction
//
//  Shared Live Activity attributes - must be included in both main app and widget extension targets
//

import Foundation
import ActivityKit

struct ForcingFunctionWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties - update these frequently
        var remainingSeconds: Int
        var timerState: String  // "running", "paused"
        var sessionType: String  // "Work", "Short Break", "Long Break"
        var startTime: Date  // When timer started (for calculating remaining time)
        var pausedDuration: TimeInterval  // Total paused time in seconds
    }

    // Fixed non-changing properties - set once when activity starts
    var sessionId: String  // UUID as string
    var totalDurationSeconds: Int
    var initialSessionType: String
}

