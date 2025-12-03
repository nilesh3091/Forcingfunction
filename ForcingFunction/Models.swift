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

