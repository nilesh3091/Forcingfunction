//
//  ForcingFunctionWidgetLiveActivity.swift
//  ForcingFunctionWidget
//
//  Created by Nilesh Kumar on 22/11/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

// IMPORTANT: ForcingFunctionWidgetAttributes must be accessible from both targets
// Option 1: Add LiveActivityAttributes.swift to widget extension target in Xcode
// Option 2: Keep this definition here (current approach - works but creates duplication)

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

struct ForcingFunctionWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ForcingFunctionWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            HStack(spacing: 12) {
                // Session type icon/indicator
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.sessionType)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(context.state.timerState == "running" ? "Running" : "Paused")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Timer display - calculate from startTime if running, otherwise use remainingSeconds
                Text(formatTime(calculateRemainingSeconds(context: context)))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .activityBackgroundTint(Color.black.opacity(0.1))
            .activitySystemActionForegroundColor(Color.primary)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.sessionType)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(context.state.timerState == "running" ? "Running" : "Paused")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // Progress indicator could go here
                    ProgressView(value: progress(context: context))
                        .tint(.blue)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(formatTime(calculateRemainingSeconds(context: context)))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } compactLeading: {
                // Compact leading: Session type icon or initial
                Text(String(context.state.sessionType.prefix(1)))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            } compactTrailing: {
                // Compact trailing: Remaining time
                Text(formatTime(calculateRemainingSeconds(context: context)))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            } minimal: {
                // Minimal: Just a timer icon or dot
                Image(systemName: "timer")
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
            }
            .widgetURL(URL(string: "forcingfunction://timer"))
            .keylineTint(Color.blue)
        }
    }
    
    // Helper function to format time as MM:SS
    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // Helper function to calculate progress (0.0 to 1.0)
    private func progress(context: ActivityViewContext<ForcingFunctionWidgetAttributes>) -> Double {
        guard context.attributes.totalDurationSeconds > 0 else { return 0 }
        let remaining = calculateRemainingSeconds(context: context)
        let elapsed = context.attributes.totalDurationSeconds - remaining
        return Double(elapsed) / Double(context.attributes.totalDurationSeconds)
    }
    
    // Helper function to calculate remaining seconds from startTime if timer is running
    // Falls back to remainingSeconds if paused or if calculation fails
    private func calculateRemainingSeconds(context: ActivityViewContext<ForcingFunctionWidgetAttributes>) -> Int {
        // If paused, use the stored remainingSeconds
        if context.state.timerState == "paused" {
            return context.state.remainingSeconds
        }
        
        // If running, calculate from startTime
        let now = Date()
        let elapsed = now.timeIntervalSince(context.state.startTime)
        let adjustedElapsed = elapsed - context.state.pausedDuration
        let calculatedRemaining = max(0, context.attributes.totalDurationSeconds - Int(adjustedElapsed))
        
        // Use calculated time if it's reasonable (within 1 second of stored value or more accurate)
        // This ensures the widget stays accurate even if updates stop
        return calculatedRemaining
    }
}

extension ForcingFunctionWidgetAttributes {
    fileprivate static var preview: ForcingFunctionWidgetAttributes {
        ForcingFunctionWidgetAttributes(
            sessionId: UUID().uuidString,
            totalDurationSeconds: 1500,
            initialSessionType: "Work"
        )
    }
}

extension ForcingFunctionWidgetAttributes.ContentState {
    fileprivate static var running: ForcingFunctionWidgetAttributes.ContentState {
        ForcingFunctionWidgetAttributes.ContentState(
            remainingSeconds: 1200,
            timerState: "running",
            sessionType: "Work",
            startTime: Date(),
            pausedDuration: 0
        )
     }
     
     fileprivate static var paused: ForcingFunctionWidgetAttributes.ContentState {
         ForcingFunctionWidgetAttributes.ContentState(
             remainingSeconds: 900,
             timerState: "paused",
             sessionType: "Work",
             startTime: Date(),
             pausedDuration: 0
         )
     }
}

#Preview("Notification", as: .content, using: ForcingFunctionWidgetAttributes.preview) {
   ForcingFunctionWidgetLiveActivity()
} contentStates: {
    ForcingFunctionWidgetAttributes.ContentState.running
    ForcingFunctionWidgetAttributes.ContentState.paused
}
