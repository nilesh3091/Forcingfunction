//
//  ForcingFunctionWidgetLiveActivity.swift
//  ForcingFunctionWidget
//
//  Created by Nilesh Kumar on 22/11/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Shared Helper Functions

/// Format seconds as MM:SS string
private func formatTime(_ totalSeconds: Int) -> String {
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%d:%02d", minutes, seconds)
}

/// Calculate remaining seconds from timer state
/// If paused, returns stored remainingSeconds. If running, calculates from startTime.
private func calculateRemainingSeconds(from context: ActivityViewContext<ForcingFunctionWidgetAttributes>) -> Int {
    // If paused, use the stored remainingSeconds
    if context.state.timerState == "paused" {
        return context.state.remainingSeconds
    }
    
    // If running, calculate from startTime
    let now = Date()
    let elapsed = now.timeIntervalSince(context.state.startTime)
    let adjustedElapsed = elapsed - context.state.pausedDuration
    let calculatedRemaining = max(0, context.attributes.totalDurationSeconds - Int(adjustedElapsed))
    
    return calculatedRemaining
}

/// Calculate progress (0.0 to 1.0) from timer state
private func calculateProgress(from context: ActivityViewContext<ForcingFunctionWidgetAttributes>) -> Double {
    guard context.attributes.totalDurationSeconds > 0 else { return 0 }
    let remaining = calculateRemainingSeconds(from: context)
    let elapsed = context.attributes.totalDurationSeconds - remaining
    return min(1.0, max(0.0, Double(elapsed) / Double(context.attributes.totalDurationSeconds)))
}

// MARK: - Dynamic Island Views

/// Compact trailing view showing timer text
struct CompactTimerView: View {
    let context: ActivityViewContext<ForcingFunctionWidgetAttributes>
    
    var body: some View {
        Text(formatTime(calculateRemainingSeconds(from: context)))
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.primary)
    }
}

/// Compact leading view showing progress ring icon
struct CompactSessionIconView: View {
    let context: ActivityViewContext<ForcingFunctionWidgetAttributes>
    
    private var progress: Double {
        calculateProgress(from: context)
    }
    
    var body: some View {
        ZStack {
            // Circular progress ring background
            Circle()
                .stroke(
                    Color.secondary.opacity(0.2),
                    lineWidth: 2.5
                )
            
            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.primary,
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: progress)
        }
        .frame(width: 20, height: 20)
    }
}

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
                
                // Timer display
                Text(formatTime(calculateRemainingSeconds(from: context)))
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
                    ProgressView(value: calculateProgress(from: context))
                        .tint(.blue)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(formatTime(calculateRemainingSeconds(from: context)))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } compactLeading: {
                CompactSessionIconView(context: context)
            } compactTrailing: {
                CompactTimerView(context: context)
            } minimal: {
                Image(systemName: "timer")
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
            }
            .widgetURL(URL(string: "forcingfunction://timer"))
            .keylineTint(Color.blue)
        }
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
