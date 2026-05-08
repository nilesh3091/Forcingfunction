//
//  Models.swift
//  ForcingFunction
//
//  Models and enums for the Pomodoro timer app
//

import Foundation
import SwiftUI
import UIKit
import SwiftData

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
    /// Work / focus / global accent.
    let workAccent: Color
    /// Short & long break sessions.
    let breakAccent: Color
    /// End / destructive outline actions (muted red).
    let destructiveAccent: Color
    let accentColor: Color

    static let standard = AppTheme()

    private init() {
        let goldReadable = AppTheme.dyn(light: (0.72, 0.58, 0.18), dark: (1.0, 0.898, 0.522))
        let burn = AppTheme.dyn(light: (0.85, 0.30, 0.25), dark: (0.95, 0.38, 0.33))
        let exercise = AppTheme.dyn(light: (0.30, 0.75, 0.45), dark: (0.38, 0.84, 0.54))

        self.workAccent = goldReadable
        self.breakAccent = exercise
        self.destructiveAccent = burn
        self.accentColor = goldReadable
    }

    private static func dyn(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { trait in
            let c = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat(c.0), green: CGFloat(c.1), blue: CGFloat(c.2), alpha: 1)
        })
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

/// Represents a complete pomodoro session with all its data
struct PomodoroSession: Codable, Identifiable {
    let id: UUID
    let sessionType: SessionType
    let startTime: Date
    var endTime: Date?
    let plannedDurationMinutes: Double
    var status: SessionStatus
    var events: [SessionEvent]

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

    /// Single source of truth for “how long was this session, really?” (minutes).
    var billedMinutes: Double {
        if let active = activeDurationMinutes { return max(0, active) }
        if let actual = actualDurationMinutes { return max(0, actual) }
        if let endTime { return max(0, endTime.timeIntervalSince(startTime) / 60.0) }
        return max(0, plannedDurationMinutes)
    }
    
    init(
        id: UUID = UUID(),
        sessionType: SessionType,
        startTime: Date = Date(),
        endTime: Date? = nil,
        plannedDurationMinutes: Double,
        status: SessionStatus = .running,
        events: [SessionEvent] = [],
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
        self.title = title
        self.tag = tag
        self.tagColor = tagColor
        self.projectId = projectId
        self.projectTagId = projectTagId
    }
}

extension PomodoroSession {
    init?(sd record: SDFocusSession) {
        let kind = SessionType(rawValue: record.kindRaw) ?? .work
        let status = SessionStatus(rawValue: record.statusRaw) ?? .running

        let events: [SessionEvent] = record.events
            .sorted(by: { $0.timestamp < $1.timestamp })
            .map { SessionEvent(timestamp: $0.timestamp, eventType: EventType(rawValue: $0.typeRaw) ?? .started) }

        self.init(
            id: record.id,
            sessionType: kind,
            startTime: record.startTime,
            endTime: record.endTime,
            plannedDurationMinutes: record.plannedMinutes,
            status: status,
            events: events,
            title: record.title,
            tag: nil,
            tagColor: nil,
            projectId: record.project?.id,
            projectTagId: record.tag?.id
        )
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

// MARK: - SwiftData (Phase 2)

/// SwiftData-backed persistence models.
///
/// NOTE: Phase 2 introduces these alongside the legacy JSON Codable structs.
/// The app switches read/write paths over in later Phase 2 steps.
@Model
final class SDProject {
    @Attribute(.unique) var id: UUID
    var name: String
    /// Stored as `CategoryColor.rawValue` to avoid SwiftData enum persistence edge cases.
    var colorRaw: String
    var goalHours: Double
    var createdDate: Date
    var isArchived: Bool

    @Relationship(deleteRule: .cascade, inverse: \SDProjectTag.project) var tags: [SDProjectTag]
    @Relationship(inverse: \SDFocusSession.project) var sessions: [SDFocusSession]

    init(
        id: UUID = UUID(),
        name: String,
        colorRaw: String,
        goalHours: Double = 10_000,
        createdDate: Date = Date(),
        isArchived: Bool = false,
        tags: [SDProjectTag] = []
    ) {
        self.id = id
        self.name = name
        self.colorRaw = colorRaw
        self.goalHours = goalHours
        self.createdDate = createdDate
        self.isArchived = isArchived
        self.tags = tags
        self.sessions = []
    }

    var color: CategoryColor {
        CategoryColor(rawValue: colorRaw) ?? .teal
    }
}

@Model
final class SDProjectTag {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdDate: Date

    @Relationship(deleteRule: .nullify) var project: SDProject?
    @Relationship(deleteRule: .nullify) var parent: SDProjectTag?
    @Relationship(deleteRule: .cascade, inverse: \SDProjectTag.parent) var children: [SDProjectTag]

    init(
        id: UUID = UUID(),
        name: String,
        createdDate: Date = Date(),
        project: SDProject? = nil,
        parent: SDProjectTag? = nil,
        children: [SDProjectTag] = []
    ) {
        self.id = id
        self.name = name
        self.createdDate = createdDate
        self.project = project
        self.parent = parent
        self.children = children
    }
}

@Model
final class SDFocusSession {
    @Attribute(.unique) var id: UUID
    var startTime: Date
    var endTime: Date?
    var plannedMinutes: Double
    /// Stored as `SessionStatus.rawValue`.
    var statusRaw: String
    /// Stored as `SessionType.rawValue` (Phase 1 kept `SessionType` unchanged).
    var kindRaw: String
    var title: String?

    @Relationship(deleteRule: .nullify) var project: SDProject?
    @Relationship(deleteRule: .nullify) var tag: SDProjectTag?
    @Relationship(deleteRule: .cascade, inverse: \SDSessionEventRecord.session) var events: [SDSessionEventRecord]

    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date? = nil,
        plannedMinutes: Double,
        statusRaw: String,
        kindRaw: String,
        title: String? = nil,
        project: SDProject? = nil,
        tag: SDProjectTag? = nil,
        events: [SDSessionEventRecord] = []
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.plannedMinutes = plannedMinutes
        self.statusRaw = statusRaw
        self.kindRaw = kindRaw
        self.title = title
        self.project = project
        self.tag = tag
        self.events = events
    }

    var status: SessionStatus {
        SessionStatus(rawValue: statusRaw) ?? .running
    }

    var kind: SessionType {
        SessionType(rawValue: kindRaw) ?? .work
    }
}

@Model
final class SDSessionEventRecord {
    var timestamp: Date
    /// Stored as `EventType.rawValue`.
    var typeRaw: String

    @Relationship(deleteRule: .nullify) var session: SDFocusSession?

    init(timestamp: Date, typeRaw: String, session: SDFocusSession? = nil) {
        self.timestamp = timestamp
        self.typeRaw = typeRaw
        self.session = session
    }

    var type: EventType {
        EventType(rawValue: typeRaw) ?? .started
    }
}

