//
//  TimerView.swift
//  ForcingFunction
//
//  Main timer view with interactive circular dial
//

import SwiftUI
import UIKit

struct TimerView: View {
    @ObservedObject var viewModel: TimerViewModel
    @State private var isDragging = false
    @State private var dragAngle: Double = 0
    @State private var lastSelectedMinutes: Double = 0
    @State private var dragRemainingSeconds: Int = 0  // For smooth display during drag
    @State private var cumulativeDragAngle: Double = 0  // Track cumulative angle for continuous rotation
    @State private var lastDragAngle: Double = 0  // Track previous angle to detect wraparound
    
    // Haptic feedback tracking
    @State private var lastHapticMinute: Int = -1  // Track last minute for haptic feedback
    @State private var lastHapticMajorTick: Int = -1  // Track last 5-minute mark for haptic feedback
    @State private var lastHapticTime: Date = Date()  // Throttle continuous feedback
    
    // Haptic feedback helper functions
    private func triggerSelectionHaptic() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    private func triggerImpactHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Today’s target from the per-weekday schedule (Settings).
    private func dailyGoalMinutes() -> Int {
        viewModel.focusGoalMinutesForToday()
    }
    
    /// Completed focus today plus elapsed time in the current work session (if any).
    private func effectiveTodayFocusMinutes() -> Double {
        var total = Double(getTodayFocusMinutes())
        if viewModel.currentSessionType == .work,
           viewModel.timerState == .running || viewModel.timerState == .paused {
            let totalSeconds = max(1, Int(viewModel.selectedMinutes * 60))
            let elapsedSeconds = totalSeconds - viewModel.remainingSeconds
            total += Double(elapsedSeconds) / 60.0
        }
        return total
    }
    
    /// Progress toward today’s focus goal (0…1), aligned with the “FOCUSED” line. No target → 0 progress.
    private var focusGoalProgress: Double {
        let goal = Double(dailyGoalMinutes())
        if goal <= 0 { return 0 }
        let m = effectiveTodayFocusMinutes()
        return min(1.0, max(0.0, m / goal))
    }
    
