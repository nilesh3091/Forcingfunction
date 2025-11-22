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
    let weeklyGoalMinutes: Int
    let dailyTotals: [Int] // [Mon, Tue, Wed, Thu, Fri, Sat, Sun]
    let accentColor: String // "Red", "Blue", or "Green"
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
    
    /// Calculate weekly totals and store in shared UserDefaults
    func updateWidgetData() {
        let dataStore = PomodoroDataStore.shared
        let calendar = Calendar.current
        let now = Date()
        
        // Get start of current week (Monday at 00:00:00)
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        guard let startOfWeek = calendar.date(from: components) else { return }
        
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
        #endif
        
        for session in completedWorkSessions {
            guard let activeMinutes = session.activeDurationMinutes else { continue }
            let sessionDate = session.startTime
            
            // Get day of week (0 = Sunday, 1 = Monday, ..., 6 = Saturday)
            let weekday = calendar.component(.weekday, from: sessionDate)
            // Convert to our array index (0 = Monday, 6 = Sunday)
            let index = (weekday == 1) ? 6 : weekday - 2
            
            if index >= 0 && index < 7 {
                dailyTotals[index] += Int(activeMinutes)
            }
        }
        
        // Sync settings from standard UserDefaults to shared UserDefaults
        // (since @AppStorage uses standard UserDefaults by default)
        if let sharedDefaults = sharedDefaults {
            // Sync themeColor
            let standardThemeColor = UserDefaults.standard.string(forKey: "themeColor")
            if let themeColor = standardThemeColor {
                sharedDefaults.set(themeColor, forKey: "themeColor")
            }
            
            // Sync weeklyGoalMinutes
            let standardWeeklyGoal = UserDefaults.standard.integer(forKey: "weeklyGoalMinutes")
            if standardWeeklyGoal > 0 {
                sharedDefaults.set(standardWeeklyGoal, forKey: "weeklyGoalMinutes")
            }
        }
        
        // Get weekly goal from shared UserDefaults
        let weeklyGoalMinutes = sharedDefaults?.integer(forKey: "weeklyGoalMinutes") ?? 0
        let defaultGoal = weeklyGoalMinutes > 0 ? weeklyGoalMinutes : 1200 // Default 20 hours
        
        // Get accent color from shared UserDefaults (now synced from standard)
        let themeColorString = sharedDefaults?.string(forKey: "themeColor") ?? ThemeColor.red.rawValue
        
        // Create widget data
        let widgetData = WeeklyWidgetData(
            currentWeekTotalMinutes: currentWeekTotalMinutes,
            weeklyGoalMinutes: defaultGoal,
            dailyTotals: dailyTotals,
            accentColor: themeColorString,
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

