//
//  Utilities.swift
//  ForcingFunction
//
//  Utility functions for angle calculations and conversions
//

import Foundation
import SwiftUI
import AudioToolbox
import SwiftData

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
        generator.prepare()
        generator.selectionChanged()
    }
    
    static func playImpact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    static func playNotification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
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

// MARK: - Repository injection (Phase 2)

protocol FocusRepository: Sendable {
    func fetchSessions(in interval: DateInterval) throws -> [SDFocusSession]
    func fetchProjects(includeArchived: Bool) throws -> [SDProject]
    func fetchProjectTags(projectId: UUID) throws -> [SDProjectTag]

    func upsertProject(
        id: UUID,
        name: String,
        colorRaw: String,
        goalHours: Double,
        createdDate: Date,
        isArchived: Bool
    ) throws

    func upsertTag(
        id: UUID,
        name: String,
        createdDate: Date,
        projectId: UUID?,
        parentId: UUID?
    ) throws

    func upsertSession(
        id: UUID,
        startTime: Date,
        endTime: Date?,
        plannedMinutes: Double,
        statusRaw: String,
        kindRaw: String,
        title: String?,
        projectId: UUID?,
        tagId: UUID?,
        events: [SessionEvent]
    ) throws

    func deleteSession(id: UUID) throws
    func deleteProject(id: UUID) throws
    func deleteAllProjects() throws
    func deleteAllSessions() throws
}

final class SwiftDataFocusRepository: FocusRepository {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    private func context() -> ModelContext {
        ModelContext(container)
    }

