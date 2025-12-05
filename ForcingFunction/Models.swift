//
//  Models.swift
//  ForcingFunction
//
//  Models and enums for the Pomodoro timer app
//

import Foundation
import SwiftUI

/// Represents the type of session in the Pomodoro cycle
enum SessionType: String, CaseIterable, Codable {
    case work = "Work"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"
    
    var displayName: String {
        return self.rawValue
    }
}

/// Theme color options for the app accent
enum ThemeColor: String, CaseIterable {
    case red = "Red"
    case blue = "Blue"
    case green = "Green"
    
    var colorValue: String {
        return self.rawValue.lowercased()
    }
    
    /// Returns the AppTheme instance for this theme color
    var theme: AppTheme {
        AppTheme(accentColor: self)
    }
}

// MARK: - App Theme System

/// Centralized theme system for app-wide styling
/// All colors used throughout the app should come from this struct
struct AppTheme {
    // MARK: - Accent Colors
    let accentColor: Color
    let accentColorLight: Color
    let accentColorDark: Color
    
    // MARK: - Background Colors
    let backgroundPrimary: Color
    let backgroundSecondary: Color
    let backgroundTertiary: Color
    let backgroundCard: Color
    let backgroundOverlay: Color
    
    // MARK: - Text Colors
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let textDisabled: Color
    
    // MARK: - Border & Divider Colors
    let borderPrimary: Color
    let borderSecondary: Color
    let divider: Color
    
    // MARK: - Button Colors
    let buttonPrimary: Color
    let buttonPrimaryText: Color
    let buttonSecondary: Color
    let buttonSecondaryText: Color
    let buttonDisabled: Color
    let buttonDisabledText: Color
    
    // MARK: - Status Colors
    let success: Color
    let warning: Color
    let error: Color
    let info: Color
    
    // MARK: - Interactive Colors
    let interactive: Color
    let interactivePressed: Color
    
    // MARK: - Shadow Colors
    let shadowLight: Color
    let shadowMedium: Color
    let shadowHeavy: Color
    
    /// Initialize theme with accent color
    init(accentColor: ThemeColor) {
        // Set accent colors based on theme
        switch accentColor {
        case .red:
            self.accentColor = .red
            self.accentColorLight = Color(red: 1.0, green: 0.4, blue: 0.4)
            self.accentColorDark = Color(red: 0.7, green: 0.0, blue: 0.0)
        case .blue:
            self.accentColor = .blue
            self.accentColorLight = Color(red: 0.4, green: 0.6, blue: 1.0)
            self.accentColorDark = Color(red: 0.0, green: 0.2, blue: 0.7)
        case .green:
            self.accentColor = .green
            self.accentColorLight = Color(red: 0.4, green: 0.9, blue: 0.4)
            self.accentColorDark = Color(red: 0.0, green: 0.6, blue: 0.0)
        }
        
        // Dark theme background colors (app uses dark theme)
        self.backgroundPrimary = .black
        self.backgroundSecondary = Color(white: 0.1)
        self.backgroundTertiary = Color(white: 0.15)
        self.backgroundCard = Color(white: 0.12)
        self.backgroundOverlay = Color.black.opacity(0.8)
        
        // Text colors for dark theme
        self.textPrimary = .white
        self.textSecondary = Color.white.opacity(0.7)
        self.textTertiary = Color.white.opacity(0.5)
        self.textDisabled = Color.white.opacity(0.4)
        
        // Border colors
        self.borderPrimary = Color.white.opacity(0.2)
        self.borderSecondary = Color.white.opacity(0.1)
        self.divider = Color.white.opacity(0.15)
        
        // Button colors
        self.buttonPrimary = self.accentColor
        self.buttonPrimaryText = .white
        self.buttonSecondary = Color(white: 0.2)
        self.buttonSecondaryText = .white
        self.buttonDisabled = Color(white: 0.15)
        self.buttonDisabledText = Color.white.opacity(0.4)
        
        // Status colors (consistent across themes)
        self.success = .green
        self.warning = .orange
        self.error = .red
        self.info = .blue
        
        // Interactive colors
        self.interactive = self.accentColor
        self.interactivePressed = self.accentColorDark
        
        // Shadow colors
        self.shadowLight = Color.black.opacity(0.2)
        self.shadowMedium = Color.black.opacity(0.3)
        self.shadowHeavy = Color.black.opacity(0.5)
    }
    
    /// Get a color with opacity applied
    func color(_ color: Color, opacity: Double) -> Color {
        color.opacity(opacity)
    }
    
    /// Get accent color with opacity
    func accent(opacity: Double = 1.0) -> Color {
        accentColor.opacity(opacity)
    }
    
    /// Get text color with opacity
    func text(_ level: TextLevel = .primary, opacity: Double = 1.0) -> Color {
        let baseColor: Color
        switch level {
        case .primary:
            baseColor = textPrimary
        case .secondary:
            baseColor = textSecondary
        case .tertiary:
            baseColor = textTertiary
        case .disabled:
            baseColor = textDisabled
        }
        return baseColor.opacity(opacity)
    }
    
    /// Get background color
    func background(_ level: BackgroundLevel = .primary) -> Color {
        switch level {
        case .primary:
            return backgroundPrimary
        case .secondary:
            return backgroundSecondary
        case .tertiary:
            return backgroundTertiary
        case .card:
            return backgroundCard
        case .overlay:
            return backgroundOverlay
        }
    }
}

/// Text color levels
enum TextLevel {
    case primary
    case secondary
    case tertiary
    case disabled
}