    // Calculate today's total focus time in minutes
    private func getTodayFocusMinutes() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        guard let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return 0 }
        
        let dataStore = PomodoroDataStore.shared
        let allSessions = dataStore.getAllSessions()
        
        let todaySessions = allSessions.filter { session in
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
                totalMinutes += (endTime.timeIntervalSince(session.startTime) / 60.0)
            } else {
                totalMinutes += session.plannedDurationMinutes
            }
        }
        
        return Int(totalMinutes)
    }
    
    // Format focus time for display (e.g., "3H 32M" or "45M")
    private func formatTodayFocusTime() -> String {
        let totalMinutes = getTodayFocusMinutes()
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)H \(minutes)M"
        } else {
            return "\(minutes)M"
        }
    }
    
    // Get today's completed work sessions
    private func getTodayCompletedWorkSessions() -> [PomodoroSession] {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        guard let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }
        
        let dataStore = PomodoroDataStore.shared
        let allSessions = dataStore.getAllSessions()
        
        return allSessions.filter { session in
            // Only completed work sessions
            session.sessionType == .work &&
            session.status == .completed &&
            // Started today
            session.startTime >= startOfDay &&
            session.startTime < startOfNextDay
        }
    }
    
    // Calculate day progress position for a given time
    private func calculateDayProgressPosition(for date: Date) -> Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        guard let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return 0.0 }
        
        // Use endTime if available, otherwise startTime
        let sessionTime = date
        
        // Calculate elapsed time since midnight
        let elapsed = sessionTime.timeIntervalSince(startOfDay)
        
        // Calculate total time in the day (24 hours)
        let totalDayDuration = startOfNextDay.timeIntervalSince(startOfDay)
        
        // Calculate progress (0.0 to 1.0)
        let progress = elapsed / totalDayDuration
        return min(1.0, max(0.0, progress))
    }
    
    // Generate time markers for every 6 hours (12am, 6am, 12pm, 6pm)
    private func generateTimeMarkers() -> [(hour: Int, position: Double, label: String)] {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        var markers: [(hour: Int, position: Double, label: String)] = []
        
        // Generate markers for every 6 hours (0, 6, 12, 18)
        for hour in stride(from: 0, to: 24, by: 6) {
            guard let markerTime = calendar.date(byAdding: .hour, value: hour, to: startOfDay) else { continue }
            let position = calculateDayProgressPosition(for: markerTime)
            
            // Format label: 12am, 6am, 12pm, 6pm
            let label: String
            if hour == 0 {
                label = "12am"
            } else if hour == 12 {
                label = "12pm"
            } else if hour < 12 {
                label = "\(hour)am"
            } else {
                label = "\(hour - 12)pm"
            }
            
            markers.append((hour: hour, position: position, label: label))
        }
        
        return markers
    }
    
    // Group sessions that are close together for stacking
    private func groupSessionsForStacking(_ sessions: [PomodoroSession], threshold: Double = 0.01) -> [[PomodoroSession]] {
        // Sort sessions by completion time
        let sortedSessions = sessions.sorted { session1, session2 in
            let time1 = session1.endTime ?? session1.startTime
            let time2 = session2.endTime ?? session2.startTime
            return time1 < time2
        }
        
        var groups: [[PomodoroSession]] = []
        var currentGroup: [PomodoroSession] = []
        var lastPosition: Double = -1.0
        
        for session in sortedSessions {
            let sessionTime = session.endTime ?? session.startTime
            let position = calculateDayProgressPosition(for: sessionTime)
            
            // If this session is close to the last one (within threshold), add to current group
            if lastPosition >= 0 && abs(position - lastPosition) < threshold {
                currentGroup.append(session)
            } else {
                // Start a new group
                if !currentGroup.isEmpty {
                    groups.append(currentGroup)
                }
                currentGroup = [session]
            }
            lastPosition = position
        }
        
        // Add the last group
        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }
        
        return groups
    }
    
    private let knobSize: CGFloat = 26
    
    // Haptic feedback constants
    private let hapticThrottleInterval: TimeInterval = 0.05  // Max 20 Hz for continuous feedback
    
    // Theme access
    private var theme: AppTheme {
        viewModel.theme
    }
    
    private var primaryActionLabelColor: Color {
        switch viewModel.currentSessionType {
        case .work:
            return theme.buttonPrimaryText
        case .shortBreak, .longBreak:
            return Color(red: 0.05, green: 0.07, blue: 0.10)
        }
    }

    private struct PressableButtonStyle: ButtonStyle {
        let scale: CGFloat
        let opacity: Double

        init(scale: CGFloat = 0.98, opacity: Double = 0.92) {
            self.scale = scale
            self.opacity = opacity
        }

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? scale : 1.0)
                .opacity(configuration.isPressed ? opacity : 1.0)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
    
    private struct AnimatedPercentText: AnimatableModifier {
        var percent: Double
        
        var animatableData: Double {
            get { percent }
            set { percent = newValue }
        }
        
        func body(content: Content) -> some View {
            Text("\(Int(percent.rounded()))%")
        }
    }
    
    var body: some View {
        GeometryReader { outerGeometry in
            let safeWidth = outerGeometry.size.width
            let safeHeight = outerGeometry.size.height
            let dialSize = max(240, min(safeWidth - 40, safeHeight * 0.46, 340))
            let handLength = dialSize * 0.40

            ZStack {
                theme.background(.primary)
                    .ignoresSafeArea()
                
                HUDGridBackground(lineColor: theme.borderSecondary.opacity(0.45), spacing: 26, lineWidth: 0.5)
                    .ignoresSafeArea()
                
                HUDEdgeVignette(color: theme.background(.primary))
                    .opacity(0.4)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Mission-control status strip (monospace labels)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Text("FOCUSED \(formatTodayFocusTime())")
                            Text("·")
                                .foregroundColor(theme.text(.tertiary, opacity: 0.45))
                            if dailyGoalMinutes() <= 0 {
                                Text("NO DAILY TARGET")
                            } else {
                                Text("\(Int(focusGoalProgress * 100))% OF DAILY GOAL")
                            }
                        }
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(0.6)
                        .foregroundColor(theme.text(.tertiary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(theme.borderPrimary.opacity(0.35))
                                    .frame(height: 2)
                                Rectangle()
                                    .fill(theme.workAccent)
                                    .frame(width: dailyGoalMinutes() <= 0 ? 0 : geometry.size.width * focusGoalProgress, height: 2)
                                    .animation(.linear(duration: 0.35), value: focusGoalProgress)
                            }
                        }
                        .frame(height: 2)
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 16)
                    
                    Spacer()
                    
                    // Interactive circular dial
                    ZStack {
                    // Outer ring (thin)
                    Circle()
                        .stroke(theme.borderPrimary.opacity(0.55), lineWidth: 1)
                        .frame(width: dialSize, height: dialSize)
                    
                    // Swept accent fill: **idle only** (selected duration wedge). While running, % is the green ring only.
                    let pieAngle: Double = {
                        if viewModel.timerState == .idle {
                            let currentTotalAngle = isDragging ? cumulativeDragAngle : viewModel.currentAngle
                            return min(currentTotalAngle, 360.0)
                        } else {
                            return 0
                        }
                    }()
                    
                    if pieAngle > 0 {
                        // Full opacity solid color for swept area
                        SweptAreaView(
                            totalAngle: pieAngle,
                            dialSize: dialSize,
                            color: viewModel.sessionAccentColor
                        )
                    }
                    
                    // Major ticks only (every 5 minutes)
                    ForEach(0..<12) { i in
                        let minute = i * 5
                        let angle = (Double(minute) * 6.0) - 90.0
                        let tickLength: CGFloat = 10
                        let tickWidth: CGFloat = 1
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(theme.text(.tertiary, opacity: 0.4))
                            .frame(width: tickWidth, height: tickLength)
                            .offset(y: -dialSize / 2 + tickLength / 2)
                            .rotationEffect(.degrees(angle))
                    }
                    
                    // Progress ring: full circumference = 0–100% of session
                    if viewModel.timerState == .running || viewModel.timerState == .paused {
                        let ringTrim = min(1.0, max(0.0, viewModel.progress))
                        Circle()
                            .trim(from: 0, to: ringTrim)
                            .stroke(
                                viewModel.sessionAccentColor,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .frame(width: dialSize, height: dialSize)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1.0), value: viewModel.progress)
                    }

                    // Progress head: circular endcap with percent
                    if viewModel.timerState == .running || viewModel.timerState == .paused {
                        let angle = viewModel.progress * 360.0 - 90.0
                        let r = (dialSize / 2)
                        let x = (dialSize / 2) + (CGFloat(cos(angle * .pi / 180.0)) * r)
                        let y = (dialSize / 2) + (CGFloat(sin(angle * .pi / 180.0)) * r)
                        let pctA11y = Int((viewModel.progress * 100).rounded())
                        let headSize: CGFloat = 22

                        ZStack {
                            Circle()
                                .fill(viewModel.sessionAccentColor)

                            Color.clear
                                .modifier(AnimatedPercentText(percent: viewModel.progress * 100))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.92))
                                .monospacedDigit()
                        }
                        .frame(width: headSize, height: headSize)
                        .position(x: x, y: y)
                        .animation(.linear(duration: 1.0), value: viewModel.progress)
                        .allowsHitTesting(false)
                        .accessibilityLabel("Progress \(pctA11y) percent")
                    }

                    // Hand/needle
                    // For display, use modulo 360° so the hand rotates visually
                    let displayAngle = isDragging ? dragAngle : {
                        let angle = viewModel.currentAngle.truncatingRemainder(dividingBy: 360.0)
                        return angle < 0 ? angle + 360.0 : angle
                    }()
                    let handAngle: Double = {
                        if viewModel.timerState == .running || viewModel.timerState == .paused {
                            // When running/paused, show elapsed angle
                            let angle = viewModel.elapsedAngle.truncatingRemainder(dividingBy: 360.0)
                            return angle < 0 ? angle + 360.0 : angle
                        } else {
                            // When idle, show selected time angle
                            return displayAngle
                        }
                    }()
                    
                    // Hand/needle
                    ZStack {
                        Capsule(style: .continuous)
                            .fill(theme.text(.primary, opacity: 0.85))
                            .frame(width: 2, height: handLength)

                        Circle()
                            .fill(viewModel.sessionAccentColor.opacity(0.8))
                            .frame(width: 5, height: 5)
                            .offset(y: -handLength / 2 + 5)
                    }
                    .offset(y: -handLength / 2)
                    .rotationEffect(.degrees(handAngle))
                    .animation(isDragging ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: handAngle)
                    
                    // Center knob
                    Circle()
                        .fill(theme.text(.primary))
                        .frame(width: knobSize - 2, height: knobSize - 2)
                        .overlay(
                            Circle()
                                .stroke(viewModel.sessionAccentColor.opacity(0.9), lineWidth: 1)
                        )
                        .scaleEffect(isDragging ? 1.04 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.65), value: isDragging)
                    }
                    .frame(width: dialSize, height: dialSize)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // Allow interaction when idle (user can set new time)
                            if viewModel.timerState == .idle {
                                if !isDragging {
                                    isDragging = true
                                    lastSelectedMinutes = viewModel.selectedMinutes
                                    // Initialize cumulative angle from current minutes
                                    cumulativeDragAngle = AngleUtilities.minutesToAngle(
                                        viewModel.selectedMinutes,
                                        minMinutes: viewModel.minMinutes,
                                        maxMinutes: viewModel.maxMinutes
                                    )
                                    lastDragAngle = AngleUtilities.angleFromPoint(value.location, center: CGPoint(x: dialSize / 2, y: dialSize / 2))
                                    
                                    // Initialize haptic tracking from current position
                                    let currentMinute = Int(viewModel.selectedMinutes)
                                    lastHapticMinute = currentMinute
                                    lastHapticMajorTick = currentMinute / 5
                                    lastHapticTime = Date()
                                    
                                    // Test haptic on drag start (if enabled) to verify generators work
                                    if viewModel.hapticsEnabled {
                                        triggerSelectionHaptic()
                                    }
                                }
                                
                                let center = CGPoint(x: dialSize / 2, y: dialSize / 2)
                                let currentAngle = AngleUtilities.angleFromPoint(value.location, center: center)
                                
                                // Detect wraparound (crossing 0°/360° boundary)
                                var angleDelta = currentAngle - lastDragAngle
                                
                                // Handle wraparound: if angle jumps from ~360° to ~0° (clockwise)
                                if angleDelta < -180.0 {
                                    angleDelta += 360.0
                                }
                                // Handle wraparound: if angle jumps from ~0° to ~360° (counter-clockwise)
                                else if angleDelta > 180.0 {
                                    angleDelta -= 360.0
                                }
                                
                                // Update cumulative angle
                                cumulativeDragAngle += angleDelta
                                
                                // Hard limit at 360° (60 minutes) - prevent going beyond
                                let maxAngle = 360.0  // Hard limit: 1 full rotation = 60 minutes
                                cumulativeDragAngle = max(0, min(maxAngle, cumulativeDragAngle))
                                
                                // Update visual angle for display (modulo 360 for visual rotation)
                                dragAngle = cumulativeDragAngle.truncatingRemainder(dividingBy: 360.0)
                                if dragAngle < 0 {
                                    dragAngle += 360.0
                                }
                                
                                // Calculate minutes from cumulative angle
                                let minutesFloat = (cumulativeDragAngle / 360.0) * 60.0
                                // Round to whole minutes (no seconds)
                                let roundedMinutes = round(minutesFloat)
                                let clampedMinutes = max(viewModel.minMinutes, min(viewModel.maxMinutes, roundedMinutes))
                                
                                // Update local state for smooth display (always whole minutes)
                                dragRemainingSeconds = Int(clampedMinutes * 60)
                                
                                // Haptic feedback logic (only if enabled)
                                if viewModel.hapticsEnabled {
                                    let currentMinute = Int(clampedMinutes)
                                    let currentMajorTick = currentMinute / 5  // 5-minute intervals
                                    let now = Date()
                                    
                                    // Check if we crossed a 5-minute mark (major tick)
                                    if currentMajorTick != lastHapticMajorTick && currentMajorTick >= 0 {
                                        triggerImpactHaptic()
                                        lastHapticMajorTick = currentMajorTick
                                        lastHapticMinute = currentMinute
                                        lastHapticTime = now
                                    }
                                    // Check if we crossed a minute boundary (light feedback)
                                    else if currentMinute != lastHapticMinute && currentMinute >= 0 {
                                        // Throttle continuous feedback
                                        if now.timeIntervalSince(lastHapticTime) >= hapticThrottleInterval {
                                            triggerSelectionHaptic()
                                            lastHapticMinute = currentMinute
                                            lastHapticTime = now
                                        }
                                    }
                                }
                                
                                lastDragAngle = currentAngle
                            }
                        }
                        .onEnded { value in
                            // Allow interaction when idle (user can set new time)
                            if isDragging && viewModel.timerState == .idle {
                                // Use cumulative angle for final calculation
                                // Apply snapping only when drag ends
                                viewModel.setTimeFromAngle(cumulativeDragAngle, force: true)
                            }
                            isDragging = false
                            dragRemainingSeconds = 0  // Reset drag display
                            cumulativeDragAngle = 0
                            lastDragAngle = 0
                            
                            // Reset haptic tracking
                            lastHapticMinute = -1
                            lastHapticMajorTick = -1
                        }
                )
                .accessibilityLabel("Timer dial")
                .accessibilityValue(String(format: "%.2f minutes", viewModel.selectedMinutes))
                
                    // Time display
                    VStack(spacing: 4) {
                    // Show seconds during countdown (running/paused), minutes only when idle
                    let displaySeconds = isDragging ? dragRemainingSeconds : viewModel.remainingSeconds
                    let timeText = (viewModel.timerState == .running || viewModel.timerState == .paused)
                        ? AngleUtilities.formatTime(displaySeconds)  // Show MM:SS during countdown
                        : AngleUtilities.formatTimeMinutesOnly(displaySeconds)  // Show MM:00 when idle
                    
                    Text(timeText)
                        .font(.system(size: 44, weight: .medium, design: .monospaced))
                        .foregroundColor(viewModel.sessionAccentColor)
                        .monospacedDigit()
                        .tracking(2)
                        .shadow(color: viewModel.sessionAccentColor.opacity(0.22), radius: 12, x: 0, y: 0)
                        .accessibilityLabel("Remaining time: \(timeText)")
                    }
                    .padding(.top, 14)
                    
                    Spacer()
                    
                    // Control buttons
                    HStack(spacing: 12) {
                    if viewModel.timerState == .running || viewModel.timerState == .paused {
                        // End button
                        Button(action: {
                            if viewModel.hapticsEnabled {
                                HapticManager.playSelection()
                            }
                            viewModel.resetTimer()
                        }) {
                            Text("End")
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .tracking(0.4)
                                .foregroundColor(theme.destructiveAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.clear)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(theme.destructiveAccent.opacity(0.95), lineWidth: 1)
                                )
                        }
                        .accessibilityLabel("End timer")
                            .buttonStyle(PressableButtonStyle())
                        
                        // Pause/Resume button
                        Button(action: {
                            if viewModel.hapticsEnabled {
                                if viewModel.timerState == .running {
                                    HapticManager.playImpact(style: .light)
                                } else {
                                    HapticManager.playImpact(style: .medium)
                                }
                            }
                            if viewModel.timerState == .running {
                                viewModel.pauseTimer()
                            } else {
                                viewModel.startTimer()
                            }
                        }) {
                            Text(viewModel.timerState == .running ? "Pause" : "Resume")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .tracking(0.5)
                                .foregroundColor(primaryActionLabelColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(viewModel.sessionAccentColor)
                                .cornerRadius(8)
                        }
                        .accessibilityLabel(viewModel.timerState == .running ? "Pause timer" : "Resume timer")
                            .buttonStyle(PressableButtonStyle())
                    } else {
                        // Start button (full width when idle)
                        Button(action: {
                            if viewModel.hapticsEnabled {
                                HapticManager.playImpact(style: .medium)
                            }
                            // Commit dial drag before starting so `selectedMinutes` matches what the user sees
                            // (avoids taps before DragGesture.onEnded updates the view model).
                            if isDragging {
                                viewModel.setTimeFromAngle(cumulativeDragAngle, force: true)
                                isDragging = false
                                dragRemainingSeconds = 0
                                cumulativeDragAngle = 0
                                lastDragAngle = 0
                                lastHapticMinute = -1
                                lastHapticMajorTick = -1
                            }
                            viewModel.startTimer()
                        }) {
                            Text("Start")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .tracking(0.8)
                                .foregroundColor(theme.breakAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(theme.breakAccent.opacity(0.95), lineWidth: 1)
                                )
                        }
                        .accessibilityLabel("Start session")
                            .buttonStyle(PressableButtonStyle(scale: 0.985, opacity: 0.94))
                    }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
                }
            }
        }
        .preferredColorScheme(.dark)
        // Note: Completion alert removed - timer now resets to idle state automatically
        .onAppear {
            viewModel.updateSettings()
            viewModel.syncTimerState()
        }
    }
}

