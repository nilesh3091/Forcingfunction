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
import UIKit

class TimerViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedMinutes: Double = 25.0
    @Published var remainingSeconds: Int = 1500  // 25 minutes * 60 seconds
    @Published var timerState: TimerState = .idle
    @Published var currentSessionType: SessionType = .work
    @Published var completedPomodoros: Int = 0
    @Published var totalFocusMinutes: Int = 0
    @AppStorage("selectedCategoryId") var selectedCategoryIdString: String = ""
    @AppStorage("selectedTaskId") var selectedTaskIdString: String = ""
    
    var selectedCategoryId: UUID? {
        get {
            UUID(uuidString: selectedCategoryIdString)
        }
        set {
            selectedCategoryIdString = newValue?.uuidString ?? ""
        }
    }
    
    var selectedTaskId: UUID? {
        get {
            UUID(uuidString: selectedTaskIdString)
        }
        set {
            selectedTaskIdString = newValue?.uuidString ?? ""
        }
    }
    
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
    @AppStorage("liveActivitiesEnabled") var liveActivitiesEnabled: Bool = true
    @AppStorage("themeColor") var themeColorString: String = ThemeColor.red.rawValue
    
    // MARK: - Timer State Persistence (using @AppStorage)
    @AppStorage("savedTimerState") private var savedTimerStateRaw: String = ""
    @AppStorage("savedStartTime") private var savedStartTimeTimestamp: Double = 0
    @AppStorage("savedOriginalDurationSeconds") private var savedOriginalDurationSeconds: Int = 0
    @AppStorage("savedPausedDuration") private var savedPausedDuration: Double = 0
    @AppStorage("savedPauseStartTime") private var savedPauseStartTimeTimestamp: Double = 0
    @AppStorage("savedSelectedMinutes") private var savedSelectedMinutes: Double = 25.0
    @AppStorage("savedSessionType") private var savedSessionTypeRaw: String = "Work"
    @AppStorage("timerWasCompleted") private var timerWasCompleted: Bool = false
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var startTime: Date?
    private var pausedSeconds: Int = 0
    private var originalDurationSeconds: Int = 0  // Store original duration for time-based calculation
    private var pausedDuration: TimeInterval = 0  // Track total paused time
    private var pauseStartTime: Date?  // Track when pause started
    private var cancellables = Set<AnyCancellable>()
    private var hasLoadedSettings = false
    private var currentSession: PomodoroSession?
    private let dataStore = PomodoroDataStore.shared
    private let taskDataStore = TaskDataStore.shared
    private var isAutoStartingNext = false
    private let liveActivityManager = LiveActivityManager.shared
    private let backgroundTaskManager = BackgroundTaskManager.shared
    
    // MARK: - Computed Properties
    var themeColor: ThemeColor {
        ThemeColor(rawValue: themeColorString) ?? .red
    }
    
    /// Centralized theme system - use this for all styling
    var theme: AppTheme {
        themeColor.theme
    }
    
    /// Accent color (backward compatibility - use theme.accentColor instead)
    var accentColor: Color {
        theme.accentColor
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
        // Rotate counter-clockwise from currentAngle back to 0 (12 o'clock)
        return currentAngle * (1.0 - progress)
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
        
        // Single daily goal: migrate from per-weekday JSON or legacy weekly ÷ 7
        if !hasMigratedToSingleDailyGoal {
            var migrated = AppSettings.defaultDailyFocusGoalMinutes
            if let json = UserDefaults.standard.string(forKey: "dailyFocusGoalMinutesByWeekdayJSON"), !json.isEmpty,
               let data = json.data(using: .utf8),
               let arr = try? JSONDecoder().decode([Int].self, from: data), arr.count == 7 {
                migrated = max(0, arr.reduce(0, +) / 7)
            } else {
                let w = UserDefaults.standard.integer(forKey: "weeklyGoalMinutes")
                if w > 0 { migrated = max(1, w / 7) }
            }
            dailyFocusGoalMinutes = min(24 * 60, max(0, migrated))
            hasMigratedToSingleDailyGoal = true
            WidgetDataManager.shared.updateWidgetData()
        }
        
        // Always start at 25 minutes
        selectedMinutes = 25.0
        remainingSeconds = Int(selectedMinutes * 60)
        
        // Load statistics from stored data
        loadStatistics()
        
        requestNotificationPermission()
        
        // Set up app lifecycle observers
        setupLifecycleObservers()
        
        // Listen for timer completion notifications from background
        NotificationCenter.default.publisher(for: .timerCompletedInBackground)
            .sink { [weak self] _ in
                self?.checkAndCompleteTimerIfNeeded()
            }
            .store(in: &cancellables)
        
        // Restore timer state from disk if available
        // This MUST happen before cleanupOrphanedSessions to complete expired sessions
        restoreTimerState()
        
        // Note: We no longer restore completion state - we reset to idle instead
        // Clear completion flag if it was set
        if timerWasCompleted {
            timerWasCompleted = false
        }
        
        // Complete any expired sessions that finished while app was terminated
        // This handles the case where app was killed and notification fired
        // Pass saved startTime to avoid completing the session that restoreTimerState() is handling
        let savedStartTime = savedStartTimeTimestamp > 0 ? Date(timeIntervalSince1970: savedStartTimeTimestamp) : nil
        dataStore.completeExpiredSessions(excludingStartTime: savedStartTime)
        
        // Reload statistics after completing expired sessions
        loadStatistics()
        
        // Clean up orphaned sessions from crashes/force quits
        // This removes any running/paused sessions that were left behind
        // IMPORTANT: This runs AFTER restoreTimerState() and completeExpiredSessions() 
        // so expired sessions can be completed first
        dataStore.cleanupOrphanedSessions()
    }
    
    // MARK: - Statistics Loading
    private func loadStatistics() {
        completedPomodoros = dataStore.getCompletedPomodorosCount()
        totalFocusMinutes = dataStore.getTotalFocusMinutes()
    }
    
    // MARK: - Timer Control
    func startTimer() {
        guard timerState != .running else { return }
        
        // Clear completion flag when starting new timer
        timerWasCompleted = false
        
        // Don't start if time is 0
        guard selectedMinutes > 0 else { return }
        
        let now = Date()
        
        if timerState == .paused {
            // Resume from paused state
            // Add the paused duration to our total paused time
            if let pauseStart = pauseStartTime {
                pausedDuration += now.timeIntervalSince(pauseStart)
                pauseStartTime = nil
            }
            
            // Set remaining seconds from paused state (will be recalculated by tick() based on time)
            remainingSeconds = pausedSeconds
            
            // Add resume event to current session
            if var session = currentSession {
                let resumeEvent = SessionEvent(timestamp: now, eventType: .resumed)
                session.events.append(resumeEvent)
                session.status = .running
                currentSession = session
                dataStore.updateSession(session)
            }
            
            // Resume: Update Live Activity to running state (if enabled)
            if liveActivitiesEnabled {
                liveActivityManager.updateActivity(
                    remainingSeconds: remainingSeconds,
                    timerState: .running,
                    sessionType: currentSessionType,
                    startTime: startTime ?? now,
                    pausedDuration: pausedDuration
                )
            }
        } else {
            // Start new session
            remainingSeconds = Int(selectedMinutes * 60)
            pausedSeconds = remainingSeconds
            originalDurationSeconds = remainingSeconds
            pausedDuration = 0  // Reset paused duration for new session
            pauseStartTime = nil
            
            // Create new session
            // Time tracking logic:
            // - If a task is selected: time goes to task only (categoryId = nil)
            // - If no task but category is selected: time goes to category (categoryId = selectedCategoryId)
            // - If neither task nor category is selected: time goes to general statistics only (categoryId = nil)
            //   Note: Time is still tracked in totalFocusMinutes and completedPomodoros, just not categorized
            let sessionCategoryId: UUID? = selectedTaskId == nil ? selectedCategoryId : nil
            
            let newSession = PomodoroSession(
                sessionType: currentSessionType,
                startTime: now,
                plannedDurationMinutes: selectedMinutes,
                status: .running,
                events: [SessionEvent(timestamp: now, eventType: .started)],
                wasAutoStarted: isAutoStartingNext,
                categoryId: sessionCategoryId
            )
            currentSession = newSession
            dataStore.addSession(newSession)
            isAutoStartingNext = false // Reset flag after use
            
            // Start Live Activity for new session (if enabled)
            if liveActivitiesEnabled {
                liveActivityManager.startActivity(
                    sessionId: newSession.id,
                    sessionType: currentSessionType,
                    totalDurationSeconds: originalDurationSeconds,
                    remainingSeconds: remainingSeconds,
                    startTime: now,
                    pausedDuration: 0
                )
            }
        }
        
        timerState = .running
        startTime = now
        
        // Save timer state to disk
        saveTimerState()
        
        // Start background task for Live Activity updates (if enabled)
        if liveActivitiesEnabled {
            backgroundTaskManager.startBackgroundUpdates { [weak self] in
                guard let self = self, self.timerState == .running else { return }
                self.updateLiveActivityInBackground()
            }
        }
        
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
        pauseStartTime = Date()  // Track when pause started
        timer?.invalidate()
        timer = nil
        cancelNotification()
        
        // Add pause event to current session
        let now = Date()
        if var session = currentSession {
            let pauseEvent = SessionEvent(timestamp: now, eventType: .paused)
            session.events.append(pauseEvent)
            session.status = .paused
            currentSession = session
            dataStore.updateSession(session)
        }
        
        // Stop background updates when paused
        backgroundTaskManager.stopBackgroundUpdates()
        
        // Update Live Activity to paused state (if enabled)
        if liveActivitiesEnabled {
            liveActivityManager.updateActivity(
                remainingSeconds: remainingSeconds,
                timerState: .paused,
                sessionType: currentSessionType,
                startTime: startTime ?? Date(),
                pausedDuration: pausedDuration
            )
        }
        
        // Save timer state to disk
        saveTimerState()
        
        if hapticsEnabled {
            HapticManager.playImpact(style: .light)
        }
    }
    
    func resetTimer() {
        timer?.invalidate()
        timer = nil
        
        // Cancel current session if it exists
        let now = Date()
        if var session = currentSession {
            let cancelEvent = SessionEvent(timestamp: now, eventType: .cancelled)
            session.events.append(cancelEvent)
            session.endTime = now
            session.status = .cancelled
            dataStore.updateSession(session)
            currentSession = nil
        }
        
        timerState = .idle
        remainingSeconds = Int(selectedMinutes * 60)
        pausedSeconds = remainingSeconds
        startTime = nil
        originalDurationSeconds = 0
        pausedDuration = 0
        pauseStartTime = nil
        cancelNotification()
        
        // Stop background updates
        backgroundTaskManager.stopBackgroundUpdates()
        
        // End Live Activity (if enabled)
        if liveActivitiesEnabled {
            liveActivityManager.endActivity()
        }
        
        // Clear saved timer state
        clearTimerState()
        
        if hapticsEnabled {
            HapticManager.playSelection()
        }
    }
    
    func endSession() {
        timer?.invalidate()
        timer = nil
        
        let now = Date()
        
        // Try to get current session, or find it from data store if nil
        var sessionToComplete: PomodoroSession?
        
        if let session = currentSession {
            sessionToComplete = session
        } else {
            // Try to find the session from data store using saved state
            // This handles the case where app was backgrounded and currentSession was lost
            if let startTime = startTime, originalDurationSeconds > 0 {
                let matchingSessions = dataStore.getAllSessions().filter { session in
                    abs(session.startTime.timeIntervalSince(startTime)) < 1.0 &&
                    (session.status == .running || session.status == .paused)
                }
                sessionToComplete = matchingSessions.first
            }
        }
        
        // Complete the session if we found one
        if var session = sessionToComplete {
            let completeEvent = SessionEvent(timestamp: now, eventType: .completed)
            session.events.append(completeEvent)
            session.endTime = now
            session.status = .completed
            dataStore.updateSession(session)
            
            // Update statistics if it was a work session
            if session.sessionType == .work {
                loadStatistics() // Reload from data store to get accurate totals
                // Update widget data
                WidgetDataManager.shared.updateWidgetData()
                
                // Add time to task if one is selected
                if let taskId = selectedTaskId {
                    if let activeDuration = session.activeDurationMinutes {
                        taskDataStore.addPomodoroTime(toTaskId: taskId, minutes: activeDuration)
                    } else if let actualDuration = session.actualDurationMinutes {
                        taskDataStore.addPomodoroTime(toTaskId: taskId, minutes: actualDuration)
                    }
                    // Clear task selection after session completes
                    // User must click task again to add more time to it
                    selectedTaskId = nil
                }
            }
            
            currentSession = nil
        } else {
            // If we still can't find a session, log a warning
            print("Warning: endSession() called but no session found to complete")
        }
        
        // Reset to default idle state when completed
        // This matches the default state when app opens
        timerState = .idle
        
        // Reset to default time based on session type
        // Default is 25 minutes for work (matching app initialization)
        switch currentSessionType {
        case .work:
            selectedMinutes = 25.0  // Default work session duration
        case .shortBreak:
            selectedMinutes = shortBreakMinutes
        case .longBreak:
            selectedMinutes = longBreakMinutes
        }
        
        remainingSeconds = Int(selectedMinutes * 60)
        pausedSeconds = remainingSeconds
        
        // Clear completion flag since we're resetting to idle
        timerWasCompleted = false
        
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
        
        // Stop background updates
        backgroundTaskManager.stopBackgroundUpdates()
        
        // End Live Activity (if enabled)
        if liveActivitiesEnabled {
            liveActivityManager.endActivity()
        }
        
        // Clear saved timer state (but keep completion flag)
        clearTimerState()
        
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
            // Update completed pomodoros count from data store
            completedPomodoros = dataStore.getCompletedPomodorosCount()
            
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
        
        // Auto-start the next session if enabled
        if autoStartNext {
            isAutoStartingNext = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startTimer()
            }
        }
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
        guard let startTime = startTime else { return }
        
        // Calculate elapsed time based on actual time, accounting for pauses
        let now = Date()
        var elapsed = now.timeIntervalSince(startTime)
        
        // Subtract paused duration
        elapsed -= pausedDuration
        
        // If currently paused, subtract the current pause duration
        if let pauseStart = pauseStartTime {
            elapsed -= now.timeIntervalSince(pauseStart)
        }
        
        // Calculate remaining seconds
        remainingSeconds = max(0, originalDurationSeconds - Int(elapsed))
        
        // Update Live Activity (if enabled)
        if liveActivitiesEnabled {
            liveActivityManager.updateActivity(
                remainingSeconds: remainingSeconds,
                timerState: .running,
                sessionType: currentSessionType,
                startTime: startTime,
                pausedDuration: pausedDuration
            )
        }
        
        if remainingSeconds <= 0 {
            endSession()
        }
    }
    
    /// Update Live Activity from background task
    private func updateLiveActivityInBackground() {
        guard liveActivitiesEnabled else { return }
        guard timerState == .running, let startTime = startTime else { return }
        
        let now = Date()
        var elapsed = now.timeIntervalSince(startTime)
        elapsed -= pausedDuration
        
        if let pauseStart = pauseStartTime {
            elapsed -= now.timeIntervalSince(pauseStart)
        }
        
        let calculatedRemaining = max(0, originalDurationSeconds - Int(elapsed))
        
        liveActivityManager.updateActivity(
            remainingSeconds: calculatedRemaining,
            timerState: .running,
            sessionType: currentSessionType,
            startTime: startTime,
            pausedDuration: pausedDuration
        )
    }
    
    // MARK: - Timer State Synchronization
    private func setupLifecycleObservers() {
        // Observe when app becomes active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.syncTimerState()
            }
            .store(in: &cancellables)
        
        // Observe when app will enter foreground
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.syncTimerState()
            }
            .store(in: &cancellables)
        
        // Observe when app goes to background - save state
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.saveTimerState()
            }
            .store(in: &cancellables)
    }
    
    func syncTimerState() {
        // First, try to restore state from disk if we don't have it in memory
        if timerState == .idle && !savedTimerStateRaw.isEmpty {
            restoreTimerState()
            return
        }
        
        // Only sync if timer is running or paused
        guard timerState == .running || timerState == .paused else { return }
        guard let startTime = startTime else { return }
        
        let now = Date()
        var elapsed = now.timeIntervalSince(startTime)
        
        // Subtract paused duration
        elapsed -= pausedDuration
        
        // If currently paused, subtract the current pause duration
        if let pauseStart = pauseStartTime {
            elapsed -= now.timeIntervalSince(pauseStart)
        }
        
        // Calculate remaining seconds
        let calculatedRemaining = max(0, originalDurationSeconds - Int(elapsed))
        
        // Update remaining seconds
        remainingSeconds = calculatedRemaining
        
        // If timer should have completed, end the session
        if calculatedRemaining <= 0 {
            // Ensure we have currentSession before ending
            ensureCurrentSessionExists()
            endSession()
            return
        }
        
        // Ensure currentSession exists before continuing
        ensureCurrentSessionExists()
        
        // Restart timer if it's not running (app was backgrounded) and timer was running
        if timer == nil && timerState == .running {
            startTimerTicking()
            // Reschedule notification with updated remaining time
            scheduleNotification()
            
            // Restart background updates
            backgroundTaskManager.startBackgroundUpdates { [weak self] in
                guard let self = self, self.timerState == .running else { return }
                self.updateLiveActivityInBackground()
            }
        }
    }
    
    /// Check if timer should be completed and complete it if needed
    /// Called when notification fires or app becomes active
    private func checkAndCompleteTimerIfNeeded() {
        // Only check if timer is running or paused
        guard timerState == .running || timerState == .paused else { return }
        guard let startTime = startTime else { return }
        guard originalDurationSeconds > 0 else { return }
        
        let now = Date()
        var elapsed = now.timeIntervalSince(startTime)
        elapsed -= pausedDuration
        
        if let pauseStart = pauseStartTime {
            elapsed -= now.timeIntervalSince(pauseStart)
        }
        
        let calculatedRemaining = max(0, originalDurationSeconds - Int(elapsed))
        
        // If timer should have completed, end the session
        if calculatedRemaining <= 0 {
            ensureCurrentSessionExists()
            endSession()
        }
    }
    
    /// Ensure currentSession exists by finding it from data store if needed
    private func ensureCurrentSessionExists() {
        // If we already have a currentSession, we're good
        if currentSession != nil {
            return
        }
        
        // Try to find the session from data store using saved state
        guard let startTime = startTime, originalDurationSeconds > 0 else { return }
        
        let matchingSessions = dataStore.getAllSessions().filter { session in
            abs(session.startTime.timeIntervalSince(startTime)) < 1.0 &&
            (session.status == .running || session.status == .paused)
        }
        
        if let session = matchingSessions.first {
            currentSession = session
            print("Restored currentSession from data store: \(session.id)")
        } else {
            // If we still can't find it, create a new one based on saved state
            // This handles edge cases where the session was never saved
            if let sessionType = SessionType(rawValue: savedSessionTypeRaw) {
                // If a task is selected, don't assign category (time goes to task only)
                // If no task is selected, assign category (time goes to category)
                let sessionCategoryId: UUID? = selectedTaskId == nil ? selectedCategoryId : nil
                
                let newSession = PomodoroSession(
                    sessionType: sessionType,
                    startTime: startTime,
                    plannedDurationMinutes: savedSelectedMinutes,
                    status: timerState == .running ? .running : .paused,
                    events: [SessionEvent(timestamp: startTime, eventType: .started)],
                    wasAutoStarted: false,
                    categoryId: sessionCategoryId
                )
                currentSession = newSession
                dataStore.addSession(newSession)
                print("Created new session from saved state: \(newSession.id)")
            }
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
        // Skip update on first load to preserve initial 25 minute value
        if !hasLoadedSettings {
            hasLoadedSettings = true
            return
        }
        
        if timerState == .idle {
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
    
    // MARK: - Timer State Persistence
    
    /// Save current timer state to disk
    private func saveTimerState() {
        if timerState == .running || timerState == .paused {
            savedTimerStateRaw = timerState == .running ? "running" : "paused"
            savedStartTimeTimestamp = startTime?.timeIntervalSince1970 ?? 0
            savedOriginalDurationSeconds = originalDurationSeconds
            savedPausedDuration = pausedDuration
            savedPauseStartTimeTimestamp = pauseStartTime?.timeIntervalSince1970 ?? 0
            savedSelectedMinutes = selectedMinutes
            savedSessionTypeRaw = currentSessionType.rawValue
        } else {
            clearTimerState()
        }
    }
    
    /// Clear saved timer state from disk
    private func clearTimerState() {
        savedTimerStateRaw = ""
        savedStartTimeTimestamp = 0
        savedOriginalDurationSeconds = 0
        savedPausedDuration = 0
        savedPauseStartTimeTimestamp = 0
        savedSelectedMinutes = 25.0
        savedSessionTypeRaw = "Work"
        // Note: timerWasCompleted flag is NOT cleared here - it's cleared after restoring state
    }
    
    /// Restore timer state from disk
    private func restoreTimerState() {
        // Only restore if we have saved state
        guard !savedTimerStateRaw.isEmpty else { return }
        guard savedStartTimeTimestamp > 0 else { return }
        guard savedOriginalDurationSeconds > 0 else { return }
        
        // Restore basic properties
        selectedMinutes = savedSelectedMinutes
        originalDurationSeconds = savedOriginalDurationSeconds
        pausedDuration = savedPausedDuration
        startTime = Date(timeIntervalSince1970: savedStartTimeTimestamp)
        
        // Restore session type
        if let sessionType = SessionType(rawValue: savedSessionTypeRaw) {
            currentSessionType = sessionType
        }
        
        // Restore pause start time if paused
        if savedPauseStartTimeTimestamp > 0 {
            pauseStartTime = Date(timeIntervalSince1970: savedPauseStartTimeTimestamp)
        }
        
        // Calculate remaining time
        let now = Date()
        var elapsed = now.timeIntervalSince(startTime!)
        elapsed -= pausedDuration
        
        if let pauseStart = pauseStartTime {
            elapsed -= now.timeIntervalSince(pauseStart)
        }
        
        let calculatedRemaining = max(0, originalDurationSeconds - Int(elapsed))
        remainingSeconds = calculatedRemaining
        pausedSeconds = calculatedRemaining
        
        // Restore timer state
        if savedTimerStateRaw == "running" {
            timerState = .running
            
            // If timer should have completed, end the session
            if calculatedRemaining <= 0 {
                ensureCurrentSessionExists()
                endSession()
                return
            }
            
            // Restart the timer
            startTimerTicking()
            scheduleNotification()
            
            // Restart background updates
            backgroundTaskManager.startBackgroundUpdates { [weak self] in
                guard let self = self, self.timerState == .running else { return }
                self.updateLiveActivityInBackground()
            }
            
            // Ensure currentSession exists before continuing
            ensureCurrentSessionExists()
            
            // Restart Live Activity if needed (if enabled)
            if liveActivitiesEnabled {
                
                // Use reconnectOrStartActivity which will find existing or create new
                if let session = currentSession {
                    liveActivityManager.reconnectOrStartActivity(
                        sessionId: session.id,
                        sessionType: currentSessionType,
                        totalDurationSeconds: originalDurationSeconds,
                        remainingSeconds: remainingSeconds,
                        startTime: startTime!,
                        pausedDuration: pausedDuration,
                        timerState: .running
                    )
                }
            }
        } else if savedTimerStateRaw == "paused" {
            timerState = .paused
            
            // Ensure currentSession exists
            ensureCurrentSessionExists()
            
            // Reconnect or update Live Activity (if enabled)
            if liveActivitiesEnabled {
                if let session = currentSession {
                    liveActivityManager.reconnectOrStartActivity(
                        sessionId: session.id,
                        sessionType: currentSessionType,
                        totalDurationSeconds: originalDurationSeconds,
                        remainingSeconds: remainingSeconds,
                        startTime: startTime!,
                        pausedDuration: pausedDuration,
                        timerState: .paused
                    )
                } else if liveActivityManager.hasActiveActivity {
                    // Fallback: update existing activity if we don't have session info
                    liveActivityManager.updateActivity(
                        remainingSeconds: remainingSeconds,
                        timerState: .paused,
                        sessionType: currentSessionType,
                        startTime: startTime!,
                        pausedDuration: pausedDuration
                    )
                }
            }
        }
    }
    
    deinit {
        timer?.invalidate()
        cancelNotification()
    }
}