    func fetchSessions(in interval: DateInterval) throws -> [SDFocusSession] {
        let ctx = context()
        let start = interval.start
        let end = interval.end
        let descriptor = FetchDescriptor<SDFocusSession>(
            predicate: #Predicate { $0.startTime >= start && $0.startTime <= end },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        return try ctx.fetch(descriptor)
    }

    func fetchProjects(includeArchived: Bool) throws -> [SDProject] {
        let ctx = context()
        let descriptor: FetchDescriptor<SDProject>
        if includeArchived {
            descriptor = FetchDescriptor(sortBy: [SortDescriptor(\.createdDate, order: .forward)])
        } else {
            descriptor = FetchDescriptor(
                predicate: #Predicate { $0.isArchived == false },
                sortBy: [SortDescriptor(\.createdDate, order: .forward)]
            )
        }
        return try ctx.fetch(descriptor)
    }

    func fetchProjectTags(projectId: UUID) throws -> [SDProjectTag] {
        let ctx = context()
        let descriptor = FetchDescriptor<SDProjectTag>(
            predicate: #Predicate { $0.project?.id == projectId },
            sortBy: [SortDescriptor(\.createdDate, order: .forward)]
        )
        return try ctx.fetch(descriptor)
    }

    func upsertProject(
        id: UUID,
        name: String,
        colorRaw: String,
        goalHours: Double,
        createdDate: Date,
        isArchived: Bool
    ) throws {
        let ctx = context()
        let existing = try ctx.fetch(
            FetchDescriptor<SDProject>(predicate: #Predicate { $0.id == id })
        ).first

        if let p = existing {
            p.name = name
            p.colorRaw = colorRaw
            p.goalHours = goalHours
            p.createdDate = createdDate
            p.isArchived = isArchived
        } else {
            ctx.insert(SDProject(
                id: id,
                name: name,
                colorRaw: colorRaw,
                goalHours: goalHours,
                createdDate: createdDate,
                isArchived: isArchived
            ))
        }

        try ctx.save()
    }

    func upsertTag(
        id: UUID,
        name: String,
        createdDate: Date,
        projectId: UUID?,
        parentId: UUID?
    ) throws {
        let ctx = context()
        let existing = try ctx.fetch(
            FetchDescriptor<SDProjectTag>(predicate: #Predicate { $0.id == id })
        ).first

        let project: SDProject? = if let projectId {
            try ctx.fetch(FetchDescriptor<SDProject>(predicate: #Predicate { $0.id == projectId })).first
        } else { nil }

        let parent: SDProjectTag? = if let parentId {
            try ctx.fetch(FetchDescriptor<SDProjectTag>(predicate: #Predicate { $0.id == parentId })).first
        } else { nil }

        if let t = existing {
            t.name = name
            t.createdDate = createdDate
            t.project = project
            t.parent = parent
        } else {
            ctx.insert(SDProjectTag(
                id: id,
                name: name,
                createdDate: createdDate,
                project: project,
                parent: parent
            ))
        }

        try ctx.save()
    }

    func upsertSession(
        id: UUID,
        startTime: Date,
        endTime: Date?,
        plannedMinutes: Double,
        statusRaw: String,
        kindRaw: String,
        title: String?,
        projectId: UUID?,
        tagId: UUID?,
        events: [SessionEvent]
    ) throws {
        let ctx = context()
        let existing = try ctx.fetch(
            FetchDescriptor<SDFocusSession>(predicate: #Predicate { $0.id == id })
        ).first

        let project: SDProject? = if let projectId {
            try ctx.fetch(FetchDescriptor<SDProject>(predicate: #Predicate { $0.id == projectId })).first
        } else { nil }

        let tag: SDProjectTag? = if let tagId {
            try ctx.fetch(FetchDescriptor<SDProjectTag>(predicate: #Predicate { $0.id == tagId })).first
        } else { nil }

        let session: SDFocusSession
        if let s = existing {
            session = s
            session.startTime = startTime
            session.endTime = endTime
            session.plannedMinutes = plannedMinutes
            session.statusRaw = statusRaw
            session.kindRaw = kindRaw
            session.title = title
            session.project = project
            session.tag = tag
            session.events.removeAll()
        } else {
            session = SDFocusSession(
                id: id,
                startTime: startTime,
                endTime: endTime,
                plannedMinutes: plannedMinutes,
                statusRaw: statusRaw,
                kindRaw: kindRaw,
                title: title,
                project: project,
                tag: tag
            )
            ctx.insert(session)
        }

        for e in events.sorted(by: { $0.timestamp < $1.timestamp }) {
            let record = SDSessionEventRecord(timestamp: e.timestamp, typeRaw: e.eventType.rawValue, session: session)
            ctx.insert(record)
            session.events.append(record)
        }

        try ctx.save()
    }

    func deleteAllSessions() throws {
        let ctx = context()
        let sessions = try ctx.fetch(FetchDescriptor<SDFocusSession>())
        for s in sessions { ctx.delete(s) }
        try ctx.save()
    }

    func deleteSession(id: UUID) throws {
        let ctx = context()
        if let session = try ctx.fetch(FetchDescriptor<SDFocusSession>(predicate: #Predicate { $0.id == id })).first {
            ctx.delete(session)
            try ctx.save()
        }
    }

    func deleteAllProjects() throws {
        let ctx = context()
        let projects = try ctx.fetch(FetchDescriptor<SDProject>())
        for p in projects { ctx.delete(p) }
        try ctx.save()
    }

    func deleteProject(id: UUID) throws {
        let ctx = context()
        if let project = try ctx.fetch(FetchDescriptor<SDProject>(predicate: #Predicate { $0.id == id })).first {
            ctx.delete(project)
            try ctx.save()
        }
    }
}

private struct UnconfiguredFocusRepository: FocusRepository {
    func fetchSessions(in interval: DateInterval) throws -> [SDFocusSession] { [] }
    func fetchProjects(includeArchived: Bool) throws -> [SDProject] { [] }
    func fetchProjectTags(projectId: UUID) throws -> [SDProjectTag] { [] }
    func upsertProject(id: UUID, name: String, colorRaw: String, goalHours: Double, createdDate: Date, isArchived: Bool) throws {}
    func upsertTag(id: UUID, name: String, createdDate: Date, projectId: UUID?, parentId: UUID?) throws {}
    func upsertSession(id: UUID, startTime: Date, endTime: Date?, plannedMinutes: Double, statusRaw: String, kindRaw: String, title: String?, projectId: UUID?, tagId: UUID?, events: [SessionEvent]) throws {}
    func deleteSession(id: UUID) throws {}
    func deleteProject(id: UUID) throws {}
    func deleteAllProjects() throws {}
    func deleteAllSessions() throws {}
}

private struct FocusRepositoryKey: EnvironmentKey {
    static let defaultValue: any FocusRepository = UnconfiguredFocusRepository()
}

extension EnvironmentValues {
    var focusRepository: any FocusRepository {
        get { self[FocusRepositoryKey.self] }
        set { self[FocusRepositoryKey.self] = newValue }
    }
}
