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
    func cleanupOrphanedSessions() {
        let orphanedSessions = sessions.filter { session in
            session.status == .running || session.status == .paused
        }
        
        if !orphanedSessions.isEmpty {
            print("Cleaning up \(orphanedSessions.count) orphaned session(s)")
            deleteSessions(orphanedSessions)
        }
    }
}