// Helper view to draw swept area (pie slice) for single rotation (0-60 minutes)
struct SweptAreaView: View {
    let totalAngle: Double  // Angle from 0-360° (0-60 minutes)
    let dialSize: CGFloat
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2

            let fillGradient = RadialGradient(
                gradient: Gradient(colors: [
                    color.opacity(0.42),
                    color.opacity(0.30)
                ]),
                center: .center,
                startRadius: 0,
                endRadius: radius
            )

            // Calculate angles and positions outside ViewBuilder branches.
            let startAngleRadians = (270.0 * .pi / 180.0)  // Top in SwiftUI
            let endAngleDegrees = (270.0 + totalAngle).truncatingRemainder(dividingBy: 360.0)
            let endAngleRadians = endAngleDegrees * .pi / 180.0

            if totalAngle > 0.1 {
                if totalAngle >= 360.0 {
                    Circle()
                        .fill(fillGradient)
                        .frame(width: dialSize, height: dialSize)
                        .overlay(
                            Circle()
                                .stroke(color.opacity(0.35), lineWidth: 1)
                        )
                } else {
                    Path { path in
                        path.move(to: center)
                        path.addArc(
                            center: center,
                            radius: radius,
                            startAngle: Angle(radians: Double(startAngleRadians)),
                            endAngle: Angle(radians: Double(endAngleRadians)),
                            clockwise: false
                        )
                        path.closeSubpath()
                    }
                    .fill(fillGradient)
                    .overlay(
                        Path { path in
                            path.move(to: center)
                            path.addArc(
                                center: center,
                                radius: radius,
                                startAngle: Angle(radians: Double(startAngleRadians)),
                                endAngle: Angle(radians: Double(endAngleRadians)),
                                clockwise: false
                            )
                            path.closeSubpath()
                        }
                        .stroke(color.opacity(0.35), lineWidth: 1)
                    )
                }
            }
        }
        .frame(width: dialSize, height: dialSize)
    }
}

