//
//  TimerView.swift
//  ForcingFunction
//
//  Main timer view with interactive circular dial
//

import SwiftUI
import UIKit
import Combine

// Extension to create darker/lighter shades of a color while maintaining full opacity
extension Color {
    func darker(by percentage: CGFloat) -> Color {
        let uiColor = UIColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        brightness = max(0, brightness - percentage)  // Darken by reducing brightness
        
        return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness), opacity: 1.0)
    }
    
    func lighter(by percentage: CGFloat) -> Color {
        let uiColor = UIColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        brightness = min(1.0, brightness + percentage)  // Lighten by increasing brightness
        
        return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness), opacity: 1.0)
    }
}

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
        dayProgress = calculateDayProgress()
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
    
    // Dial geometry
    private let dialSize: CGFloat = 300
    private let knobSize: CGFloat = 20
    private let handLength: CGFloat = 120
    
    // Haptic feedback constants
    private let hapticThrottleInterval: TimeInterval = 0.05  // Max 20 Hz for continuous feedback
    
    var body: some View {
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top status bar area
                HStack {
                    // Focus time display
                    Text(AngleUtilities.formatFocusTime(viewModel.totalFocusMinutes))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                // Main heading
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your day :")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 20)
                    
                    // Day progress bar
                    VStack(spacing: 6) {
                        HStack {
                            Text("\(Int(dayProgress * 100))%")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Spacer()
                            
                            Text(formatTodayFocusTime())
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background bar
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 10)
                                
                                // Progress bar
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(viewModel.accentColor)
                                    .frame(width: geometry.size.width * dayProgress, height: 10)
                                    .animation(.linear(duration: 60.0), value: dayProgress)
                                
                                // Green blocks for completed work sessions
                                SessionBlocksOverlay(
                                    geometry: geometry,
                                    dayProgress: dayProgress
                                )
                            }
                        }
                        .frame(height: 10)
                    }
                    .padding(.horizontal, 20)
                    
                    // Category picker
                    CategoryPickerView(viewModel: viewModel)
                        .padding(.top, 12)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Interactive circular dial
                ZStack {
                    // Outer ring with tick marks
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
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
                            color: viewModel.accentColor  // Full opacity solid color
                        )
                    }
                    
                    // Tick marks
                    ForEach(0..<60) { index in
                        let angle = Double(index) * 6.0 - 90.0 // 6 degrees per minute mark
                        let isMajorTick = index % 5 == 0
                        let tickLength: CGFloat = isMajorTick ? 12 : 6
                        let tickWidth: CGFloat = isMajorTick ? 2 : 1
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: tickWidth, height: tickLength)
                            .offset(y: -dialSize / 2 + tickLength / 2)
                            .rotationEffect(.degrees(angle))
                    }
                    
                    // Progress arc (filled portion)
                    if viewModel.timerState == .running || viewModel.timerState == .paused {
                        Circle()
                            .trim(from: 0, to: viewModel.progress)
                            .stroke(
                                viewModel.accentColor,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: dialSize, height: dialSize)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1.0), value: viewModel.progress)
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
                    
                    // Hand line
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 5, height: handLength)
                        .offset(y: -handLength / 2)
                        .rotationEffect(.degrees(handAngle))
                        .animation(isDragging ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: handAngle)
                    
                    // Center knob
                    Circle()
                        .fill(Color.white)
                        .frame(width: knobSize, height: knobSize)
                        .shadow(color: isDragging ? viewModel.accentColor.opacity(0.8) : Color.clear, radius: 15)
                        .overlay(
                            Circle()
                                .stroke(viewModel.accentColor, lineWidth: 2)
                                .frame(width: knobSize, height: knobSize)
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
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .accessibilityLabel("Remaining time: \(timeText)")
                    
                    Text("session interval")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 30)
                
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
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(12)
                        }
                        .accessibilityLabel("Reset timer")
                        
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
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(viewModel.accentColor)
                                .cornerRadius(12)
                                .shadow(color: viewModel.accentColor.opacity(0.5), radius: 10)
                        }
                        .accessibilityLabel(viewModel.timerState == .running ? "Pause timer" : "Resume timer")
                    } else {
                        // Start button (full width when idle)
                        Button(action: {
                            viewModel.startTimer()
                        }) {
                            Text("START SESSION")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(viewModel.accentColor)
                                .cornerRadius(16)
                                .shadow(color: viewModel.accentColor.opacity(0.6), radius: 15)
                        }
                        .accessibilityLabel("Start session")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
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
            
            // Create pronounced 3D gradient: lighter center, darker edges (solid colors, fully opaque)
            // Increased contrast: 25% lighter center, 45% darker edges
            let lighterColor = color.lighter(by: 0.25)  // 25% lighter at center
            let baseColor = color  // Base color in middle
            let darkerColor = color.darker(by: 0.45)  // 45% darker at edges
            
            // Radial gradient for raised effect
            let radialGradient = RadialGradient(
                gradient: Gradient(colors: [lighterColor, baseColor, darkerColor]),
                center: .center,
                startRadius: 0,
                endRadius: radius
            )
            
            // Calculate all angles and positions BEFORE the conditional (outside ViewBuilder)
            // Use let instead of var to avoid ViewBuilder issues - no mutations allowed in ViewBuilder
            let startAngleRadians = (270.0 * .pi / 180.0)  // Top in SwiftUI
            let endAngleDegrees = (270.0 + totalAngle).truncatingRemainder(dividingBy: 360.0)
            let endAngleRadians = endAngleDegrees * .pi / 180.0
            
            // Calculate highlight position
            let mathAngle = endAngleRadians - (.pi / 2.0)  // Convert to math coordinates
            let highlightCenterX = 0.5 + 0.5 * CGFloat(cos(mathAngle))
            let highlightCenterY = 0.5 + 0.5 * CGFloat(sin(mathAngle))
            let highlightStartAngle = endAngleRadians - (5.0 * .pi / 180.0)  // 5 degrees before end
            
            // Draw pie slice from top (0°) to current angle
            // Handle full circle (360°) and partial arcs
            if totalAngle > 0.1 {
                if totalAngle >= 360.0 {
                    // Full circle - draw complete circle with pronounced 3D gradient and raised effect
                    ZStack {
                        // Base shadow layer (creates depth)
                        Circle()
                            .fill(Color.black.opacity(0.4))
                            .frame(width: dialSize, height: dialSize)
                            .offset(x: 0, y: 4)
                            .blur(radius: 8)
                        
                        // Main circle with gradient
                        Circle()
                            .fill(radialGradient)
                            .frame(width: dialSize, height: dialSize)
                        
                        // Top edge highlight (light from above)
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        lighterColor.opacity(0.8),
                                        Color.clear
                                    ]),
                                    startPoint: .top,
                                    endPoint: .center
                                ),
                                lineWidth: 3
                            )
                            .frame(width: dialSize, height: dialSize)
                    }
                    .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)  // Strong shadow for raised effect
                } else {
                    // Partial arc - draw pie slice with raised/beveled effect
                    ZStack {
                        // Base shadow layer (creates depth - offset downward)
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
                        .fill(Color.black.opacity(0.3))
                        .offset(x: 0, y: 4)  // Offset downward for shadow
                        .blur(radius: 6)
                        
                        // Main pie slice with radial gradient
                        Path { path in
                            path.move(to: center)
                            path.addArc(
                                center: center,
                                radius: radius,
                                startAngle: Angle(radians: Double(startAngleRadians)),
                                endAngle: Angle(radians: Double(endAngleRadians)),
                                clockwise: false  // Counter-clockwise in SwiftUI = clockwise in our system
                            )
                            path.closeSubpath()
                        }
                        .fill(radialGradient)
                        
                        // Top/outer edge highlight (beveled edge - light from above)
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
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    lighterColor.opacity(0.9),
                                    lighterColor.opacity(0.3),
                                    Color.clear
                                ]),
                                startPoint: UnitPoint(
                                    x: 0.5 + 0.5 * CGFloat(cos(startAngleRadians - (.pi / 2.0))),
                                    y: 0.5 + 0.5 * CGFloat(sin(startAngleRadians - (.pi / 2.0)))
                                ),
                                endPoint: .center
                            ),
                            lineWidth: 4
                        )
                        
                        // Bottom/inner edge shadow (beveled edge - shadow for depth)
                        Path { path in
                            path.move(to: center)
                            path.addArc(
                                center: center,
                                radius: radius - 2,
                                startAngle: Angle(radians: Double(startAngleRadians)),
                                endAngle: Angle(radians: Double(endAngleRadians)),
                                clockwise: false
                            )
                            path.closeSubpath()
                        }
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    darkerColor.opacity(0.6),
                                    Color.clear
                                ]),
                                startPoint: .center,
                                endPoint: UnitPoint(
                                    x: 0.5 + 0.5 * CGFloat(cos(endAngleRadians - (.pi / 2.0))),
                                    y: 0.5 + 0.5 * CGFloat(sin(endAngleRadians - (.pi / 2.0)))
                                )
                            ),
                            lineWidth: 3
                        )
                        
                        // Highlight along the leading edge (where the arm is)
                        Path { path in
                            path.move(to: center)
                            path.addArc(
                                center: center,
                                radius: radius,
                                startAngle: Angle(radians: Double(highlightStartAngle)),
                                endAngle: Angle(radians: Double(endAngleRadians)),
                                clockwise: false
                            )
                            path.closeSubpath()
                        }
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    lighterColor.opacity(0.9),
                                    lighterColor.opacity(0.4)
                                ]),
                                center: UnitPoint(x: highlightCenterX, y: highlightCenterY),
                                startRadius: 0,
                                endRadius: radius
                            )
                        )
                    }
                    .shadow(color: Color.black.opacity(0.5), radius: 18, x: 0, y: 8)  // Strong shadow for raised effect
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
                        blockWidth: calculateBlockWidth(for: session)
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
    
    var body: some View {
        // Center the block at the completion time position
        let xPosition = geometry.size.width * position
        
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.green)
            .frame(width: blockWidth, height: 10)
            .offset(x: xPosition - blockWidth / 2, y: 0)
    }
}

