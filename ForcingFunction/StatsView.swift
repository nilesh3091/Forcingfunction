//
//  StatsView.swift
//  ForcingFunction
//
//  Statistics view
//

import SwiftUI

struct StatsView: View {
    @ObservedObject var viewModel: TimerViewModel
    
    private let dataStore = PomodoroDataStore.shared
    private let calendar = Calendar.current
    
    // Start (Monday) and end (Sunday) of the current week
    private var currentWeekRange: (start: Date, end: Date)? {
        let now = Date()
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        guard let startOfWeek = calendar.date(from: components),
              let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek),
              let endOfWeekEndOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfWeek) else {
            return nil
        }
        return (startOfWeek, endOfWeekEndOfDay)
    }
    
    // Completed work sessions for the current week
    private var currentWeekSessions: [PomodoroSession] {
        guard let range = currentWeekRange else { return [] }
        let weekSessions = dataStore.getSessions(from: range.start, to: range.end)
        return weekSessions.filter { $0.sessionType == .work && $0.status == .completed }
    }
    
    // Helper to get effective duration in minutes for a session
    private func durationMinutes(for session: PomodoroSession) -> Double {
        if let active = session.activeDurationMinutes {
            return active
        } else if let actual = session.actualDurationMinutes {
            return actual
        } else {
            return session.plannedDurationMinutes
        }
    }

    // Format like "12th Mar - 18th Mar"
    private func formatWeekRange(start: Date, end: Date) -> String {
        let startDay = calendar.component(.day, from: start)
        let endDay = calendar.component(.day, from: end)
        
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"
        let startMonth = monthFormatter.string(from: start)
        let endMonth = monthFormatter.string(from: end)
        
        let startSuffix = daySuffix(startDay)
        let endSuffix = daySuffix(endDay)
        
        if startMonth == endMonth {
            return "\(startDay)\(startSuffix) \(startMonth) - \(endDay)\(endSuffix) \(endMonth)"
        } else {
            return "\(startDay)\(startSuffix) \(startMonth) - \(endDay)\(endSuffix) \(endMonth)"
        }
    }
    
    private func daySuffix(_ day: Int) -> String {
        let ones = day % 10
        let tens = (day / 10) % 10
        if tens == 1 { return "th" }
        switch ones {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
    
    // Buckets of sessions per weekday (Mon–Sun), each with its total minutes
    private struct DayBucket {
        let date: Date
        let label: String
        let sessions: [PomodoroSession]
        let totalMinutes: Double
    }
    
    private var weeklyBuckets: [DayBucket] {
        guard let range = currentWeekRange else { return [] }
        
        // Build ordered dates for Mon–Sun of this week
        var days: [Date] = []
        var current = range.start
        for _ in 0..<7 {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }
        
        let sessions = currentWeekSessions
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEE"
        
        return days.map { dayStart in
            let dayEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: dayStart) ?? dayStart
            let daySessions = sessions.filter { session in
                session.startTime >= dayStart && session.startTime <= dayEnd
            }
            let total = daySessions.reduce(0.0) { $0 + durationMinutes(for: $1) }
            return DayBucket(
                date: dayStart,
                label: formatter.string(from: dayStart),
                sessions: daySessions,
                totalMinutes: total
            )
        }
    }
    
    // Fixed scale: full bar height = this many minutes (so bar height reflects actual focus time)
    // You can tweak this to 30/45/90 etc. if you want different sensitivity.
    private static let chartScaleMinutes: Double = 30
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This Week")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                        
                        if let range = currentWeekRange {
                            Text(formatWeekRange(start: range.start, end: range.end))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 20)
                        }
                        
                        HStack(alignment: .bottom, spacing: 12) {
                            ForEach(weeklyBuckets.indices, id: \.self) { index in
                                let bucket = weeklyBuckets[index]
                                WeeklyDayBar(
                                    label: bucket.label,
                                    sessions: bucket.sessions,
                                    totalMinutes: bucket.totalMinutes,
                                    scaleMinutes: Self.chartScaleMinutes,
                                    accentColor: viewModel.accentColor
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            WidgetDataManager.shared.updateWidgetData()
        }
    }
}

// Vertical bar made of bricks for one day (Mon–Sun)
private struct WeeklyDayBar: View {
    let label: String
    let sessions: [PomodoroSession]
    let totalMinutes: Double
    /// Full bar height in the chart represents this many minutes (absolute scale).
    let scaleMinutes: Double
    let accentColor: Color
    
    var body: some View {
        VStack(spacing: 6) {
            // Bar
            let maxBarHeight: CGFloat = 180
            let trackWidth: CGFloat = 34
            
            // Bar height = (total minutes / scaleMinutes), capped at full height
            let clampedTotal = max(totalMinutes, 0.0)
            let scale = scaleMinutes > 0 ? min(1.0, clampedTotal / scaleMinutes) : 0
            let barHeight = maxBarHeight * CGFloat(scale)
            
            ZStack(alignment: .bottom) {
                // Background track
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: trackWidth, height: maxBarHeight)
                
                // Bricks stacked vertically, sized by pomodoro length
                if barHeight > 0 && !sessions.isEmpty {
                    VStack(spacing: 2) {
                        ForEach(sessions.indices, id: \.self) { idx in
                            let session = sessions[idx]
                            let duration = max(1.0, durationMinutes(for: session))
                            let fraction = duration / clampedTotal
                            let brickHeight = max(6, barHeight * CGFloat(fraction))
                            
                            RoundedRectangle(cornerRadius: 3)
                                .fill(accentColor.opacity(0.9))
                                .frame(width: trackWidth * 0.75, height: brickHeight)
                        }
                    }
                    .frame(height: barHeight, alignment: .bottom)
                    .frame(maxHeight: maxBarHeight, alignment: .bottom)
                }
            }
            
            // Weekday label
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            // Total focus time label
            if totalMinutes > 0 {
                Text(formatMinutes(totalMinutes))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            } else {
                Text("0m")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
    }
    
    private func durationMinutes(for session: PomodoroSession) -> Double {
        if let active = session.activeDurationMinutes {
            return active
        } else if let actual = session.actualDurationMinutes {
            return actual
        } else {
            return session.plannedDurationMinutes
        }
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let total = Int(round(minutes))
        let hours = total / 60
        let mins = total % 60
        
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 18) {
            // Icon with background
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(0.3)
                
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding(22)
        .background(
            ZStack {
                // Gradient background
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.gray.opacity(0.15),
                                Color.gray.opacity(0.08)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Subtle border
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
        )
        .padding(.horizontal, 20)
    }
}

// (Category views removed)


#Preview {
    StatsView(viewModel: TimerViewModel())
}

