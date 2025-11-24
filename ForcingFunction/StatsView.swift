//
//  StatsView.swift
//  ForcingFunction
//
//  Statistics view with weekly goal tracking
//

import SwiftUI

struct StatsView: View {
    @ObservedObject var viewModel: TimerViewModel
    @AppStorage("weeklyGoalMinutes") private var weeklyGoalMinutes: Int = 1200 // Default: 20 hours
    @State private var showingGoalPicker = false
    
    // Calculate current week's completed focus time in minutes (excluding pauses)
    private var currentWeekCompletedMinutes: Int {
        let dataStore = PomodoroDataStore.shared
        let calendar = Calendar.current
        let now = Date()
        
        // Get start of current week (Monday at 00:00:00)
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        guard let startOfWeek = calendar.date(from: components) else { return 0 }
        
        // Get end of week (Sunday at 23:59:59)
        guard let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) else { return 0 }
        let endOfWeekEndOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfWeek) ?? endOfWeek
        
        let weekSessions = dataStore.getSessions(from: startOfWeek, to: endOfWeekEndOfDay)
        let completedWorkSessions = weekSessions.filter { $0.sessionType == .work && $0.status == .completed }
        
        // Sum up active duration (excluding pauses) for all completed work sessions
        let totalMinutes = completedWorkSessions.compactMap { session -> Double? in
            return session.activeDurationMinutes
        }.reduce(0, +)
        
        return Int(totalMinutes)
    }
    
    private var goalProgress: Double {
        guard weeklyGoalMinutes > 0 else { return 0 }
        return min(1.0, Double(currentWeekCompletedMinutes) / Double(weeklyGoalMinutes))
    }
    
    // Format minutes as "XhYmin" (e.g., "2h30min")
    private func formatTimeGoal(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 && mins > 0 {
            return "\(hours)h\(mins)min"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)min"
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Weekly Goal Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Weekly Goal")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Button(action: {
                                    showingGoalPicker = true
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(viewModel.accentColor)
                                }
                            }
                            
                            // Progress display
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(formatTimeGoal(currentWeekCompletedMinutes))
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .foregroundColor(viewModel.accentColor)
                                    
                                    Text("/ \(formatTimeGoal(weeklyGoalMinutes))")
                                        .font(.system(size: 32, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    Spacer()
                                }
                                
                                Text("focus time this week")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.6))
                                
                                // Progress bar
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        // Background
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 12)
                                        
                                        // Progress
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        viewModel.accentColor,
                                                        viewModel.accentColor.opacity(0.8)
                                                    ]),
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: geometry.size.width * goalProgress, height: 12)
                                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: goalProgress)
                                    }
                                }
                                .frame(height: 12)
                                
                                // Goal status text
                                if currentWeekCompletedMinutes >= weeklyGoalMinutes {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("Goal achieved! 🎉")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.green)
                                    }
                                    .padding(.top, 4)
                                } else {
                                    let remaining = weeklyGoalMinutes - currentWeekCompletedMinutes
                                    Text("\(formatTimeGoal(remaining)) remaining")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.6))
                                        .padding(.top, 4)
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.1))
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Statistics Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Statistics")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                            
                            // Total Focus Time
                            StatCard(
                                title: "Total Focus Time",
                                value: AngleUtilities.formatFocusTime(viewModel.totalFocusMinutes),
                                icon: "clock.fill",
                                color: viewModel.accentColor
                            )
                            
                            // Completed Pomodoros
                            StatCard(
                                title: "Completed Pomodoros",
                                value: "\(viewModel.completedPomodoros)",
                                icon: "checkmark.circle.fill",
                                color: viewModel.accentColor
                            )
                            
                            // Category Breakdown
                            CategoryBreakdownView(accentColor: viewModel.accentColor)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingGoalPicker) {
            GoalPickerView(weeklyGoalMinutes: $weeklyGoalMinutes, accentColor: viewModel.accentColor)
        }
        .onAppear {
            // Update widget data when Stats view appears
            WidgetDataManager.shared.updateWidgetData()
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .padding(.horizontal, 20)
    }
}

struct GoalPickerView: View {
    @Binding var weeklyGoalMinutes: Int
    let accentColor: Color
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedHours: Int = 0
    @State private var selectedMinutes: Int = 0
    
    // Format minutes as "XhYmin"
    private func formatTimeGoal(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 && mins > 0 {
            return "\(hours)h\(mins)min"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)min"
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("Set Weekly Goal")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.top, 20)
                    
                    Text("How much focus time do you want to complete this week?")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    // Current goal display
                    Text(formatTimeGoal(weeklyGoalMinutes))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(accentColor)
                        .padding(.vertical, 8)
                    
                    // Hours and Minutes pickers
                    HStack(spacing: 40) {
                        // Hours picker
                        VStack(spacing: 12) {
                            Text("Hours")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.7))
                            
                            Picker("Hours", selection: $selectedHours) {
                                ForEach(0...50, id: \.self) { hour in
                                    Text("\(hour)").tag(hour)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 100)
                            .clipped()
                        }
                        
