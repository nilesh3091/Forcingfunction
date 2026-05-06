//
//  Models.swift
//  ForcingFunction
//
//  Models and enums for the Pomodoro timer app
//

import Foundation
import SwiftUI
import UIKit

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

/// App-level appearance override.
enum AppAppearance: String, CaseIterable, Codable, Identifiable {
    case system
    case light
    case dark
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

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

    /// Warm, Atoms-inspired palette (ported from Simple Fasting Timer). Dynamic light/dark.
    static let standard = AppTheme()

    private init() {
        // Core gold — readable on both light cream and warm-dark surfaces
        let gold = Color(uiColor: UIColor(red: 1.0, green: 0.863, blue: 0.380, alpha: 1))
        let goldReadable = AppTheme.dyn(light: (0.72, 0.58, 0.18), dark: (1.0, 0.898, 0.522))
        let goldDark = Color(uiColor: UIColor(red: 0.72, green: 0.58, blue: 0.18, alpha: 1))

        // Semantic accents (fitness-style)
        let burn = AppTheme.dyn(light: (0.85, 0.30, 0.25), dark: (0.95, 0.38, 0.33))
        let exercise = AppTheme.dyn(light: (0.30, 0.75, 0.45), dark: (0.38, 0.84, 0.54))
        let stand = AppTheme.dyn(light: (0.30, 0.55, 0.95), dark: (0.44, 0.66, 1.00))

        self.workAccent = goldReadable
        self.breakAccent = exercise
        self.destructiveAccent = burn

        self.accentColor = goldReadable
        self.accentColorLight = gold
        self.accentColorDark = goldDark

        // Warm cream (light) / warm near-black (dark)
        self.backgroundPrimary   = AppTheme.dyn(light: (0.945, 0.925, 0.875), dark: (0.078, 0.074, 0.070))
        self.backgroundSecondary = AppTheme.dyn(light: (0.965, 0.948, 0.905), dark: (0.098, 0.092, 0.086))
        self.backgroundTertiary  = AppTheme.dyn(light: (0.980, 0.970, 0.950), dark: (0.118, 0.110, 0.102))
        self.backgroundCard      = AppTheme.dyn(light: (0.980, 0.970, 0.950), dark: (0.118, 0.110, 0.102))
        self.backgroundOverlay   = AppTheme.dyn(light: (0.945, 0.925, 0.875), dark: (0.050, 0.047, 0.044)).opacity(0.92)

        self.textPrimary   = AppTheme.dyn(light: (0.15, 0.15, 0.15),   dark: (0.945, 0.925, 0.875))
        self.textSecondary = AppTheme.dyn(light: (0.45, 0.45, 0.45),   dark: (0.604, 0.580, 0.541))
        self.textTertiary  = AppTheme.dyn(light: (0.58, 0.56, 0.52),   dark: (0.462, 0.442, 0.412))
        self.textDisabled  = AppTheme.dyn(light: (0.72, 0.70, 0.66),   dark: (0.322, 0.308, 0.288))

        // Hairlines: black 6% on light / white 8% on dark
        self.borderPrimary   = AppTheme.dynA(light: (0, 0, 0, 0.10),   dark: (1, 1, 1, 0.10))
        self.borderSecondary = AppTheme.dynA(light: (0, 0, 0, 0.06),   dark: (1, 1, 1, 0.08))
        self.divider         = AppTheme.dynA(light: (0, 0, 0, 0.06),   dark: (1, 1, 1, 0.08))

        self.buttonPrimary = goldReadable
        self.buttonPrimaryText = AppTheme.dyn(light: (0.12, 0.10, 0.06), dark: (0.08, 0.07, 0.04))
        self.buttonSecondary = AppTheme.dyn(light: (0.980, 0.970, 0.950), dark: (0.118, 0.110, 0.102))
        self.buttonSecondaryText = AppTheme.dyn(light: (0.15, 0.15, 0.15), dark: (0.945, 0.925, 0.875))
        self.buttonDisabled = AppTheme.dyn(light: (0.92, 0.90, 0.86), dark: (0.14, 0.13, 0.12))
        self.buttonDisabledText = AppTheme.dyn(light: (0.60, 0.58, 0.54), dark: (0.42, 0.40, 0.38))

        self.success = exercise
        self.warning = gold
        self.error = burn
        self.info = stand

        self.interactive = goldReadable
        self.interactivePressed = goldDark

        // Softer, warmer shadows
        self.shadowLight  = AppTheme.dynA(light: (0, 0, 0, 0.05), dark: (0, 0, 0, 0.28))
        self.shadowMedium = AppTheme.dynA(light: (0, 0, 0, 0.08), dark: (0, 0, 0, 0.40))
        self.shadowHeavy  = AppTheme.dynA(light: (0, 0, 0, 0.14), dark: (0, 0, 0, 0.55))
    }

    // MARK: - Dynamic color helpers
    private static func dyn(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { trait in
            let c = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat(c.0), green: CGFloat(c.1), blue: CGFloat(c.2), alpha: 1)
        })
    }
    private static func dynA(light: (Double, Double, Double, Double), dark: (Double, Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { trait in
            let c = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat(c.0), green: CGFloat(c.1), blue: CGFloat(c.2), alpha: CGFloat(c.3))
        })
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
    static let defaultMaxMinutes: Double = 240.0  // 4 hours (4 rotations; 60 minutes per rotation)
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
    
    /// Optional per-session metadata (set via the Timer "Setup" flow).
    /// These are optional to keep backward-compatible decoding for existing saved sessions.
    var title: String?
    var tag: String?
    var tagColor: CategoryColor?

    /// Project association — optional so existing sessions decode without breakage.
    var projectId: UUID?
    var projectTagId: UUID?
    
    /// Cancelled (incomplete) work sessions under this many focused minutes are discarded (history/stats).
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
        categoryId: UUID? = nil,
        title: String? = nil,
        tag: String? = nil,
        tagColor: CategoryColor? = nil,
        projectId: UUID? = nil,
        projectTagId: UUID? = nil
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
        self.title = title
        self.tag = tag
        self.tagColor = tagColor
        self.projectId = projectId
        self.projectTagId = projectTagId
    }
}

// MARK: - Project Models

/// A tag that belongs to a project. Two-level nesting: parentId == nil → top-level; otherwise sub-tag.
struct ProjectTag: Codable, Identifiable {
    let id: UUID
    var name: String
    var parentId: UUID?
    let createdDate: Date

    init(
        id: UUID = UUID(),
        name: String,
        parentId: UUID? = nil,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.parentId = parentId
        self.createdDate = createdDate
    }
}

/// A named mastery project that accumulates focus hours toward a goal (default 10,000 h).
struct Project: Codable, Identifiable {
    let id: UUID
    var name: String
    var color: CategoryColor
    var goalHours: Double
    var tags: [ProjectTag]
    let createdDate: Date
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        name: String,
        color: CategoryColor,
        goalHours: Double = 10_000,
        tags: [ProjectTag] = [],
        createdDate: Date = Date(),
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.goalHours = goalHours
        self.tags = tags
        self.createdDate = createdDate
        self.isArchived = isArchived
    }

    /// All top-level tags (no parent).
    var topLevelTags: [ProjectTag] {
        tags.filter { $0.parentId == nil }.sorted { $0.createdDate < $1.createdDate }
    }

    /// Sub-tags of a given parent tag.
    func subTags(of parentId: UUID) -> [ProjectTag] {
        tags.filter { $0.parentId == parentId }.sorted { $0.createdDate < $1.createdDate }
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

