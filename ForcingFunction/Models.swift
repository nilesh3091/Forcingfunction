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

// MARK: - App Theme System

/// Centralized theme system for app-wide styling
/// All colors used throughout the app should come from this struct
struct AppTheme {
    /// Work / focus / global accent (~`#42d7ff`).
    let workAccent: Color
    /// Short & long break sessions (~`#39ff14`).
    let breakAccent: Color
    /// End / destructive outline actions (muted red).
    let destructiveAccent: Color

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

    /// Fixed exam-style palette on deep charcoal (HUD canvas).
    static let standard = AppTheme()

    private init() {
        let work = Color(red: 66.0 / 255.0, green: 215.0 / 255.0, blue: 1.0)
        let breakNeon = Color(red: 57.0 / 255.0, green: 1.0, blue: 20.0 / 255.0)
        let destructive = Color(red: 0.78, green: 0.26, blue: 0.30)

        self.workAccent = work
        self.breakAccent = breakNeon
        self.destructiveAccent = destructive

        self.accentColor = work
        self.accentColorLight = Color(red: 0.48, green: 0.90, blue: 1.0)
        self.accentColorDark = Color(red: 0.0, green: 0.48, blue: 0.64)
        
        // Apple-dark base: deep charcoal / cool navy (HUD canvas)
        self.backgroundPrimary = Color(red: 0.043, green: 0.055, blue: 0.078)
        self.backgroundSecondary = Color(red: 0.059, green: 0.071, blue: 0.094)
        self.backgroundTertiary = Color(red: 0.078, green: 0.090, blue: 0.118)
        self.backgroundCard = Color(red: 0.067, green: 0.078, blue: 0.102)
        self.backgroundOverlay = Color(red: 0.02, green: 0.03, blue: 0.05).opacity(0.92)
        
        self.textPrimary = Color(red: 0.92, green: 0.94, blue: 0.97)
        self.textSecondary = Color(red: 0.62, green: 0.68, blue: 0.76)
        self.textTertiary = Color(red: 0.42, green: 0.48, blue: 0.56)
        self.textDisabled = Color(red: 0.32, green: 0.36, blue: 0.40)
        
        self.borderPrimary = Color.white.opacity(0.11)
        self.borderSecondary = Color(red: 0.55, green: 0.65, blue: 0.78).opacity(0.14)
        self.divider = Color.white.opacity(0.08)
        
        self.buttonPrimary = self.accentColor
        self.buttonPrimaryText = Color(red: 0.98, green: 0.99, blue: 1.0)
        self.buttonSecondary = Color(red: 0.10, green: 0.12, blue: 0.16)
        self.buttonSecondaryText = Color(red: 0.72, green: 0.76, blue: 0.82)
        self.buttonDisabled = Color(red: 0.08, green: 0.09, blue: 0.11)
        self.buttonDisabledText = Color(red: 0.38, green: 0.42, blue: 0.46)
        
        // Progress / break-style highlights (neon green)
        self.success = breakNeon
        self.warning = Color(red: 1.0, green: 0.72, blue: 0.28)
        self.error = Color(red: 1.0, green: 0.38, blue: 0.40)
        self.info = Color(red: 0.45, green: 0.78, blue: 1.0)
        
        self.interactive = self.accentColor
        self.interactivePressed = self.accentColorDark
        
        self.shadowLight = Color.black.opacity(0.35)
        self.shadowMedium = Color.black.opacity(0.45)
        self.shadowHeavy = Color.black.opacity(0.60)
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
    /// Default daily focus target (2 h) when unset.
    static let defaultDailyFocusGoalMinutes: Int = 120
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
    
    /// Minimum focused work minutes before a work session is kept (history, stats, widgets).
    static let minimumRecordedWorkMinutes: Double = 15
    
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
    var categoryId: UUID?  // Optional category assignment
    
    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        isCompleted: Bool = false,
        totalPomodoroMinutes: Double = 0.0,
        createdDate: Date = Date(),
        completedDate: Date? = nil,
        isArchived: Bool = false,
        categoryId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.totalPomodoroMinutes = totalPomodoroMinutes
        self.createdDate = createdDate
        self.completedDate = completedDate
        self.isArchived = isArchived
        self.categoryId = categoryId
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