                        // Minutes picker
                        VStack(spacing: 12) {
                            Text("Minutes")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.7))
                            
                            Picker("Minutes", selection: $selectedMinutes) {
                                ForEach([0, 15, 30, 45], id: \.self) { minute in
                                    Text("\(minute)").tag(minute)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 100)
                            .clipped()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Preview of total
                    VStack(spacing: 8) {
                        Text("Total:")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text(formatTimeGoal(selectedHours * 60 + selectedMinutes))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(accentColor)
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Save button
                    Button(action: {
                        weeklyGoalMinutes = selectedHours * 60 + selectedMinutes
                        // Update widget data when goal changes
                        WidgetDataManager.shared.updateWidgetData()
                        dismiss()
                    }) {
                        Text("Set Goal")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(accentColor)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Weekly Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(accentColor)
                }
            }
            .onAppear {
                // Initialize pickers with current goal
                selectedHours = weeklyGoalMinutes / 60
                selectedMinutes = weeklyGoalMinutes % 60
                // Round minutes to nearest 15
                selectedMinutes = [0, 15, 30, 45].min(by: { abs($0 - selectedMinutes) < abs($1 - selectedMinutes) }) ?? 0
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Category Breakdown View

struct CategoryBreakdownView: View {
    let accentColor: Color
    
    private let categoryManager = CategoryManager.shared
    private let dataStore = PomodoroDataStore.shared
    
    private var categoryStats: [(category: Category?, minutes: Int, sessionCount: Int, isArchived: Bool)] {
        let allSessions = dataStore.getCompletedWorkSessions()
        var categoryMinutes: [UUID: (minutes: Double, count: Int)] = [:]
        var noCategoryMinutes: Double = 0
        var noCategoryCount: Int = 0
        
        // Calculate stats per category
        for session in allSessions {
            if let categoryId = session.categoryId {
                let duration = session.activeDurationMinutes ?? session.actualDurationMinutes ?? 0
                if let existing = categoryMinutes[categoryId] {
                    categoryMinutes[categoryId] = (existing.minutes + duration, existing.count + 1)
                } else {
                    categoryMinutes[categoryId] = (duration, 1)
                }
            } else {
                let duration = session.activeDurationMinutes ?? session.actualDurationMinutes ?? 0
                noCategoryMinutes += duration
                noCategoryCount += 1
            }
        }
        
        // Build result array
        var results: [(category: Category?, minutes: Int, sessionCount: Int, isArchived: Bool)] = []
        
        // Add categories with sessions
        for (categoryId, stats) in categoryMinutes {
            if let category = categoryManager.getCategory(byId: categoryId) {
                results.append((
                    category: category,
                    minutes: Int(stats.minutes),
                    sessionCount: stats.count,
                    isArchived: category.isArchived
                ))
            }
        }
        
        // Add "No Category" if there are sessions without categories
        if noCategoryCount > 0 {
            results.append((
                category: nil,
                minutes: Int(noCategoryMinutes),
                sessionCount: noCategoryCount,
                isArchived: false
            ))
        }
        
        // Sort: active categories first (alphabetically), then archived (alphabetically), then "No Category" last
        return results.sorted { first, second in
            if first.isArchived != second.isArchived {
                return !first.isArchived // Active first
            }
            if first.category == nil {
                return false // "No Category" always last
            }
            if second.category == nil {
                return true
            }
            // Alphabetical by name
            return (first.category?.name ?? "").localizedCaseInsensitiveCompare(second.category?.name ?? "") == .orderedAscending
        }
    }
    
    var body: some View {
        let stats = categoryStats
        
        if !stats.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Category Breakdown")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                
                ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                    CategoryStatRow(
                        category: stat.category,
                        minutes: stat.minutes,
                        sessionCount: stat.sessionCount,
                        isArchived: stat.isArchived,
                        accentColor: accentColor
                    )
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 8)
        }
    }
}

struct CategoryStatRow: View {
    let category: Category?
    let minutes: Int
    let sessionCount: Int
    let isArchived: Bool
    let accentColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // Color indicator
            if let category = category {
                Circle()
                    .fill(isArchived ? category.color.color.opacity(0.4) : category.color.color)
                    .frame(width: 24, height: 24)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 24, height: 24)
            }
            
            // Category name and stats
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(category?.name ?? "No Category")
                        .font(.headline)
                        .foregroundColor(isArchived ? .white.opacity(0.6) : .white)
                    
                    if isArchived {
                        Text("(Archived)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                
                HStack(spacing: 8) {
                    Text(AngleUtilities.formatFocusTime(minutes))
                        .font(.subheadline)
                        .foregroundColor(isArchived ? accentColor.opacity(0.6) : accentColor)
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text("\(sessionCount) session\(sessionCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(isArchived ? 0.4 : 0.6))
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(isArchived ? 0.05 : 0.1))
        )
    }
}

#Preview {
    StatsView(viewModel: TimerViewModel())
}

