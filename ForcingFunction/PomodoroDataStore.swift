//
//  PomodoroDataStore.swift
//  ForcingFunction
//
//  Manages persistence of pomodoro session data
//

import Foundation

class PomodoroDataStore {
    static let shared = PomodoroDataStore()
    
    private let fileName = "pomodoro_sessions.json"
    private var sessions: [PomodoroSession] = []
    
    private init() {
        loadSessions()
    }
    
    // MARK: - File Management
    
    private var fileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(fileName)
    }
    
    // MARK: - Load Sessions
    
    /// Load all sessions from disk
    func loadSessions() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            sessions = []
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            sessions = try decoder.decode([PomodoroSession].self, from: data)
            
            let beforeCount = sessions.count
            sessions.removeAll { session in
                guard session.sessionType == .work, session.status == .cancelled else { return false }
                let minutes = session.activeDurationMinutes ?? session.actualDurationMinutes ?? 0
                return minutes < PomodoroSession.minimumRecordedWorkMinutes
            }
            if sessions.count != beforeCount {
                saveSessions()
            }
            
            // Sort by start time (most recent first)
            sessions.sort { $0.startTime > $1.startTime }
        } catch {
            print("Error loading pomodoro sessions: \(error)")
            sessions = []
        }
    }
    
    // MARK: - Save Sessions
    
    /// Save all sessions to disk
    @discardableResult
    private func saveSessions() -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(sessions)
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            print("Error saving pomodoro sessions: \(error)")
            return false
        }
    }
    
    // MARK: - Session Management
    
    /// Add a new session
    func addSession(_ session: PomodoroSession) {
        sessions.append(session)
        sessions.sort { $0.startTime > $1.startTime }
        saveSessions()
    }
    
    /// Update an existing session (e.g., when it's completed or paused)
    func updateSession(_ session: PomodoroSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
            saveSessions()
        }
    }
    
    /// Persists a session after it has ended. Completed work sessions are always kept; cancelled work under `minimumRecordedWorkMinutes` is removed.
    func finalizeEndedSession(_ session: PomodoroSession) {
        guard session.sessionType == .work else {
            updateSession(session)
            return
        }
        guard session.status == .completed || session.status == .cancelled else {
            updateSession(session)
            return
        }
        if session.status == .completed {
            updateSession(session)
            return
        }
        let minutes = session.activeDurationMinutes ?? session.actualDurationMinutes ?? 0
        if minutes >= PomodoroSession.minimumRecordedWorkMinutes {
            updateSession(session)
        } else {
            deleteSession(byId: session.id)
        }
    }
    
    /// Get all sessions
    func getAllSessions() -> [PomodoroSession] {
        return sessions
    }
    
    /// Get sessions filtered by date range
    func getSessions(from startDate: Date, to endDate: Date) -> [PomodoroSession] {
        return sessions.filter { session in
            session.startTime >= startDate && session.startTime <= endDate
        }
    }
    
    /// Get sessions by type
    func getSessions(ofType type: SessionType) -> [PomodoroSession] {
        return sessions.filter { $0.sessionType == type }
    }
    
    /// Get completed work sessions
    func getCompletedWorkSessions() -> [PomodoroSession] {
        return sessions.filter { $0.sessionType == .work && $0.status == .completed }
    }
    
    /// Get total count of completed work sessions
    func getCompletedPomodorosCount() -> Int {
        return getCompletedWorkSessions().count
    }
    
    /// Get total focus minutes from all completed work sessions
    func getTotalFocusMinutes() -> Int {
        let completedWorkSessions = getCompletedWorkSessions()
        let totalMinutes = completedWorkSessions.compactMap { $0.activeDurationMinutes ?? $0.actualDurationMinutes }.reduce(0, +)
        return Int(totalMinutes)
    }
    
    /// Completed work focus minutes for the current calendar day (same rules as the main timer’s “today” total).
    func getTodayCompletedWorkFocusMinutes() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        guard let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return 0 }
        
        let todaySessions = sessions.filter { session in
            session.sessionType == .work &&
            session.status == .completed &&
            session.startTime >= startOfDay &&
            session.startTime < startOfNextDay
        }
        
        var totalMinutes: Double = 0
        for session in todaySessions {
            if let activeDuration = session.activeDurationMinutes {
                totalMinutes += activeDuration
            } else if let actualDuration = session.actualDurationMinutes {
                totalMinutes += actualDuration
            } else if let endTime = session.endTime {
                totalMinutes += endTime.timeIntervalSince(session.startTime) / 60.0
            } else {
                totalMinutes += session.plannedDurationMinutes
            }
        }
        return Int(totalMinutes)
    }
    
    /// Get session by ID
    func getSession(byId id: UUID) -> PomodoroSession? {
        return sessions.first { $0.id == id }
    }
    
    /// Delete a session by ID
    func deleteSession(byId id: UUID) {
        sessions.removeAll { $0.id == id }
        saveSessions()
    }
    
    /// Delete multiple sessions
    func deleteSessions(_ sessionsToDelete: [PomodoroSession]) {
        let idsToDelete = Set(sessionsToDelete.map { $0.id })
        sessions.removeAll { idsToDelete.contains($0.id) }
        saveSessions()
    }
    
    /// Clean up orphaned sessions (running/paused sessions from previous app launches)
    /// These are sessions that were left in running/paused state when app crashed or was force-quit
    /// IMPORTANT: This should be called AFTER restoreTimerState() completes expired sessions
    func cleanupOrphanedSessions() {
        let orphanedSessions = sessions.filter { session in
            session.status == .running || session.status == .paused
        }
        
        if !orphanedSessions.isEmpty {
            print("Cleaning up \(orphanedSessions.count) orphaned session(s)")
            deleteSessions(orphanedSessions)
        }
    }
    
    /// Complete expired sessions that should have finished
    /// This is called on app launch to complete sessions that finished while app was terminated
    /// Note: Sessions matching saved timer state are handled by restoreTimerState(), so this
    /// completes any other orphaned sessions that expired
    func completeExpiredSessions(excludingStartTime: Date? = nil) {
        let now = Date()
        let expiredSessions = sessions.filter { session in
            (session.status == .running || session.status == .paused) &&
            session.endTime == nil &&
            // Skip session if it matches the saved timer state (will be handled by restoreTimerState)
            (excludingStartTime == nil || abs(session.startTime.timeIntervalSince(excludingStartTime!)) >= 1.0)
        }
        
        for var session in expiredSessions {
            // Calculate if session should have completed
            var totalPausedTime: TimeInterval = 0
            var pauseStartTime: Date?
            
            // Calculate paused time from events
            for event in session.events.sorted(by: { $0.timestamp < $1.timestamp }) {
                if event.eventType == .paused {
                    pauseStartTime = event.timestamp
                } else if event.eventType == .resumed, let pauseStart = pauseStartTime {
                    totalPausedTime += event.timestamp.timeIntervalSince(pauseStart)
                    pauseStartTime = nil
                }
            }
            
            // If still paused, add time until now
            if let pauseStart = pauseStartTime {
                totalPausedTime += now.timeIntervalSince(pauseStart)
            }
            
            // Calculate elapsed time
            let elapsed = now.timeIntervalSince(session.startTime) - totalPausedTime
            let elapsedMinutes = elapsed / 60.0
            
            // If elapsed time exceeds planned duration, complete the session
            if elapsedMinutes >= session.plannedDurationMinutes {
                let completeEvent = SessionEvent(timestamp: now, eventType: .completed)
                session.events.append(completeEvent)
                session.endTime = now
                session.status = .completed
                finalizeEndedSession(session)
                print("Completed expired session: \(session.id) - elapsed: \(elapsedMinutes)min, planned: \(session.plannedDurationMinutes)min")
            }
        }
    }
}