// MARK: - Category Picker View

struct CategoryPickerView: View {
    @ObservedObject var viewModel: TimerViewModel
    
    private let categoryManager = CategoryManager.shared
    
    private var isDisabled: Bool {
        viewModel.timerState != .idle
    }
    
    private var activeCategories: [Category] {
        categoryManager.getActiveCategories()
    }
    
    private var selectedCategory: Category? {
        guard let id = viewModel.selectedCategoryId else { return nil }
        return categoryManager.getCategory(byId: id)
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // No Category chip
                CategoryChipView(
                    title: "No Category",
                    color: .gray,
                    isSelected: viewModel.selectedCategoryId == nil,
                    isDisabled: isDisabled,
                    action: {
                        guard !isDisabled else { return }
                        viewModel.selectedCategoryId = nil
                    }
                )
                
                // Category chips
                ForEach(activeCategories) { category in
                    CategoryChipView(
                        title: category.name,
                        color: category.color.color,
                        isSelected: viewModel.selectedCategoryId == category.id,
                        isDisabled: isDisabled,
                        action: {
                            guard !isDisabled else { return }
                            viewModel.selectedCategoryId = category.id
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.selectedCategoryId)
    }
}

struct CategoryChipView: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // Color indicator circle
                Circle()
                    .fill(isDisabled ? color.opacity(0.4) : color)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(
                                isSelected && !isDisabled
                                    ? Color.white.opacity(0.4)
                                    : Color.white.opacity(0.15),
                                lineWidth: isSelected && !isDisabled ? 1 : 0.5
                            )
                    )
                    .shadow(
                        color: isSelected && !isDisabled
                            ? color.opacity(0.6)
                            : Color.clear,
                        radius: isSelected && !isDisabled ? 3 : 0
                    )
                
                // Category name
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(
                        isDisabled
                            ? .white.opacity(0.4)
                            : (isSelected ? .white : .white.opacity(0.8))
                    )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isSelected && !isDisabled
                            ? color.opacity(0.2)
                            : Color.gray.opacity(isDisabled ? 0.08 : 0.12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected && !isDisabled
                                    ? color.opacity(0.6)
                                    : Color.gray.opacity(isDisabled ? 0.15 : 0.25),
                                lineWidth: isSelected && !isDisabled ? 1 : 0.5
                            )
                    )
            )
            .shadow(
                color: isSelected && !isDisabled
                    ? color.opacity(0.4)
                    : Color.clear,
                radius: isSelected && !isDisabled ? 5 : 0,
                x: 0,
                y: 2
            )
            .scaleEffect(isSelected && !isDisabled ? 1.05 : 1.0)
        }
        .disabled(isDisabled)
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    TimerView(viewModel: TimerViewModel())
}