/// Background color levels
enum BackgroundLevel {
    case primary
    case secondary
    case tertiary
    case card
    case overlay
}

/// Timer state
enum TimerState {
    case idle
    case running
    case paused
    case completed
}

/// Settings model - all settings are stored using @AppStorage
/// This struct provides default values and computed properties
struct AppSettings {
    // Default values - can be changed here
    static let defaultPomodoroMinutes: Double = 0.0
    static let defaultShortBreakMinutes: Double = 5
    static let defaultLongBreakMinutes: Double = 15
    static let defaultPomodorosBeforeLongBreak: Int = 4
    static let defaultSnapIncrement: Double = 1.0  // 1-minute increments for precise control
    static let defaultMinMinutes: Double = 0.0
    static let defaultMaxMinutes: Double = 60.0  // 1 full rotation (60 minutes)
}

// MARK: - Pomodoro Session Data Models

/// Represents an event that occurred during a pomodoro session
struct SessionEvent: Codable {
    let timestamp: Date
    let eventType: EventType
}

/// Types of events that can occur during a session
enum EventType: String, Codable {
    case started
    case paused
    case resumed
    case completed
    case cancelled
}

/// Status of a pomodoro session
enum SessionStatus: String, Codable {
    case running
    case paused
    case completed
    case cancelled
}

// MARK: - Category Models

/// Color options for categories
enum CategoryColor: String, CaseIterable, Codable {
    case red = "Red"
    case blue = "Blue"
    case green = "Green"
    case orange = "Orange"
    case purple = "Purple"
    case pink = "Pink"
    case teal = "Teal"
    case yellow = "Yellow"
    case indigo = "Indigo"
    case gray = "Gray"
    
    var color: Color {
        switch self {
        case .red: return .red
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        case .pink: return .pink
        case .teal: return .teal
        case .yellow: return .yellow
        case .indigo: return .indigo
        case .gray: return .gray
        }
    }
}

/// Represents a category for pomodoro sessions
struct Category: Codable, Identifiable {
    let id: UUID
    var name: String
    var color: CategoryColor
    let createdDate: Date
    var isArchived: Bool
    var archivedDate: Date?
    
    init(
        id: UUID = UUID(),
        name: String,
        color: CategoryColor,
        createdDate: Date = Date(),
        isArchived: Bool = false,
        archivedDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.createdDate = createdDate
        self.isArchived = isArchived
        self.archivedDate = archivedDate
    }
}

/// Represents a complete pomodoro session with all its data
struct PomodoroSession: Codable, Identifiable {
    let id: UUID
    let sessionType: SessionType
    let startTime: Date
    var endTime: Date?
    let plannedDurationMinutes: Double
    var status: SessionStatus
    var events: [SessionEvent]
    let wasAutoStarted: Bool
    var categoryId: UUID?
    
    /// Computed actual duration in minutes (nil if session hasn't ended)
    var actualDurationMinutes: Double? {
        guard let endTime = endTime else { return nil }
        return (endTime.timeIntervalSince(startTime) / 60.0)
    }
    
    /// Total time spent in the session (accounting for pauses)
    var activeDurationMinutes: Double? {
        guard let endTime = endTime else { return nil }
        
        var totalPausedTime: TimeInterval = 0
        var pauseStartTime: Date?
        
        for event in events.sorted(by: { $0.timestamp < $1.timestamp }) {
            if event.eventType == .paused {
                pauseStartTime = event.timestamp
            } else if event.eventType == .resumed, let pauseStart = pauseStartTime {
                totalPausedTime += event.timestamp.timeIntervalSince(pauseStart)
                pauseStartTime = nil
            }
        }
        
        // If still paused at end, add time until end
        if let pauseStart = pauseStartTime {
            totalPausedTime += endTime.timeIntervalSince(pauseStart)
        }
        
        let totalTime = endTime.timeIntervalSince(startTime)
        return (totalTime - totalPausedTime) / 60.0
    }
    
    init(
        id: UUID = UUID(),
        sessionType: SessionType,
        startTime: Date = Date(),
        endTime: Date? = nil,
        plannedDurationMinutes: Double,
        status: SessionStatus = .running,
        events: [SessionEvent] = [],
        wasAutoStarted: Bool = false,
        categoryId: UUID? = nil
    ) {
        self.id = id
        self.sessionType = sessionType
        self.startTime = startTime
        self.endTime = endTime
        self.plannedDurationMinutes = plannedDurationMinutes
        self.status = status
        self.events = events
        self.wasAutoStarted = wasAutoStarted
        self.categoryId = categoryId
    }
}

// MARK: - Task Models

/// Represents a task with pomodoro time tracking
struct PomodoroTask: Codable, Identifiable {
    let id: UUID
    var title: String
    var notes: String?
    var isCompleted: Bool
    var totalPomodoroMinutes: Double  // Accumulated time in minutes
    let createdDate: Date
    var completedDate: Date?
    var isArchived: Bool  // Same as isCompleted, but explicit for clarity
    
    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        isCompleted: Bool = false,
        totalPomodoroMinutes: Double = 0.0,
        createdDate: Date = Date(),
        completedDate: Date? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.totalPomodoroMinutes = totalPomodoroMinutes
        self.createdDate = createdDate
        self.completedDate = completedDate
        self.isArchived = isArchived
    }
    
    /// Format accumulated time as "Xh Ym" or "Ym"
    var formattedTime: String {
        let totalMinutes = Int(totalPomodoroMinutes)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes)m"
        }
    }
}

