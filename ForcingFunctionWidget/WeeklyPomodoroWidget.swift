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
    let weeklyGoalMinutes: Int
    let dailyTotals: [Int] // [Mon, Tue, Wed, Thu, Fri, Sat, Sun]
    let accentColor: String // "Red", "Blue", or "Green"
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
        .description("Track your weekly Pomodoro focus time and daily progress.")
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
            weeklyGoalMinutes: 1200,
            dailyTotals: [30, 45, 0, 50, 0, 0, 0],
            accentColor: "Red"
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
                weeklyGoalMinutes: 1200,
                dailyTotals: [0, 0, 0, 0, 0, 0, 0],
                accentColor: "Red"
            )
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let widgetData = try? decoder.decode(WeeklyWidgetData.self, from: data) else {
            return WeeklyPomodoroEntry(
                date: Date(),
                currentWeekTotalMinutes: 0,
                weeklyGoalMinutes: 1200,
                dailyTotals: [0, 0, 0, 0, 0, 0, 0],
                accentColor: "Red"
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
                weeklyGoalMinutes: widgetData.weeklyGoalMinutes, // Keep the goal setting
                dailyTotals: [0, 0, 0, 0, 0, 0, 0],
                accentColor: widgetData.accentColor // Keep the accent color
            )
        }
        
        return WeeklyPomodoroEntry(
            date: widgetData.lastUpdated,
            currentWeekTotalMinutes: widgetData.currentWeekTotalMinutes,
            weeklyGoalMinutes: widgetData.weeklyGoalMinutes,
            dailyTotals: widgetData.dailyTotals,
            accentColor: widgetData.accentColor
        )
    }
}

struct WeeklyPomodoroEntry: TimelineEntry {
    let date: Date
    let currentWeekTotalMinutes: Int
    let weeklyGoalMinutes: Int
    let dailyTotals: [Int] // [Mon, Tue, Wed, Thu, Fri, Sat, Sun]
    let accentColor: String
}

struct WeeklyPomodoroWidgetEntryView: View {
    var entry: WeeklyPomodoroEntry
    
    var accentColor: Color {
        switch entry.accentColor {
        case "Blue":
            return .blue
        case "Green":
            return .green
        default:
            return .red
        }
    }
    
    var progress: Double {
        guard entry.weeklyGoalMinutes > 0 else { return 0 }
        return min(1.0, Double(entry.currentWeekTotalMinutes) / Double(entry.weeklyGoalMinutes))
    }
    
    var maxDailyTotal: Int {
        entry.dailyTotals.max() ?? 1
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Left: Circular Progress
            VStack {
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            accentColor,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear, value: progress)
                    
                        // Time text
                        VStack(spacing: 0) {
                            Text(formatTime(entry.currentWeekTotalMinutes))
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                }
                .frame(width: 120, height: 120)
            }
            
            // Right: Weekly Goal and Daily Breakdown
            VStack(alignment: .leading, spacing: 8) {
                // Weekly goal
                Text("Weekly goal: \(formatTimeGoal(entry.weeklyGoalMinutes))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Daily bars
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<7) { index in
                        VStack(spacing: 2) {
                    // Bar
                    let dailyMinutes = entry.dailyTotals[index]
                    let maxBarHeight: CGFloat = 36.0
                    let minBarHeight: CGFloat = 2.4
                    let barHeight = maxDailyTotal > 0 
                        ? max(minBarHeight, CGFloat(dailyMinutes) / CGFloat(maxDailyTotal) * maxBarHeight)
                        : minBarHeight
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(dailyMinutes > 0 ? accentColor : Color.gray.opacity(0.3))
                        .frame(width: 9.6, height: barHeight)
                            
                            // Day label
                            Text(dayAbbreviation(index))
                                .font(.system(size: 9, weight: .regular))
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

#Preview(as: .systemMedium) {
    WeeklyPomodoroWidget()
} timeline: {
    WeeklyPomodoroEntry(
        date: Date(),
        currentWeekTotalMinutes: 125,
        weeklyGoalMinutes: 1200,
        dailyTotals: [30, 45, 0, 50, 0, 0, 0],
        accentColor: "Red"
    )
    WeeklyPomodoroEntry(
        date: Date(),
        currentWeekTotalMinutes: 0,
        weeklyGoalMinutes: 1200,
        dailyTotals: [0, 0, 0, 0, 0, 0, 0],
        accentColor: "Blue"
    )
}

