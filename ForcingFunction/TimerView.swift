//
//  TimerView.swift
//  ForcingFunction
//
//  Main timer view with interactive circular dial
//

import SwiftUI
import UIKit

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
    @State private var showingCompletionAlert = false
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
                VStack(spacing: 8) {
                    Text("What's your focus?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Progress dots (placeholder - can be enhanced)
                    HStack(spacing: 6) {
                        ForEach(0..<10) { index in
                            Circle()
                                .fill(index < 2 ? viewModel.accentColor : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                    
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
                    let handAngle = viewModel.timerState == .running || viewModel.timerState == .paused
                        ? {
                            let angle = viewModel.elapsedAngle.truncatingRemainder(dividingBy: 360.0)
                            return angle < 0 ? angle + 360.0 : angle
                        }()
                        : displayAngle
                    
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
                            if viewModel.timerState == .completed {
                                showingCompletionAlert = true
                            } else {
                                viewModel.startTimer()
                            }
                        }) {
                            Text(viewModel.timerState == .completed ? "Start Next" : "START SESSION")
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
        .alert("Session Complete!", isPresented: $showingCompletionAlert) {
            Button("Start Next") {
                viewModel.startNextSession()
            }
            Button("Dismiss", role: .cancel) {
                viewModel.timerState = .idle
            }
        } message: {
            Text("Your \(viewModel.currentSessionType.displayName) session has finished!")
        }
        .onChange(of: viewModel.timerState) { oldValue, newState in
            if newState == .completed && !viewModel.autoStartNext {
                showingCompletionAlert = true
            }
        }
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
        Menu {
            // No Category option
            Button(action: {
                viewModel.selectedCategoryId = nil
            }) {
                HStack {
                    Circle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 12, height: 12)
                    Text("No Category")
                    if viewModel.selectedCategoryId == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .disabled(isDisabled)
            
            if !activeCategories.isEmpty {
                Divider()
                
                // Active categories
                ForEach(activeCategories) { category in
                    Button(action: {
                        viewModel.selectedCategoryId = category.id
                    }) {
                        HStack {
                            Circle()
                                .fill(category.color.color)
                                .frame(width: 12, height: 12)
                            Text(category.name)
                            if viewModel.selectedCategoryId == category.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(isDisabled)
                }
            }
        } label: {
            HStack(spacing: 8) {
                if let category = selectedCategory {
                    Circle()
                        .fill(isDisabled ? category.color.color.opacity(0.5) : category.color.color)
                        .frame(width: 16, height: 16)
                    Text(category.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isDisabled ? .white.opacity(0.5) : .white)
                } else {
                    Circle()
                        .fill(Color.gray.opacity(isDisabled ? 0.3 : 0.5))
                        .frame(width: 16, height: 16)
                    Text("No Category")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isDisabled ? .white.opacity(0.4) : .white.opacity(0.7))
                }
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isDisabled ? .white.opacity(0.3) : .white.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(isDisabled ? 0.08 : 0.15))
            )
        }
        .disabled(isDisabled)
    }
}

#Preview {
    TimerView(viewModel: TimerViewModel())
}

