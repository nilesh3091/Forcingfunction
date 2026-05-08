//
//  SessionRecorder.swift
//  ForcingFunction
//

import Foundation

/// Serializes session persistence writes behind an actor.
actor SessionRecorder {
    private let dataStore: PomodoroDataStore
    private var currentSession: PomodoroSession?

    init(dataStore: PomodoroDataStore) {
        self.dataStore = dataStore
    }

    func recordStart(_ session: PomodoroSession) async {
        currentSession = session
        await MainActor.run { dataStore.addSession(session) }
    }

    func pause(now: Date) async -> PomodoroSession? {
        guard var session = currentSession else { return nil }
        session.events.append(SessionEvent(timestamp: now, eventType: .paused))
        session.status = .paused
        currentSession = session
        let sessionCopy = session
        await MainActor.run { [sessionCopy] in dataStore.updateSession(sessionCopy) }
        return session
    }

    func resume(now: Date) async -> PomodoroSession? {
        guard var session = currentSession else { return nil }
        session.events.append(SessionEvent(timestamp: now, eventType: .resumed))
        session.status = .running
        currentSession = session
        let sessionCopy = session
        await MainActor.run { [sessionCopy] in dataStore.updateSession(sessionCopy) }
        return session
    }

    func complete(now: Date) async -> PomodoroSession? {
        guard var session = currentSession else { return nil }
        session.events.append(SessionEvent(timestamp: now, eventType: .completed))
        session.endTime = now
        session.status = .completed
        currentSession = nil
        let sessionCopy = session
        await MainActor.run { [sessionCopy] in dataStore.finalizeEndedSession(sessionCopy) }
        return session
    }

    func cancel(now: Date) async -> PomodoroSession? {
        guard var session = currentSession else { return nil }
        session.events.append(SessionEvent(timestamp: now, eventType: .cancelled))
        session.endTime = now
        session.status = .cancelled
        currentSession = nil
        let sessionCopy = session
        await MainActor.run { [sessionCopy] in dataStore.finalizeEndedSession(sessionCopy) }
        return session
    }

    func setCurrentSession(_ session: PomodoroSession?) {
        currentSession = session
    }

    func getCurrentSession() -> PomodoroSession? {
        currentSession
    }

    /// Best-effort restoration used by lifecycle recovery when `TimerViewModel` lost in-memory session.
    func restoreIfNeeded(startTime: Date) async -> PomodoroSession? {
        if let currentSession, abs(currentSession.startTime.timeIntervalSince(startTime)) < 1.0 {
            return currentSession
        }

        let match = await MainActor.run {
            dataStore.getAllSessions().first { s in
                abs(s.startTime.timeIntervalSince(startTime)) < 1.0 && (s.status == .running || s.status == .paused)
            }
        }
        currentSession = match
        return match
    }
}

