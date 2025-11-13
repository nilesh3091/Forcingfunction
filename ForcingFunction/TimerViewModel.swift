//
//  TimerViewModel.swift
//  ForcingFunction
//
//  ViewModel managing timer state and logic
//

import Foundation
import SwiftUI
import Combine
import UserNotifications

class TimerViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedMinutes: Double = AppSettings.defaultPomodoroMinutes
    @Published var remainingSeconds: Int = 0
    @Published var timerState: TimerState = .idle
    @Published var currentSessionType: SessionType = .work
    @Published var completedPomodoros: Int = 0
    @Published var totalFocusMinutes: Int = 0
    
    // MARK: - Settings (using @AppStorage)
    @AppStorage("pomodoroMinutes") var pomodoroMinutes: Double = AppSettings.defaultPomodoroMinutes
    @AppStorage("shortBreakMinutes") var shortBreakMinutes: Double = AppSettings.defaultShortBreakMinutes
    @AppStorage("longBreakMinutes") var longBreakMinutes: Double = AppSettings.defaultLongBreakMinutes
    @AppStorage("pomodorosBeforeLongBreak") var pomodorosBeforeLongBreak: Int = AppSettings.defaultPomodorosBeforeLongBreak
    @AppStorage("snapIncrement") var snapIncrement: Double = AppSettings.defaultSnapIncrement
    @AppStorage("hasMigratedToNewRange") var hasMigratedToNewRange: Bool = false
    @AppStorage("autoStartNext") var autoStartNext: Bool = false
    @AppStorage("playSoundOnCompletion") var playSoundOnCompletion: Bool = true
    @AppStorage("hapticsEnabled") var hapticsEnabled: Bool = true
    @AppStorage("themeColor") var themeColorString: String = ThemeColor.red.rawValue
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var startTime: Date?
    private var pausedSeconds: Int = 0
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var themeColor: ThemeColor {
        ThemeColor(rawValue: themeColorString) ?? .red
    }
    
    var accentColor: Color {
        switch themeColor {
        case .red:
            return .red
        case .blue:
            return .blue
        case .green:
            return .green
        }
    }
    
    var minMinutes: Double {
        AppSettings.defaultMinMinutes
    }
    
    var maxMinutes: Double {
        AppSettings.defaultMaxMinutes
    }
    
    var progress: Double {
        guard selectedMinutes >= 0 else { return 0 }
        let totalSeconds = Int(selectedMinutes * 60)
        guard totalSeconds > 0 else { return 0 }
        let elapsed = totalSeconds - remainingSeconds
        return Double(elapsed) / Double(totalSeconds)
    }
    
    var currentAngle: Double {
        // Ensure 0 minutes maps to -90° (top/12 o'clock)
        let angle = AngleUtilities.minutesToAngle(selectedMinutes, minMinutes: minMinutes, maxMinutes: maxMinutes)
        // Debug: Print to verify
        #if DEBUG
        if selectedMinutes == 0 {
            print("DEBUG: selectedMinutes=0, angle=\(angle)")
        }
        #endif
        return angle
    }
    
    var elapsedAngle: Double {
        guard selectedMinutes >= 0 else { return 0 }
        let progress = self.progress
        return currentAngle + (progress * 360.0)
    }
    
    // MARK: - Initialization
    init() {
        // Migration: Reset to 0 if this is first launch with new range system
        // or if pomodoroMinutes is in the old range (5-25 minutes)
        if !hasMigratedToNewRange || (pomodoroMinutes >= 5 && pomodoroMinutes <= 25) {
            pomodoroMinutes = AppSettings.defaultPomodoroMinutes
            hasMigratedToNewRange = true
        }
        
        // If pomodoroMinutes is outside the new valid range (0-60), reset to default
        if pomodoroMinutes < minMinutes || pomodoroMinutes > maxMinutes {
            pomodoroMinutes = AppSettings.defaultPomodoroMinutes
        }
        
        // Migrate snap increment from old 15-minute default to new 1-minute default
        if snapIncrement == 15.0 {
            snapIncrement = AppSettings.defaultSnapIncrement
        }
        
        // Migrate maxMinutes if it was set to old 120-minute value
        if maxMinutes > 60.0 {
            // This will be handled by the computed property, but ensure selectedMinutes doesn't exceed 60
            if selectedMinutes > 60.0 {
                selectedMinutes = 60.0
            }
        }
        
        // Always start at 0 minutes (top position)
        selectedMinutes = 0.0
        remainingSeconds = Int(selectedMinutes * 60)
        requestNotificationPermission()
    }
    
    // MARK: - Timer Control
    func startTimer() {
        guard timerState != .running else { return }
        
        // Don't start if time is 0
        guard selectedMinutes > 0 else { return }
        
        if timerState == .paused {
            // Resume from paused state
            remainingSeconds = pausedSeconds
        } else {
            // Start new session
            remainingSeconds = Int(selectedMinutes * 60)
            pausedSeconds = remainingSeconds
        }
        
        timerState = .running
        startTime = Date()
        
        if hapticsEnabled {
            HapticManager.playImpact(style: .medium)
        }
        
        scheduleNotification()
        startTimerTicking()
    }
    
    func pauseTimer() {
        guard timerState == .running else { return }
        
        timerState = .paused
        pausedSeconds = remainingSeconds
        timer?.invalidate()
        timer = nil
        cancelNotification()
        
        if hapticsEnabled {
            HapticManager.playImpact(style: .light)
        }
    }
    
    func resetTimer() {
        timer?.invalidate()
        timer = nil
        timerState = .idle
        remainingSeconds = Int(selectedMinutes * 60)
        pausedSeconds = remainingSeconds
        startTime = nil
        cancelNotification()
        
        if hapticsEnabled {
            HapticManager.playSelection()
        }
    }
    
    func endSession() {
        timer?.invalidate()
        timer = nil
        
        if timerState == .running || timerState == .paused {
            // Update focus time if it was a work session
            if currentSessionType == .work {
                totalFocusMinutes += Int(selectedMinutes) - (remainingSeconds / 60)
            }
        }
        
        timerState = .completed
        
        // Play sound if enabled
        if playSoundOnCompletion {
            SoundManager.playCompletionSound()
        }
        
        // Haptic feedback
        if hapticsEnabled {
            HapticManager.playNotification(type: .success)
        }
        
        // Cancel notification
        cancelNotification()
        
        // Auto-start next session if enabled
        if autoStartNext {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.startNextSession()
            }
        }
    }
    
    func startNextSession() {
        // Determine next session type
        if currentSessionType == .work {
            completedPomodoros += 1
            if completedPomodoros >= pomodorosBeforeLongBreak {
                currentSessionType = .longBreak
                selectedMinutes = longBreakMinutes
                completedPomodoros = 0
            } else {
                currentSessionType = .shortBreak
                selectedMinutes = shortBreakMinutes
            }
        } else {
            // Break finished, start work session
            currentSessionType = .work
            selectedMinutes = pomodoroMinutes
        }
        
        remainingSeconds = Int(selectedMinutes * 60)
        pausedSeconds = remainingSeconds
        timerState = .idle
    }
    
    // MARK: - Time Selection
    func setTimeFromAngle(_ angle: Double) {
        let newMinutes = AngleUtilities.angleToMinutes(angle, minMinutes: minMinutes, maxMinutes: maxMinutes, snapIncrement: snapIncrement)
        
        // Round to whole minutes
        let wholeMinutes = round(newMinutes)
        
        if abs(wholeMinutes - selectedMinutes) > 0.01 && timerState == .idle {
            selectedMinutes = wholeMinutes
            remainingSeconds = Int(wholeMinutes * 60)
            pausedSeconds = remainingSeconds
            
            // Haptic feedback on minute change
            if hapticsEnabled {
                HapticManager.playSelection()
            }
        }
    }
    
    func setTimeFromMinutes(_ minutes: Double) {
        let clamped = max(minMinutes, min(maxMinutes, minutes))
        if timerState == .idle {
            selectedMinutes = clamped
            remainingSeconds = Int(selectedMinutes * 60)
            pausedSeconds = remainingSeconds
        }
    }
    
    // MARK: - Private Methods
    private func startTimerTicking() {
        timer?.invalidate()
        timer = nil
        
        let interval: TimeInterval = 1.0
        
        // Create timer on main thread - Timer.scheduledTimer automatically adds to RunLoop
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            self.tick()
        }
    }
    
    private func tick() {
        guard timerState == .running else { return }
        
        if remainingSeconds > 0 {
            remainingSeconds -= 1
        }
        
        if remainingSeconds <= 0 {
            endSession()
        }
    }
    
    // MARK: - Notifications
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    private func scheduleNotification() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        let content = UNMutableNotificationContent()
        content.title = "Session Complete"
        content.body = "Your \(currentSessionType.displayName) session has finished!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(remainingSeconds), repeats: false)
        let request = UNNotificationRequest(identifier: "pomodoro-timer", content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("Notification scheduling error: \(error)")
            }
        }
    }
    
    private func cancelNotification() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // MARK: - Settings Updates
    func updateSettings() {
        // When settings change, update current session if idle
        // Skip update on first load to preserve initial 0 value
        if timerState == .idle && selectedMinutes != 0 {
            let newMinutes: Double
            switch currentSessionType {
            case .work:
                newMinutes = pomodoroMinutes
            case .shortBreak:
                newMinutes = shortBreakMinutes
            case .longBreak:
                newMinutes = longBreakMinutes
            }
            // Only update if the new value is different and valid
            let clampedMinutes = max(minMinutes, min(maxMinutes, newMinutes))
            if clampedMinutes != selectedMinutes {
                selectedMinutes = clampedMinutes
                remainingSeconds = Int(selectedMinutes * 60)
                pausedSeconds = remainingSeconds
            }
        }
    }
    
    deinit {
        timer?.invalidate()
        cancelNotification()
    }
}

