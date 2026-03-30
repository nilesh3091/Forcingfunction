//
//  WidgetDataManager.swift
//  ForcingFunction
//
//  Manages shared data between app and widget extension
//

import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

struct WeeklyWidgetData: Codable {
    let currentWeekTotalMinutes: Int
    /// Completed work focus minutes for the current calendar day (matches main timer “today”).
    let todayFocusMinutes: Int
    /// Single daily target in minutes (same as Settings → Focus goal).
    let dailyFocusGoalMinutes: Int
    let dailyTotals: [Int] // [Mon, Tue, Wed, Thu, Fri, Sat, Sun]
    /// Legacy key for Codable compatibility; widget UI uses fixed work accent (cyan).
    let accentColor: String
    let lastUpdated: Date
}

class WidgetDataManager {
    static let shared = WidgetDataManager()
    
    // App Group identifier - needs to match in Xcode project settings
    private let appGroupIdentifier = "group.com.forcingfunction.shared"
    
    private let widgetDataKey = "weeklyWidgetData"
    
    private init() {}
    
    // MARK: - Shared UserDefaults
    
    private var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupIdentifier)
    }
    
    // MARK: - Calculate and Store Weekly Data
    
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
    func isDateInCurrentWeek(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let startOfCurrentWeek = getStartOfCurrentWeek(calendar: calendar, from: now)
        let endOfCurrentWeek = calendar.date(byAdding: .day, value: 6, to: startOfCurrentWeek)!
        let endOfWeekEndOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfCurrentWeek) ?? endOfCurrentWeek
        return date >= startOfCurrentWeek && date <= endOfWeekEndOfDay
    }
    
    /// Calculate weekly totals and store in shared UserDefaults
    func updateWidgetData() {
        let dataStore = PomodoroDataStore.shared
        let calendar = Calendar.current
        let now = Date()
        
        // Get start of current week (Monday at 00:00:00) - explicitly calculate Monday
        let startOfWeek = getStartOfCurrentWeek(calendar: calendar, from: now)
        
        // Get end of week (Sunday at 23:59:59)
        guard let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) else { return }
        let endOfWeekEndOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfWeek) ?? endOfWeek
        
        // Get all sessions for the week
        let weekSessions = dataStore.getSessions(from: startOfWeek, to: endOfWeekEndOfDay)
        let completedWorkSessions = weekSessions.filter { $0.sessionType == .work && $0.status == .completed }
        
        // Calculate total for the week
        let totalMinutes = completedWorkSessions.compactMap { session -> Double? in
            return session.activeDurationMinutes
        }.reduce(0, +)
        let currentWeekTotalMinutes = Int(totalMinutes)
        
        // Calculate daily totals (Mon-Sun)
        var dailyTotals: [Int] = [0, 0, 0, 0, 0, 0, 0]
        
        #if DEBUG
        print("WidgetDataManager: Found \(completedWorkSessions.count) completed work sessions this week")
        print("WidgetDataManager: Week range: \(startOfWeek) to \(endOfWeekEndOfDay)")
        print("WidgetDataManager: Total minutes this week: \(currentWeekTotalMinutes)")
        print("WidgetDataManager: Daily totals: \(dailyTotals)")
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        for (index, total) in dailyTotals.enumerated() {
            if total > 0 {
                print("WidgetDataManager:   \(dayNames[index]): \(total) minutes")
            }
        }
        #endif
        
        for session in completedWorkSessions {
            guard let activeMinutes = session.activeDurationMinutes else { continue }
            let sessionDate = session.startTime
            
            // Validate session is within the week range (safety check)
            guard sessionDate >= startOfWeek && sessionDate <= endOfWeekEndOfDay else {
                #if DEBUG
                print("WidgetDataManager: Warning - Session outside week range: \(sessionDate)")
                #endif
                continue
            }
            
            // Get day of week (1 = Sunday, 2 = Monday, ..., 7 = Saturday)
            let weekday = calendar.component(.weekday, from: sessionDate)
            // Convert to our array index (0 = Monday, 6 = Sunday)
            let index = (weekday == 1) ? 6 : weekday - 2
            
            // Validate index is within bounds
            guard index >= 0 && index < 7 else {
                #if DEBUG
                print("WidgetDataManager: Warning - Invalid weekday index \(index) for weekday \(weekday), session: \(sessionDate)")
                #endif
                continue
            }
            
            dailyTotals[index] += Int(activeMinutes)
            
            #if DEBUG
            let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            print("WidgetDataManager: Session on \(sessionDate): weekday=\(weekday) (\(dayNames[index])), minutes=\(Int(activeMinutes))")
            #endif
        }
        
        let todayFocusMinutes = dataStore.getTodayCompletedWorkFocusMinutes()
        let dailyFocusGoalMinutes: Int
        if UserDefaults.standard.object(forKey: "dailyFocusGoalMinutes") == nil {
            dailyFocusGoalMinutes = AppSettings.defaultDailyFocusGoalMinutes
        } else {
            dailyFocusGoalMinutes = UserDefaults.standard.integer(forKey: "dailyFocusGoalMinutes")
        }
        
        // Create widget data (accent key kept for Codable; widget renders fixed cyan)
        let widgetData = WeeklyWidgetData(
            currentWeekTotalMinutes: currentWeekTotalMinutes,
            todayFocusMinutes: todayFocusMinutes,
            dailyFocusGoalMinutes: dailyFocusGoalMinutes,
            dailyTotals: dailyTotals,
            accentColor: "Cyan",
            lastUpdated: now
        )
        
        // Save to shared UserDefaults
        saveWidgetData(widgetData)
        
        // Reload widget timeline
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "WeeklyPomodoroWidget")
        #endif
    }
    
    // MARK: - Save/Load Widget Data
    
    private func saveWidgetData(_ data: WeeklyWidgetData) {
        guard let defaults = sharedDefaults else { return }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        
        if let encoded = try? encoder.encode(data) {
            defaults.set(encoded, forKey: widgetDataKey)
        }
    }
    
    func loadWidgetData() -> WeeklyWidgetData? {
        guard let defaults = sharedDefaults else { return nil }
        
        guard let data = defaults.data(forKey: widgetDataKey),
              let widgetData = try? JSONDecoder().decode(WeeklyWidgetData.self, from: data) else {
            return nil
        }
        
        return widgetData
    }
    
    // MARK: - Format Time
    
    static func formatTime(_ minutes: Int) -> String {
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
    
    static func formatTimeGoal(_ minutes: Int) -> String {
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

