//
//  TimerStatePersistence.swift
//  ForcingFunction
//

import Foundation
import SwiftUI

/// Persists in-flight timer state as a single Codable blob and provides a single
/// recovery routine for app lifecycle + cold-launch restoration.
@MainActor
final class TimerStatePersistence {
    struct Snapshot: Codable, Equatable {
        var timerStateRaw: String            // "running" | "paused"
        var startTime: Date
        var originalDurationSeconds: Int
        var pausedDuration: TimeInterval
        var pauseStartTime: Date?
        var selectedMinutes: Double
        var sessionTypeRaw: String
    }

    @AppStorage("timerStateSnapshot") private var timerStateSnapshotData: Data = Data()

    init() {}

    func load() -> Snapshot? {
        guard !timerStateSnapshotData.isEmpty else { return nil }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Snapshot.self, from: timerStateSnapshotData)
        } catch {
            print("TimerStatePersistence: failed to decode snapshot — \(error)")
            return nil
        }
    }

    func save(_ snapshot: Snapshot) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            timerStateSnapshotData = try encoder.encode(snapshot)
        } catch {
            print("TimerStatePersistence: failed to encode snapshot — \(error)")
        }
    }

    func clear() {
        timerStateSnapshotData = Data()
    }

    /// The single lifecycle recovery routine.
    ///
    /// - If there is no snapshot: does nothing.
    /// - If the snapshot's timer should have completed by now: returns `.completedExpired`.
    /// - Else restores `engine`, and returns `.restoredPaused` or `.restoredRunning`.
    func recoverIfNeeded(
        now: Date,
        engine: inout TimerEngine,
        currentSessionType: inout SessionType
    ) -> RecoveryOutcome {
        guard let snapshot = load() else { return .noSnapshot }
        guard snapshot.originalDurationSeconds > 0 else {
            clear()
            return .noSnapshot
        }

        if let sessionType = SessionType(rawValue: snapshot.sessionTypeRaw) {
            currentSessionType = sessionType
        }

        let state: TimerState = (snapshot.timerStateRaw == "running") ? .running : .paused

        engine.restoreFromSnapshot(
            timerState: state,
            startTime: snapshot.startTime,
            originalDurationSeconds: snapshot.originalDurationSeconds,
            pausedDuration: snapshot.pausedDuration,
            pauseStartTime: snapshot.pauseStartTime,
            selectedMinutes: snapshot.selectedMinutes,
            remainingSeconds: 0
        )

        let remaining = engine.calculateRemainingSeconds(now: now)
        engine.setRemainingSeconds(remaining)

        // One-shot restore: avoid re-restoring on next cold launch.
        clear()

        if remaining <= 0 {
            return .completedExpired
        }
        return state == .running ? .restoredRunning : .restoredPaused
    }

    enum RecoveryOutcome: Equatable {
        case noSnapshot
        case restoredRunning
        case restoredPaused
        case completedExpired
    }
}

