//
//  WeeklyPomodoroWidget.swift
//  ForcingFunctionWidget
//
//  Widget showing weekly Pomodoro progress
//

import WidgetKit
import SwiftUI

// Shared data structure - must match WidgetDataManager.swift
struct WeeklyWidgetData: Codable {
    let currentWeekTotalMinutes: Int
    let todayFocusMinutes: Int
    let dailyFocusGoalMinutes: Int
    let dailyTotals: [Int] // [Mon, Tue, Wed, Thu, Fri, Sat, Sun]
    /// Legacy Codable field; UI uses fixed cyan (`AppTheme.standard.workAccent`).
    let accentColor: String
    let lastUpdated: Date
}

struct WeeklyPomodoroWidget: Widget {
    let kind: String = "WeeklyPomodoroWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeeklyPomodoroTimelineProvider()) { entry in
            WeeklyPomodoroWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Weekly Pomodoro")
        .description("See today’s progress toward your daily focus goal and your week at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

struct WeeklyPomodoroTimelineProvider: TimelineProvider {
    typealias Entry = WeeklyPomodoroEntry
    
    /// Get the start of the current week (Monday at 00:00:00)
    /// This explicitly calculates Monday regardless of calendar's firstWeekday setting
    private func getStartOfCurrentWeek(calendar: Calendar, from date: Date) -> Date {
        let today = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: today)
        // Calendar weekday: 1=Sunday, 2=Monday, ..., 7=Saturday
        // Calculate days back to Monday (0 = Monday, 6 = Sunday)
        let daysFromMonday = (weekday == 1) ? 6 : weekday - 2
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today
    }
    
    /// Check if a date is within the current week (Monday-Sunday)
    private func isDateInCurrentWeek(_ date: Date, calendar: Calendar) -> Bool {
        let now = Date()
        let startOfCurrentWeek = getStartOfCurrentWeek(calendar: calendar, from: now)
        let endOfCurrentWeek = calendar.date(byAdding: .day, value: 6, to: startOfCurrentWeek)!
        let endOfWeekEndOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfCurrentWeek) ?? endOfCurrentWeek
        return date >= startOfCurrentWeek && date <= endOfWeekEndOfDay
    }
    
