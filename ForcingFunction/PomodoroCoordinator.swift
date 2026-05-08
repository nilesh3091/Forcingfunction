//
//  PomodoroCoordinator.swift
//  ForcingFunction
//

import Foundation

struct PomodoroCoordinator {
    struct Settings: Equatable {
        var strictPomodoroMode: Bool
        var pomodoroMinutes: Double
        var shortBreakMinutes: Double
        var longBreakMinutes: Double
        var pomodorosBeforeLongBreak: Int
    }

    struct NextSession: Equatable {
        var sessionType: SessionType
        var minutes: Double
        var completedPomodoros: Int?
    }

    func nextSession(
        currentSessionType: SessionType,
        completedPomodorosCount: Int,
        settings: Settings
    ) -> NextSession {
        if currentSessionType == .work {
            if settings.strictPomodoroMode {
                if completedPomodorosCount >= settings.pomodorosBeforeLongBreak {
                    return NextSession(sessionType: .longBreak, minutes: settings.longBreakMinutes, completedPomodoros: 0)
                } else {
                    return NextSession(sessionType: .shortBreak, minutes: settings.shortBreakMinutes, completedPomodoros: nil)
                }
            } else {
                return NextSession(sessionType: .shortBreak, minutes: settings.shortBreakMinutes, completedPomodoros: nil)
            }
        } else {
            return NextSession(sessionType: .work, minutes: settings.pomodoroMinutes, completedPomodoros: nil)
        }
    }
}

