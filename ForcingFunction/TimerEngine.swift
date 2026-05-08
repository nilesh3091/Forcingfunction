//
//  TimerEngine.swift
//  ForcingFunction
//

import Foundation

/// Pure timer math/state: start/pause/resume/tick/remaining.
/// No I/O, no side-effects.
@MainActor
struct TimerEngine: Equatable {
    private(set) var timerState: TimerState = .idle

    private(set) var selectedMinutes: Double = 25.0
    private(set) var remainingSeconds: Int = 25 * 60

    private(set) var startTime: Date?
    private(set) var originalDurationSeconds: Int = 0

    private(set) var pausedDuration: TimeInterval = 0
    private(set) var pauseStartTime: Date?
    private(set) var pausedSeconds: Int = 0

    init() {}

    mutating func setSelectedMinutes(_ minutes: Double) {
        guard timerState == .idle else { return }
        selectedMinutes = minutes
        remainingSeconds = Int(minutes * 60)
        pausedSeconds = remainingSeconds
    }

    mutating func startOrResume(now: Date, minutes: Double) {
        if timerState == .paused {
            resume(now: now)
            return
        }
        startNew(now: now, minutes: minutes)
    }

    mutating func startNew(now: Date, minutes: Double) {
        selectedMinutes = minutes
        remainingSeconds = Int(minutes * 60)
        pausedSeconds = remainingSeconds

        originalDurationSeconds = remainingSeconds
        startTime = now

        pausedDuration = 0
        pauseStartTime = nil

        timerState = .running
    }

    mutating func pause(now: Date) {
        guard timerState == .running else { return }
        timerState = .paused
        pausedSeconds = remainingSeconds
        pauseStartTime = now
    }

    mutating func resume(now: Date) {
        guard timerState == .paused else { return }

        if let pauseStartTime {
            pausedDuration += now.timeIntervalSince(pauseStartTime)
            self.pauseStartTime = nil
        }

        // Resume uses the pre-pause remaining seconds, but tick() will
        // immediately re-derive from wall clock so we don't accumulate drift.
        remainingSeconds = pausedSeconds
        timerState = .running
    }

    mutating func resetToIdle(minutes: Double) {
        timerState = .idle
        selectedMinutes = minutes
        remainingSeconds = Int(minutes * 60)
        pausedSeconds = remainingSeconds

        startTime = nil
        originalDurationSeconds = 0
        pausedDuration = 0
        pauseStartTime = nil
    }

    mutating func tick(now: Date) -> Int {
        guard timerState == .running else { return remainingSeconds }
        remainingSeconds = calculateRemainingSeconds(now: now)
        return remainingSeconds
    }

    mutating func setRemainingSeconds(_ seconds: Int) {
        remainingSeconds = max(0, seconds)
        pausedSeconds = remainingSeconds
    }

    func calculateRemainingSeconds(now: Date) -> Int {
        guard let startTime else { return remainingSeconds }
        guard originalDurationSeconds > 0 else { return remainingSeconds }

        var elapsed = now.timeIntervalSince(startTime)
        elapsed -= pausedDuration
        if let pauseStartTime {
            elapsed -= now.timeIntervalSince(pauseStartTime)
        }

        return max(0, originalDurationSeconds - Int(elapsed))
    }

    mutating func restoreFromSnapshot(
        timerState: TimerState,
        startTime: Date,
        originalDurationSeconds: Int,
        pausedDuration: TimeInterval,
        pauseStartTime: Date?,
        selectedMinutes: Double,
        remainingSeconds: Int
    ) {
        self.timerState = timerState
        self.startTime = startTime
        self.originalDurationSeconds = originalDurationSeconds
        self.pausedDuration = pausedDuration
        self.pauseStartTime = pauseStartTime

        self.selectedMinutes = selectedMinutes
        self.remainingSeconds = remainingSeconds
        self.pausedSeconds = remainingSeconds
    }
}

