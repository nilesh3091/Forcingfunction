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
    @Published var healthWorkouts: [HealthWorkoutSession] = []
    
    // MARK: - Per-session metadata ("Setup")
    @AppStorage("setupPomodoroTitle") var setupTitle: String = ""
    @AppStorage("setupPomodoroTag") var setupTag: String = ""
    @AppStorage("setupPomodoroTagColor") private var setupTagColorRaw: String = CategoryColor.teal.rawValue
    /// UUID string of the selected project (empty = none).
    @AppStorage("setupProjectId") var setupProjectId: String = ""
    /// UUID string of the selected project tag (empty = none).
    @AppStorage("setupTagId") var setupTagId: String = ""

    var setupTagColor: CategoryColor {
        get { CategoryColor(rawValue: setupTagColorRaw) ?? .teal }
        set { setupTagColorRaw = newValue.rawValue }
    }
    
    // MARK: - Settings (using @AppStorage)
    @AppStorage("pomodoroMinutes") var pomodoroMinutes: Double = AppSettings.defaultPomodoroMinutes
    @AppStorage("shortBreakMinutes") var shortBreakMinutes: Double = AppSettings.defaultShortBreakMinutes
    @AppStorage("longBreakMinutes") var longBreakMinutes: Double = AppSettings.defaultLongBreakMinutes
    @AppStorage("pomodorosBeforeLongBreak") var pomodorosBeforeLongBreak: Int = AppSettings.defaultPomodorosBeforeLongBreak
    @AppStorage("snapIncrement") var snapIncrement: Double = AppSettings.defaultSnapIncrement
    @AppStorage("hasMigratedToNewRange") var hasMigratedToNewRange: Bool = false
    @AppStorage("strictPomodoroMode") var strictPomodoroMode: Bool = false
    @AppStorage("autoStartNext") var autoStartNext: Bool = false
    @AppStorage("playSoundOnCompletion") var playSoundOnCompletion: Bool = true
    @AppStorage("hapticsEnabled") var hapticsEnabled: Bool = true
    @AppStorage("liveActivitiesEnabled") var liveActivitiesEnabled: Bool = true
    @AppStorage("dailyFocusGoalMinutes") var dailyFocusGoalMinutes: Int = AppSettings.defaultDailyFocusGoalMinutes
    @AppStorage("hasMigratedToSingleDailyGoal") private var hasMigratedToSingleDailyGoal: Bool = false
    @AppStorage("appAppearance") private var appAppearanceRaw: String = AppAppearance.system.rawValue
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var engine = TimerEngine()
    private let statePersistence = TimerStatePersistence()
    private var cancellables = Set<AnyCancellable>()
    private var hasLoadedSettings = false
    private var currentSession: PomodoroSession?
    private let dataStore = PomodoroDataStore.shared
    private let liveActivityManager = LiveActivityManager.shared
    private let backgroundTaskManager = BackgroundTaskManager.shared

    private func syncPublishedFromEngine() {
        selectedMinutes = engine.selectedMinutes
        remainingSeconds = engine.remainingSeconds
        timerState = engine.timerState
    }
    
    // MARK: - Computed Properties
    
    /// Centralized theme system - use this for all styling
    var theme: AppTheme {
        AppTheme.standard
    }
    
    var appAppearance: AppAppearance {
        get { AppAppearance(rawValue: appAppearanceRaw) ?? .system }
        set { appAppearanceRaw = newValue.rawValue }
    }
    
    /// Global accent (work / cyan) — tabs, settings, calendar, stats.
    var accentColor: Color {
        theme.accentColor
    }
    
    /// Work vs break accent for timer dial, readout, and primary session controls.
    var sessionAccentColor: Color {
        switch currentSessionType {
        case .work:
            return theme.workAccent
        case .shortBreak, .longBreak:
            return theme.breakAccent
        }
    }
    
    // MARK: - Focus goal (single daily target, minutes)
    
    func focusGoalMinutesForToday() -> Int {
        max(0, dailyFocusGoalMinutes)
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
    
    /// Hand position while running: sweeps **backward** along the selected-duration arc from the end toward 12 o’clock.
    /// (Progress **percentage** is shown by the separate full-circle green ring in `TimerView`, not by this angle.)
    var elapsedAngle: Double {
        guard selectedMinutes >= 0 else { return 0 }
        let progress = self.progress
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
        
        // Ensure selectedMinutes doesn't exceed the current supported dial range.
        if selectedMinutes > maxMinutes {
            selectedMinutes = maxMinutes
        }
        
        // Always start at 25 minutes
        selectedMinutes = 25.0
        remainingSeconds = Int(selectedMinutes * 60)
        engine.resetToIdle(minutes: selectedMinutes)
        
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
        recoverTimerStateIfNeeded()
        
        // Complete any expired sessions that finished while app was terminated
        // This handles the case where app was killed and notification fired
        // Pass saved startTime to avoid completing the session that recoverTimerStateIfNeeded() is handling
        let savedStartTime = statePersistence.load()?.startTime
        dataStore.completeExpiredSessions(excludingStartTime: savedStartTime)
        
        // Reload statistics after completing expired sessions
        loadStatistics()
        
        // Clean up orphaned sessions from crashes/force quits
        // This removes any running/paused sessions that were left behind
        // IMPORTANT: This runs AFTER recoverTimerStateIfNeeded() and completeExpiredSessions()
        // so expired sessions can be completed first
        dataStore.cleanupOrphanedSessions()
        
        Task { @MainActor in
            await refreshHealthWorkouts()
        }
    }

    @MainActor
    func refreshHealthWorkouts() async {
        // Pull enough history to populate the History strip (up to ~60 days) and month view.
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(byAdding: .day, value: -90, to: now) ?? now.addingTimeInterval(-90 * 24 * 60 * 60)
        
        let ok = await HealthKitManager.shared.requestWorkoutReadAuthorization()
        guard ok else {
            healthWorkouts = []
            return
        }
        
        let workouts = await HealthKitManager.shared.fetchWorkouts(from: start, to: now)
        healthWorkouts = workouts
    }
    
    /// Keeps the device from auto-locking while a session is active (running or paused).
    private func updateIdleTimerForSession() {
        let keepAwake = (timerState == .running || timerState == .paused)
        let apply = {
            UIApplication.shared.isIdleTimerDisabled = keepAwake
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }
    
    // MARK: - Statistics Loading
    private func loadStatistics() {
        completedPomodoros = dataStore.getCompletedPomodorosCount()
        totalFocusMinutes = dataStore.getTotalFocusMinutes()
    }
    
    // MARK: - Timer Control
    func startTimer() {
        guard engine.timerState != .running else { return }
        
        // Don't start if time is 0
        guard selectedMinutes > 0 else { return }
        
        let now = Date()
        let resumeFromPaused = (engine.timerState == .paused)
        
        if engine.timerState == .paused {
            // Resume from paused state
            engine.resume(now: now)
            syncPublishedFromEngine()
            
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
                    startTime: engine.startTime ?? now,
                    pausedDuration: engine.pausedDuration
                )
            }
        } else {
            // Start new session
            engine.startNew(now: now, minutes: selectedMinutes)
            syncPublishedFromEngine()
            
            // Create new session
            let cleanTitle = setupTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanTag = setupTag.trimmingCharacters(in: .whitespacesAndNewlines)
            let newSession = PomodoroSession(
                sessionType: currentSessionType,
                startTime: now,
                plannedDurationMinutes: selectedMinutes,
                status: .running,
                events: [SessionEvent(timestamp: now, eventType: .started)],
                title: cleanTitle.isEmpty ? nil : cleanTitle,
                tag: cleanTag.isEmpty ? nil : cleanTag,
                tagColor: (cleanTag.isEmpty ? nil : setupTagColor),
                projectId: UUID(uuidString: setupProjectId),
                projectTagId: UUID(uuidString: setupTagId)
            )
            currentSession = newSession
            dataStore.addSession(newSession)
            
            // Start Live Activity for new session (if enabled)
            if liveActivitiesEnabled {
                liveActivityManager.startActivity(
                    sessionId: newSession.id,
                    sessionType: currentSessionType,
                    totalDurationSeconds: engine.originalDurationSeconds,
                    remainingSeconds: remainingSeconds,
                    startTime: now,
                    pausedDuration: 0
                )
            }
        }
        
        if !resumeFromPaused {
            // ensure published state reflects a fresh start
            syncPublishedFromEngine()
        }
        updateIdleTimerForSession()
        
        // Save timer state to disk
        saveTimerState()
        
        // Start background task for Live Activity updates (if enabled)
        if liveActivitiesEnabled {
            backgroundTaskManager.startBackgroundUpdates { [weak self] in
                guard let self = self, self.timerState == .running else { return }
                self.updateLiveActivityInBackground()
            }
        }
        
        scheduleNotification()
        startTimerTicking()
    }
    
    func pauseTimer() {
        guard engine.timerState == .running else { return }
        
        let now = Date()
        engine.pause(now: now)
        syncPublishedFromEngine()
        updateIdleTimerForSession()
        timer?.invalidate()
        timer = nil
        cancelNotification()
        
        // Add pause event to current session
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
                startTime: engine.startTime ?? now,
                pausedDuration: engine.pausedDuration
            )
        }
        
        // Save timer state to disk
        saveTimerState()
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
            dataStore.finalizeEndedSession(session)
            currentSession = nil
        }
        
        engine.resetToIdle(minutes: selectedMinutes)
        syncPublishedFromEngine()
        updateIdleTimerForSession()
        cancelNotification()
        
        // Stop background updates
        backgroundTaskManager.stopBackgroundUpdates()
        
        // End Live Activity (if enabled)
        if liveActivitiesEnabled {
            liveActivityManager.endActivity()
        }
        
        // Clear saved timer state
        statePersistence.clear()
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
            if let startTime = engine.startTime, engine.originalDurationSeconds > 0 {
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
            dataStore.finalizeEndedSession(session)
            
            // Update statistics if it was a work session
            if session.sessionType == .work {
                loadStatistics() // Reload from data store to get accurate totals
                // Update widget data
                WidgetDataManager.shared.updateWidgetData()
            }
            
            currentSession = nil
        } else {
            // If we still can't find a session, log a warning
            print("Warning: endSession() called but no session found to complete")
        }
        
        // Reset to default idle state when completed
        // This matches the default state when app opens
        engine.resetToIdle(minutes: selectedMinutes)
        syncPublishedFromEngine()
        updateIdleTimerForSession()
        
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
        
        engine.resetToIdle(minutes: selectedMinutes)
        syncPublishedFromEngine()
        
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
        statePersistence.clear()
        
        // Auto-start next session if enabled
        if autoStartNext {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.startNextSession()
            }
        }
    }
    
    func startNextSession() {
        if currentSessionType == .work {
            if strictPomodoroMode {
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
                // Free-flow: every post-work break is a short break.
                currentSessionType = .shortBreak
                selectedMinutes = shortBreakMinutes
            }
        } else {
            currentSessionType = .work
            selectedMinutes = pomodoroMinutes
        }

        engine.resetToIdle(minutes: selectedMinutes)
        syncPublishedFromEngine()
        updateIdleTimerForSession()

        if autoStartNext {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.startTimer() }
        }
    }
    
    // MARK: - Time Selection
    func setTimeFromAngle(_ angle: Double, force: Bool = false) {
        let newMinutes = AngleUtilities.angleToMinutes(angle, minMinutes: minMinutes, maxMinutes: maxMinutes, snapIncrement: snapIncrement)
        
        // Round to whole minutes
        let wholeMinutes = round(newMinutes)
        
        guard engine.timerState == .idle else { return }
        if force || abs(wholeMinutes - selectedMinutes) > 0.01 {
            engine.setSelectedMinutes(wholeMinutes)
            syncPublishedFromEngine()
            
            // Haptic feedback on minute change (skip when forced — caller or drag handles feedback)
            if hapticsEnabled && !force {
                HapticManager.playSelection()
            }
        }
    }
    
    func setTimeFromMinutes(_ minutes: Double) {
        let clamped = max(minMinutes, min(maxMinutes, minutes))
        if engine.timerState == .idle {
            let oldWhole = Int(selectedMinutes.rounded())
            engine.setSelectedMinutes(clamped)
            syncPublishedFromEngine()
            if hapticsEnabled && Int(clamped.rounded()) != oldWhole {
                HapticManager.playSelection()
            }
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
        guard engine.timerState == .running else { return }
        let now = Date()
        remainingSeconds = engine.tick(now: now)
        
        // Update Live Activity (if enabled)
        if liveActivitiesEnabled, let startTime = engine.startTime {
            liveActivityManager.updateActivity(
                remainingSeconds: remainingSeconds,
                timerState: .running,
                sessionType: currentSessionType,
                startTime: startTime,
                pausedDuration: engine.pausedDuration
            )
        }
        
        if remainingSeconds <= 0 {
            endSession()
        }
    }
    
    /// Update Live Activity from background task
    private func updateLiveActivityInBackground() {
        guard liveActivitiesEnabled else { return }
        guard engine.timerState == .running, let startTime = engine.startTime else { return }

        let calculatedRemaining = engine.calculateRemainingSeconds(now: Date())
        
        liveActivityManager.updateActivity(
            remainingSeconds: calculatedRemaining,
            timerState: .running,
            sessionType: currentSessionType,
            startTime: startTime,
            pausedDuration: engine.pausedDuration
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
        if engine.timerState == .idle && statePersistence.load() != nil {
            recoverTimerStateIfNeeded()
            return
        }
        
        // Only sync if timer is running or paused
        guard engine.timerState == .running || engine.timerState == .paused else { return }
        let calculatedRemaining = engine.calculateRemainingSeconds(now: Date())
        
        // Update remaining seconds
        remainingSeconds = calculatedRemaining
        engine.setRemainingSeconds(calculatedRemaining)
        
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
        if timer == nil && engine.timerState == .running {
            startTimerTicking()
            // Reschedule notification with updated remaining time
            scheduleNotification()
            
            // Restart background updates
            backgroundTaskManager.startBackgroundUpdates { [weak self] in
                guard let self = self, self.engine.timerState == .running else { return }
                self.updateLiveActivityInBackground()
            }
        }
    }
    
    /// Check if timer should be completed and complete it if needed
    /// Called when notification fires or app becomes active
    private func checkAndCompleteTimerIfNeeded() {
        // Only check if timer is running or paused
        guard engine.timerState == .running || engine.timerState == .paused else { return }
        guard engine.originalDurationSeconds > 0 else { return }

        let calculatedRemaining = engine.calculateRemainingSeconds(now: Date())
        
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
        guard let startTime = engine.startTime, engine.originalDurationSeconds > 0 else { return }
        
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
            guard let snapshot = statePersistence.load(),
                  let sessionType = SessionType(rawValue: snapshot.sessionTypeRaw) else { return }
                let newSession = PomodoroSession(
                    sessionType: sessionType,
                    startTime: startTime,
                    plannedDurationMinutes: snapshot.selectedMinutes,
                    status: engine.timerState == .running ? .running : .paused,
                    events: [SessionEvent(timestamp: startTime, eventType: .started)],
                    title: nil,
                    tag: nil,
                    tagColor: nil
                )
                currentSession = newSession
                dataStore.addSession(newSession)
                print("Created new session from saved state: \(newSession.id)")
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
        content.title = "Session complete"
        content.body = currentSessionType == .work
            ? "Focus session complete. Take a break."
            : "Break over. Ready for the next session?"
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
        
        if engine.timerState == .idle {
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
                engine.setSelectedMinutes(clampedMinutes)
                syncPublishedFromEngine()
            }
        }
    }
    
    // MARK: - Timer State Persistence
    
    private func saveTimerState() {
        guard engine.timerState == .running || engine.timerState == .paused else {
            statePersistence.clear()
            return
        }
        guard let startTime = engine.startTime else { return }

        let snapshot = TimerStatePersistence.Snapshot(
            timerStateRaw: (engine.timerState == .running ? "running" : "paused"),
            startTime: startTime,
            originalDurationSeconds: engine.originalDurationSeconds,
            pausedDuration: engine.pausedDuration,
            pauseStartTime: engine.pauseStartTime,
            selectedMinutes: engine.selectedMinutes,
            sessionTypeRaw: currentSessionType.rawValue
        )
        statePersistence.save(snapshot)
    }
    
    private func recoverTimerStateIfNeeded() {
        let now = Date()
        let outcome = statePersistence.recoverIfNeeded(now: now, engine: &engine, currentSessionType: &currentSessionType)
        syncPublishedFromEngine()

        switch outcome {
        case .noSnapshot:
            return
        case .completedExpired:
            ensureCurrentSessionExists()
            endSession()
            return
        case .restoredRunning:
            updateIdleTimerForSession()
            startTimerTicking()
            scheduleNotification()
            backgroundTaskManager.startBackgroundUpdates { [weak self] in
                guard let self, self.engine.timerState == .running else { return }
                self.updateLiveActivityInBackground()
            }
            ensureCurrentSessionExists()
            if liveActivitiesEnabled, let session = currentSession, let startTime = engine.startTime {
                liveActivityManager.reconnectOrStartActivity(
                    sessionId: session.id,
                    sessionType: currentSessionType,
                    totalDurationSeconds: engine.originalDurationSeconds,
                    remainingSeconds: remainingSeconds,
                    startTime: startTime,
                    pausedDuration: engine.pausedDuration,
                    timerState: .running
                )
            }
        case .restoredPaused:
            updateIdleTimerForSession()
            ensureCurrentSessionExists()
            if liveActivitiesEnabled, let session = currentSession, let startTime = engine.startTime {
                liveActivityManager.reconnectOrStartActivity(
                    sessionId: session.id,
                    sessionType: currentSessionType,
                    totalDurationSeconds: engine.originalDurationSeconds,
                    remainingSeconds: remainingSeconds,
                    startTime: startTime,
                    pausedDuration: engine.pausedDuration,
                    timerState: .paused
                )
            } else if liveActivitiesEnabled, liveActivityManager.hasActiveActivity, let startTime = engine.startTime {
                liveActivityManager.updateActivity(
                    remainingSeconds: remainingSeconds,
                    timerState: .paused,
                    sessionType: currentSessionType,
                    startTime: startTime,
                    pausedDuration: engine.pausedDuration
                )
            }
        }
    }
    
    deinit {
        timer?.invalidate()
        cancelNotification()
        if Thread.isMainThread {
            UIApplication.shared.isIdleTimerDisabled = false
        } else {
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }
}

