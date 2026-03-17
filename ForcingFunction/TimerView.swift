//
//  TimerView.swift
//  ForcingFunction
//
//  Main timer view with interactive circular dial
//

import SwiftUI
import UIKit
import Combine

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
    
    // Day progress tracking
    @State private var dayProgress: Double = 0.0  // 0.0 to 1.0 (0% to 100%)
    @State private var isInitialLoad: Bool = true  // Track if this is the first progress update
    
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
    
    // Day progress calculation
    private func calculateDayProgress() -> Double {
        let calendar = Calendar.current
        let now = Date()
        
        // Get start of today (midnight) - returns non-optional Date
        let startOfDay = calendar.startOfDay(for: now)
        
        // Get start of next day (next midnight)
        guard let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return 0.0 }
        
        // Calculate elapsed time since midnight
        let elapsed = now.timeIntervalSince(startOfDay)
        
        // Calculate total time in the day (24 hours)
        let totalDayDuration = startOfNextDay.timeIntervalSince(startOfDay)
        
        // Calculate progress (0.0 to 1.0)
        let progress = elapsed / totalDayDuration
        return min(1.0, max(0.0, progress))
    }
    
    private func updateDayProgress() {
        let newProgress = calculateDayProgress()
        // On initial load, update instantly without animation
        if isInitialLoad {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                dayProgress = newProgress
            }
            isInitialLoad = false
        } else {
            // Subsequent updates animate smoothly over 60 seconds
            dayProgress = newProgress
        }
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
                // Dark background
                theme.background(.primary)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Main heading
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(theme.text(.primary))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 20)
                        
                        // Day progress bar
                        VStack(spacing: 6) {
                            HStack {
                                Text("Focused \(formatTodayFocusTime())")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(theme.text(.secondary))
                                
                                Spacer()
                                
                                Text("\(Int(dayProgress * 100))%")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(theme.text(.tertiary))
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Background bar
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(theme.background(.tertiary))
                                        .frame(height: 6)
                                    
                                    // Progress bar
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(theme.accent(opacity: 0.9))
                                        .frame(width: geometry.size.width * dayProgress, height: 6)
                                        .animation(.linear(duration: 60.0), value: dayProgress)
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Interactive circular dial
                    ZStack {
                    // Outer ring with tick marks
                    Circle()
                        .stroke(theme.borderPrimary, lineWidth: 2)
                        .frame(width: dialSize, height: dialSize)
                    
                    // Swept area fill (pie slice showing covered area)
                    // Show when idle (full size) or running/paused (shrinking as time progresses)
                    let pieAngle: Double = {
                        if viewModel.timerState == .idle {
                            // When idle, show full selected time
                            let currentTotalAngle = isDragging ? cumulativeDragAngle : viewModel.currentAngle
                            return min(currentTotalAngle, 360.0)  // Hard limit at 360° (60 minutes)
                        } else {
                            // When running/paused, show remaining time (shrinking pie)
                            let remainingAngle = viewModel.currentAngle * (1.0 - viewModel.progress)
                            return max(0, min(remainingAngle, 360.0))
                        }
                    }()
                    
                    if pieAngle > 0 {
                        // Full opacity solid color for swept area
                        SweptAreaView(
                            totalAngle: pieAngle,
                            dialSize: dialSize,
                            color: theme.accentColor  // Full opacity solid color
                        )
                    }
                    
                    // Tick marks (minor every 1 minute, major every 5 minutes)
                    ForEach(0..<60) { minute in
                        let angle = (Double(minute) * 6.0) - 90.0
                        let isMajor = minute % 5 == 0
                        let tickLength: CGFloat = isMajor ? 12 : 6
                        let tickWidth: CGFloat = isMajor ? 2 : 1
                        let tickColor = theme.text(.tertiary, opacity: isMajor ? 0.75 : 0.35)

                        RoundedRectangle(cornerRadius: tickWidth)
                            .fill(tickColor)
                            .frame(width: tickWidth, height: tickLength)
                            .offset(y: -dialSize / 2 + tickLength / 2)
                            .rotationEffect(.degrees(angle))
                    }
                    
                    // Progress arc (filled portion)
                    if viewModel.timerState == .running || viewModel.timerState == .paused {
                        Circle()
                            .trim(from: 0, to: viewModel.progress)
                            .stroke(
                                theme.accentColor,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: dialSize, height: dialSize)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1.0), value: viewModel.progress)
                    }

                    // Progress head: circular endcap with percent
                    if viewModel.timerState == .running || viewModel.timerState == .paused {
                        let angle = (viewModel.progress * 360.0) - 90.0
                        let r = (dialSize / 2)
                        let x = (dialSize / 2) + (CGFloat(cos(angle * .pi / 180.0)) * r)
                        let y = (dialSize / 2) + (CGFloat(sin(angle * .pi / 180.0)) * r)
                        let pctA11y = Int((viewModel.progress * 100).rounded())
                        let headSize: CGFloat = 28

                        ZStack {
                            Circle()
                                .fill(theme.accentColor)
                                .shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 5)

                            Color.clear
                                .modifier(AnimatedPercentText(percent: viewModel.progress * 100))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.95))
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
                    
                    // Hand/needle (slim, calm)
                    ZStack {
                        Capsule(style: .continuous)
                            .fill(theme.text(.primary, opacity: 0.92))
                            .frame(width: 3, height: handLength)

                        Circle()
                            .fill(theme.accent(opacity: 0.85))
                            .frame(width: 6, height: 6)
                            .offset(y: -handLength / 2 + 6)
                    }
                    .offset(y: -handLength / 2)
                    .rotationEffect(.degrees(handAngle))
                    .animation(isDragging ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: handAngle)
                    
                    // Center knob
                    Circle()
                        .fill(theme.text(.primary))
                        .frame(width: knobSize, height: knobSize)
                        .shadow(color: isDragging ? theme.accent(opacity: 0.35) : Color.clear, radius: 10, x: 0, y: 6)
                        .overlay(
                            ZStack {
                                Circle()
                                    .stroke(theme.accentColor, lineWidth: 2)
                                    .frame(width: knobSize, height: knobSize)
                            }
                        )
                        .scaleEffect(isDragging ? 1.1 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isDragging)
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
                                viewModel.setTimeFromAngle(cumulativeDragAngle)
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
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(theme.text(.primary))
                        .monospacedDigit()
                        .accessibilityLabel("Remaining time: \(timeText)")
                    }
                    .padding(.top, 18)
                    
                    Spacer()
                    
                    // Control buttons
                    HStack(spacing: 20) {
                    if viewModel.timerState == .running || viewModel.timerState == .paused {
                        // Reset button
                        Button(action: {
                            viewModel.resetTimer()
                        }) {
                            Text("Reset")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(theme.buttonSecondaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(theme.buttonSecondary)
                                .cornerRadius(12)
                        }
                        .accessibilityLabel("Reset timer")
                            .buttonStyle(PressableButtonStyle())
                        
                        // Pause/Resume button
                        Button(action: {
                            if viewModel.timerState == .running {
                                viewModel.pauseTimer()
                            } else {
                                viewModel.startTimer()
                            }
                        }) {
                            Text(viewModel.timerState == .running ? "Pause" : "Resume")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(theme.buttonPrimaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(theme.buttonPrimary)
                                .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 6)
                        }
                        .accessibilityLabel(viewModel.timerState == .running ? "Pause timer" : "Resume timer")
                            .buttonStyle(PressableButtonStyle())
                    } else {
                        // Start button (full width when idle)
                        Button(action: {
                            viewModel.startTimer()
                        }) {
                                Text("Start")
                                    .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(theme.buttonPrimaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(theme.buttonPrimary)
                                .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.24), radius: 12, x: 0, y: 7)
                        }
                        .accessibilityLabel("Start session")
                            .buttonStyle(PressableButtonStyle(scale: 0.985, opacity: 0.94))
                    }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
        // Note: Completion alert removed - timer now resets to idle state automatically
        .onAppear {
            viewModel.updateSettings()
            viewModel.syncTimerState()
            updateDayProgress()
        }
        .onReceive(Timer.publish(every: 60.0, on: .main, in: .common).autoconnect()) { _ in
            updateDayProgress()
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

            // Minimal, calm fill: low-contrast gradient with subtle edge definition.
            let fillGradient = RadialGradient(
                gradient: Gradient(colors: [
                    color.opacity(0.26),
                    color.opacity(0.18)
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
                                .stroke(color.opacity(0.22), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
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
                        .stroke(color.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 5)
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
    
    var body: some View {
        // Center the block at the completion time position
        let xPosition = geometry.size.width * position
        
        RoundedRectangle(cornerRadius: 1)
            .fill(theme.success)
            .frame(width: blockWidth, height: 10)
            .offset(x: xPosition - blockWidth / 2, y: 0)
    }
}

#Preview {
    TimerView(viewModel: TimerViewModel())
}