// MARK: - Session Blocks View

struct SessionBlocksOverlay: View {
    let geometry: GeometryProxy
    let dayProgress: Double
    let theme: AppTheme
    
    private var todaySessions: [PomodoroSession] {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        guard let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }
        
        let dataStore = PomodoroDataStore.shared
        let allSessions = dataStore.getAllSessions()
        
        return allSessions.filter { session in
            session.sessionType == .work &&
            session.status == .completed &&
            session.startTime >= startOfDay &&
            session.startTime < startOfNextDay
        }
    }
    
    private func calculateDayProgressPosition(for date: Date) -> Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        guard let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return 0.0 }
        
        let elapsed = date.timeIntervalSince(startOfDay)
        let totalDayDuration = startOfNextDay.timeIntervalSince(startOfDay)
        let progress = elapsed / totalDayDuration
        return min(1.0, max(0.0, progress))
    }
    
    private func groupSessionsForStacking(_ sessions: [PomodoroSession], threshold: Double = 0.01) -> [[PomodoroSession]] {
        let sortedSessions = sessions.sorted { session1, session2 in
            let time1 = session1.endTime ?? session1.startTime
            let time2 = session2.endTime ?? session2.startTime
            return time1 < time2
        }
        
        var groups: [[PomodoroSession]] = []
        var currentGroup: [PomodoroSession] = []
        var lastPosition: Double = -1.0
        
        for session in sortedSessions {
            let sessionTime = session.endTime ?? session.startTime
            let position = calculateDayProgressPosition(for: sessionTime)
            
            if lastPosition >= 0 && abs(position - lastPosition) < threshold {
                currentGroup.append(session)
            } else {
                if !currentGroup.isEmpty {
                    groups.append(currentGroup)
                }
                currentGroup = [session]
            }
            lastPosition = position
        }
        
        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }
        
        return groups
    }
    
    private func calculateBlockWidth(for session: PomodoroSession) -> CGFloat {
        // Use the same logic as CalendarView for consistency
        // Priority: activeDuration > actualDuration > plannedDuration
        let durationMinutes: Double
        
        if let activeDuration = session.activeDurationMinutes {
            durationMinutes = activeDuration
        } else if let actualDuration = session.actualDurationMinutes {
            durationMinutes = actualDuration
        } else {
            // Fallback: calculate from startTime to endTime if available
            if let endTime = session.endTime {
                durationMinutes = (endTime.timeIntervalSince(session.startTime) / 60.0)
            } else {
                durationMinutes = session.plannedDurationMinutes
            }
        }
        
        // Linear scale: 1 point per 5 minutes
        // Minimum: 2pt, Maximum: 10pt
        let calculatedWidth = durationMinutes / 5.0
        let clampedWidth = max(2.0, min(10.0, calculatedWidth))
        
        #if DEBUG
        print("Session - planned: \(session.plannedDurationMinutes)min, actual: \(session.actualDurationMinutes?.description ?? "nil"), active: \(session.activeDurationMinutes?.description ?? "nil"), calculated: \(durationMinutes)min, width: \(clampedWidth)pt")
        #endif
        
        return CGFloat(clampedWidth)
    }
    
    var body: some View {
        let sessionGroups = groupSessionsForStacking(todaySessions, threshold: 0.015)
        
        ForEach(Array(sessionGroups.enumerated()), id: \.offset) { groupIndex, group in
            // Render each session individually with its own width and position
            // Add slight offset for stacking when sessions are grouped together
            ForEach(Array(group.enumerated()), id: \.element.id) { sessionIndex, session in
                let sessionTime = session.endTime ?? session.startTime
                let basePosition = calculateDayProgressPosition(for: sessionTime)
                
                // Calculate offset for stacking (spread out slightly if multiple in group)
                let stackOffset: Double = group.count > 1 ? (Double(sessionIndex) - Double(group.count - 1) / 2.0) * 0.002 : 0.0
                let position = basePosition + stackOffset
                
                if position <= dayProgress {
                    SessionBlockView(
                        geometry: geometry,
                        session: session,
                        position: position,
                        blockWidth: calculateBlockWidth(for: session),
                        theme: theme
                    )
                }
            }
        }
    }
}

struct SessionBlockView: View {
    let geometry: GeometryProxy
    let session: PomodoroSession
    let position: Double
    let blockWidth: CGFloat
    let theme: AppTheme
    
    private var blockColor: Color {
        switch session.sessionType {
        case .work:
            return theme.workAccent
        case .shortBreak, .longBreak:
            return theme.breakAccent
        }
    }
    
    var body: some View {
        // Center the block at the completion time position
        let xPosition = geometry.size.width * position
        
        RoundedRectangle(cornerRadius: 1)
            .fill(blockColor)
            .frame(width: blockWidth, height: 10)
            .offset(x: xPosition - blockWidth / 2, y: 0)
    }
}

#Preview {
    TimerView(viewModel: TimerViewModel())
}