    func placeholder(in context: Context) -> WeeklyPomodoroEntry {
        WeeklyPomodoroEntry(
            date: Date(),
            currentWeekTotalMinutes: 125,
            todayFocusMinutes: 45,
            dailyFocusGoalMinutes: 120,
            dailyTotals: [30, 45, 0, 50, 0, 0, 0],
            accentColor: "Cyan"
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (WeeklyPomodoroEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry = loadEntry()
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate next refresh times
        // 1. Refresh at midnight tonight
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
        
        // 2. Refresh at start of next week (Monday at 00:00:00)
        let startOfCurrentWeek = getStartOfCurrentWeek(calendar: calendar, from: now)
        let startOfNextWeek = calendar.date(byAdding: .day, value: 7, to: startOfCurrentWeek)!
        
        // Use whichever comes first: midnight or start of next week
        let nextRefresh = min(tomorrow, startOfNextWeek)
        
        // Create timeline entry for now
        var entries: [Entry] = [entry]
        
        // If next week starts before tomorrow, also add an entry for midnight
        // This ensures the widget updates at both boundaries
        if startOfNextWeek > tomorrow {
            // Add midnight entry (will show current week data until next week starts)
            entries.append(entry)
        }
        
        let timeline = Timeline(entries: entries, policy: .after(nextRefresh))
        completion(timeline)
    }
    
    private func loadEntry() -> WeeklyPomodoroEntry {
        // App Group identifier - must match WidgetDataManager
        let appGroupIdentifier = "group.com.forcingfunction.shared"
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        let calendar = Calendar.current
        
        guard let data = defaults?.data(forKey: "weeklyWidgetData") else {
            // Return empty entry if no data
            return WeeklyPomodoroEntry(
                date: Date(),
                currentWeekTotalMinutes: 0,
                todayFocusMinutes: 0,
                dailyFocusGoalMinutes: 120,
                dailyTotals: [0, 0, 0, 0, 0, 0, 0],
                accentColor: "Cyan"
            )
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let widgetData = try? decoder.decode(WeeklyWidgetData.self, from: data) else {
            return WeeklyPomodoroEntry(
                date: Date(),
                currentWeekTotalMinutes: 0,
                todayFocusMinutes: 0,
                dailyFocusGoalMinutes: 120,
                dailyTotals: [0, 0, 0, 0, 0, 0, 0],
                accentColor: "Cyan"
            )
        }
        
        // Check if the data is stale (from a previous week)
        // If lastUpdated is not in the current week, return empty data for current week
        if !isDateInCurrentWeek(widgetData.lastUpdated, calendar: calendar) {
            // Data is from a previous week - return empty entry for current week
            // The app will recalculate when a new session completes
            return WeeklyPomodoroEntry(
                date: Date(),
                currentWeekTotalMinutes: 0,
                todayFocusMinutes: 0,
                dailyFocusGoalMinutes: widgetData.dailyFocusGoalMinutes,
                dailyTotals: [0, 0, 0, 0, 0, 0, 0],
                accentColor: widgetData.accentColor
            )
        }
        
        return WeeklyPomodoroEntry(
            date: widgetData.lastUpdated,
            currentWeekTotalMinutes: widgetData.currentWeekTotalMinutes,
            todayFocusMinutes: widgetData.todayFocusMinutes,
            dailyFocusGoalMinutes: widgetData.dailyFocusGoalMinutes,
            dailyTotals: widgetData.dailyTotals,
            accentColor: widgetData.accentColor
        )
    }
}

struct WeeklyPomodoroEntry: TimelineEntry {
    let date: Date
    let currentWeekTotalMinutes: Int
    let todayFocusMinutes: Int
    let dailyFocusGoalMinutes: Int
    let dailyTotals: [Int] // [Mon, Tue, Wed, Thu, Fri, Sat, Sun]
    let accentColor: String
}

struct WeeklyPomodoroWidgetEntryView: View {
    var entry: WeeklyPomodoroEntry
    
    /// Matches main app `AppTheme.standard.workAccent` (~`#42d7ff`).
    private var widgetAccentColor: Color {
        Color(red: 66.0 / 255.0, green: 215.0 / 255.0, blue: 1.0)
    }
    
    var progress: Double {
        guard entry.dailyFocusGoalMinutes > 0 else { return 0 }
        return min(1.0, Double(entry.todayFocusMinutes) / Double(entry.dailyFocusGoalMinutes))
    }
    
    var maxDailyTotal: Int {
        entry.dailyTotals.max() ?? 1
    }
    
    var body: some View {
        HStack(spacing: 24) {
            // Left: Circular Progress
            VStack {
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            widgetAccentColor,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear, value: progress)
                    
                    // Content inside ring: percentage centered, time at bottom
                    ZStack {
                        // Percentage centered - thinner font weight
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 32, weight: .medium, design: .default))
                            .foregroundColor(.white)
                        
                        // Time at bottom - keep at same position
                        VStack {
                            Spacer()
                            Text(formatTime(entry.todayFocusMinutes))
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.bottom, 18)
                        }
                    }
                }
                .frame(width: 125, height: 125)
            }
            
            // Right: Daily goal + weekly chart
            VStack(alignment: .leading, spacing: 8) {
                Text("Daily goal: \(formatTimeGoal(entry.dailyFocusGoalMinutes))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                
                Text("This week: \(formatTime(entry.currentWeekTotalMinutes))")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.75))
                
                Spacer()
                
                // Daily bars
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<7) { index in
                        VStack(spacing: 2) {
                    // Bar with logarithmic scaling for better visibility of small values
                    let dailyMinutes = entry.dailyTotals[index]
                    let maxBarHeight: CGFloat = 51.84  // Increased by 20% for more pronounced differences
                    let minBarHeight: CGFloat = 3.456  // Increased by 20% to maintain proportions
                    let barHeight: CGFloat = {
                        if dailyMinutes == 0 {
                            return minBarHeight
                        }
                        guard maxDailyTotal > 0 else { return minBarHeight }
                        // Logarithmic scaling: log(1 + value) / log(1 + max) * maxHeight
                        // This compresses large differences, making small values more visible
                        let logValue = log(1.0 + Double(dailyMinutes))
                        let logMax = log(1.0 + Double(maxDailyTotal))
                        let scaledHeight = (logValue / logMax) * maxBarHeight
                        return max(minBarHeight, scaledHeight)
                    }()
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(dailyMinutes > 0 ? widgetAccentColor : Color.gray.opacity(0.3))
                        .frame(width: 11.52, height: barHeight)
                            
                            // Day label
                            Text(dayAbbreviation(index))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .widgetURL(URL(string: "forcingfunction://stats"))
    }
    
    private func dayAbbreviation(_ index: Int) -> String {
        let days = ["M", "T", "W", "T", "F", "S", "S"]
        return days[index]
    }
    
    private func formatTime(_ minutes: Int) -> String {
        if minutes == 0 {
            return "0m"
        }
        
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
    
    private func formatTimeGoal(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
}

