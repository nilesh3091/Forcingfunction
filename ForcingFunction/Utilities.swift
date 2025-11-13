//
//  Utilities.swift
//  ForcingFunction
//
//  Utility functions for angle calculations and conversions
//

import Foundation
import SwiftUI
import AudioToolbox

/// Utility functions for converting between angles and minutes
struct AngleUtilities {
    
    /// Convert minutes to angle in degrees (0° = top, clockwise)
    /// Supports continuous rotation: each 60 minutes = 360°
    /// Minutes range: minMinutes to maxMinutes (0-120)
    /// Note: Rectangle points up by default, so 0° = up (12 o'clock)
    static func minutesToAngle(_ minutes: Double, minMinutes: Double, maxMinutes: Double) -> Double {
        let clampedMinutes = max(minMinutes, min(maxMinutes, minutes))
        // Each 60 minutes = 360° rotation
        // 0 minutes = 0° (top/12 o'clock)
        // 60 minutes = 360° (back to top, but 60 minutes)
        // 75 minutes = 450° (90° into second rotation)
        // 120 minutes = 720° (back to top, but 120 minutes)
        let angle = (clampedMinutes / 60.0) * 360.0
        return angle
    }
    
    /// Convert angle in degrees to minutes
    /// Supports continuous rotation: angle can be > 360° for multiple rotations
    /// Returns minutes clamped to minMinutes...maxMinutes range
    /// Note: Rectangle points up at 0°, so 0° = top (12 o'clock)
    static func angleToMinutes(_ angle: Double, minMinutes: Double, maxMinutes: Double, snapIncrement: Double) -> Double {
        // Handle negative angles
        var normalizedAngle = angle
        while normalizedAngle < 0 {
            normalizedAngle += 360.0
        }
        
        // Convert cumulative angle to minutes
        // Each 360° = 60 minutes
        // 0° = 0 minutes (top)
        // 360° = 60 minutes (back to top, but 60 minutes)
        // 450° = 75 minutes (90° into second rotation)
        // 720° = 120 minutes (back to top, but 120 minutes)
        let minutesFloat = (normalizedAngle / 360.0) * 60.0
        
        // Round to nearest snap increment, then round to whole minutes
        let snapped = round(minutesFloat / snapIncrement) * snapIncrement
        let wholeMinutes = round(snapped)  // Ensure whole minutes (no seconds)
        
        // Clamp to valid range
        return max(minMinutes, min(maxMinutes, wholeMinutes))
    }
    
    /// Calculate angle from touch point relative to center
    /// Returns angle where 0° = top (12 o'clock), clockwise
    static func angleFromPoint(_ point: CGPoint, center: CGPoint) -> Double {
        let dx = point.x - center.x
        let dy = point.y - center.y
        // atan2 returns angle in radians, convert to degrees
        // atan2(dy, dx): top = -90°, right = 0°, bottom = 90°, left = 180°
        // We want: top = 0°, right = 90°, bottom = 180°, left = 270°
        // So add 90° to convert
        let radians = atan2(dy, dx)
        let degrees = radians * 180.0 / .pi
        // Convert to our coordinate system: 0° at top, clockwise
        var adjustedDegrees = degrees + 90.0
        // Normalize to 0-360 range
        if adjustedDegrees < 0 {
            adjustedDegrees += 360.0
        }
        return adjustedDegrees
    }
    
    /// Format time as mm:ss or mm if whole minutes
    static func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        
        if seconds == 0 {
            return "\(minutes):00"
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    /// Format time as mm:00 (always whole minutes, no seconds)
    static func formatTimeMinutesOnly(_ totalSeconds: Int) -> String {
        // Round to nearest minute
        let roundedSeconds = Int(round(Double(totalSeconds) / 60.0)) * 60
        let minutes = roundedSeconds / 60
        return "\(minutes):00"
    }
    
    /// Format time as "XH YM FOCUS" style
    static func formatFocusTime(_ totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)H \(minutes)M FOCUS"
        } else {
            return "\(minutes)M FOCUS"
        }
    }
}

/// Haptic feedback utility
struct HapticManager {
    static func playSelection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    static func playImpact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    static func playNotification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}

/// Sound player utility
struct SoundManager {
    static func playCompletionSound() {
        // Use system sound for completion
        AudioServicesPlaySystemSound(1057) // System sound ID for alert
    }
}
