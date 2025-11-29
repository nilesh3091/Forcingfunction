//
//  StatsView.swift
//  ForcingFunction
//
//  Statistics view with weekly goal tracking
//

import SwiftUI

// Helper to manage category-specific weekly goals
extension UserDefaults {
    func getCategoryWeeklyGoal(categoryId: UUID) -> Int? {
        let key = "weeklyGoal_\(categoryId.uuidString)"
        let value = integer(forKey: key)
        return value > 0 ? value : nil
    }
    
    func setCategoryWeeklyGoal(categoryId: UUID, minutes: Int) {
        let key = "weeklyGoal_\(categoryId.uuidString)"
        set(minutes, forKey: key)
    }
    
    func removeCategoryWeeklyGoal(categoryId: UUID) {
        let key = "weeklyGoal_\(categoryId.uuidString)"
        removeObject(forKey: key)
    }
}

// Make UUID Identifiable for sheet binding
extension UUID: Identifiable {
    public var id: UUID { self }
}

struct StatsView: View {
    @ObservedObject var viewModel: TimerViewModel
    @AppStorage("weeklyGoalMinutes") private var weeklyGoalMinutes: Int = 1200 // Default: 20 hours
    @State private var showingGoalPicker = false
    @State private var showingCategoryGoalPicker: UUID? = nil
    @State private var showingCreateCategory = false
    @State private var refreshTrigger: Int = 0 // Force view refresh when goals change
    @State private var isCategoryGoalsExpanded = false // Start collapsed
    @State private var isArchivedGoalsExpanded = false // Start collapsed
    
    private let categoryManager = CategoryManager.shared
    
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
    
    // Calculate current week's completed focus time for a specific category
    private func currentWeekCompletedMinutes(for categoryId: UUID) -> Int {
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
        let completedWorkSessions = weekSessions.filter { 
            $0.sessionType == .work && 
            $0.status == .completed && 
            $0.categoryId == categoryId
        }
        
        // Sum up active duration (excluding pauses) for completed work sessions in this category
        let totalMinutes = completedWorkSessions.compactMap { session -> Double? in
            return session.activeDurationMinutes
        }.reduce(0, +)
        
        return Int(totalMinutes)
    }
    
    // Get categories that have weekly goals set
    private var categoriesWithGoals: [(category: Category, goalMinutes: Int)] {
        let _ = refreshTrigger // Force SwiftUI to recalculate when refreshTrigger changes
        let categoryManager = CategoryManager.shared
        let activeCategories = categoryManager.getActiveCategories()
        let defaults = UserDefaults.standard
        
        return activeCategories.compactMap { category -> (Category, Int)? in
            if let goalMinutes = defaults.getCategoryWeeklyGoal(categoryId: category.id) {
                return (category, goalMinutes)
            }
            return nil
        }
    }
    
    // Get active categories without goals
    private var categoriesWithoutGoals: [Category] {
        let _ = refreshTrigger // Force SwiftUI to recalculate when refreshTrigger changes
        let categoryManager = CategoryManager.shared
        let activeCategories = categoryManager.getActiveCategories()
        let defaults = UserDefaults.standard
        
        return activeCategories.filter { category in
            defaults.getCategoryWeeklyGoal(categoryId: category.id) == nil
        }
    }
    
    // Get all archived categories
    private var archivedCategories: [Category] {
        let _ = refreshTrigger // Force SwiftUI to recalculate when refreshTrigger changes
        let categoryManager = CategoryManager.shared
        return categoryManager.getArchivedCategories()
    }
    
    // Get archived categories with goals
    private var archivedCategoriesWithGoals: [(category: Category, goalMinutes: Int)] {
        let _ = refreshTrigger // Force SwiftUI to recalculate when refreshTrigger changes
        let defaults = UserDefaults.standard
        
        return archivedCategories.compactMap { category -> (Category, Int)? in
            if let goalMinutes = defaults.getCategoryWeeklyGoal(categoryId: category.id) {
                return (category, goalMinutes)
            }
            return nil
        }
    }
    
    // Get archived categories without goals
    private var archivedCategoriesWithoutGoals: [Category] {
        let _ = refreshTrigger // Force SwiftUI to recalculate when refreshTrigger changes
        let defaults = UserDefaults.standard
        
        return archivedCategories.filter { category in
            defaults.getCategoryWeeklyGoal(categoryId: category.id) == nil
        }
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
                        // Weekly Total Goal Card (Vertical Stack Layout)
                        VStack(alignment: .leading, spacing: 14) {
                            // Title and Edit Button Row
                            HStack {
                                Text("Weekly Total Goal")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Button(action: {
                                    showingGoalPicker = true
                                }) {
                                    Image(systemName: "pencil")
                                        .font(.subheadline)
                                        .foregroundColor(viewModel.accentColor)
                                }
                            }
                            
                            // Time Display Row (Full Width)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(formatTimeGoal(currentWeekCompletedMinutes))
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundColor(viewModel.accentColor)
                                    
                                    Text("/ \(formatTimeGoal(weeklyGoalMinutes))")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                Text("focus time this week")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            // Progress Bar Row (Full Width)
                            VStack(alignment: .leading, spacing: 6) {
                                // Progress bar
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        // Background
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 10)
                                        
                                        // Progress
                                        RoundedRectangle(cornerRadius: 6)
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
                                            .frame(width: geometry.size.width * goalProgress, height: 10)
                                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: goalProgress)
                                    }
                                }
                                .frame(height: 10)
                                
                                // Goal status text
                                HStack {
                                    if currentWeekCompletedMinutes >= weeklyGoalMinutes {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                            Text("Goal achieved! 🎉")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.green)
                                        }
                                    } else {
                                        let remaining = weeklyGoalMinutes - currentWeekCompletedMinutes
                                        Text("\(formatTimeGoal(remaining)) remaining")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.1))
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Category Goals Section (Collapsible)
                        CollapsibleCategoryGoalsSection(
                            title: "Category Goals",
                            isExpanded: $isCategoryGoalsExpanded,
                            categoriesWithGoals: categoriesWithGoals,
                            categoriesWithoutGoals: categoriesWithoutGoals,
                            accentColor: viewModel.accentColor,
                            currentWeekCompletedMinutes: { categoryId in
                                currentWeekCompletedMinutes(for: categoryId)
                            },
                            onSetGoal: { categoryId in
                                showingCategoryGoalPicker = categoryId
                            },
                            onAddCategory: {
                                showingCreateCategory = true
                            }
                        )
                        
                        // Archived Category Goals Section (Collapsible)
                        if !archivedCategories.isEmpty {
                            CollapsibleCategoryGoalsSection(
                                title: "Archived Category Goals",
                                isExpanded: $isArchivedGoalsExpanded,
                                categoriesWithGoals: archivedCategoriesWithGoals,
                                categoriesWithoutGoals: archivedCategoriesWithoutGoals,
                                accentColor: viewModel.accentColor,
                                currentWeekCompletedMinutes: { categoryId in
                                    currentWeekCompletedMinutes(for: categoryId)
                                },
                                onSetGoal: { categoryId in
                                    showingCategoryGoalPicker = categoryId
                                },
                                onAddCategory: nil,
                                isArchived: true
                            )
                        }
                        
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
                            CategoryBreakdownView(
                                accentColor: viewModel.accentColor,
                                onSetGoal: { categoryId in
                                    showingCategoryGoalPicker = categoryId
                                }
                            )
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
        .sheet(item: $showingCategoryGoalPicker) { categoryId in
            CategoryGoalPickerView(
                categoryId: categoryId,
                categoryName: CategoryManager.shared.getCategory(byId: categoryId)?.name ?? "Category",
                accentColor: viewModel.accentColor,
                onGoalChanged: {
                    refreshTrigger += 1
                }
            )
        }
        .sheet(isPresented: $showingCreateCategory) {
            CreateEditCategoryView(
                accentColor: viewModel.accentColor,
                onSave: { name, color in
                    _ = categoryManager.createCategory(name: name, color: color)
                    refreshTrigger += 1
                }
            )
            .onDisappear {
                // Refresh when sheet dismisses to ensure we catch any changes
                refreshTrigger += 1
            }
        }
        .onAppear {
            // Update widget data when Stats view appears
            WidgetDataManager.shared.updateWidgetData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .categoriesDidChange)) { _ in
            refreshTrigger += 1
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
    let onSetGoal: (UUID) -> Void
    
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
                        accentColor: accentColor,
                        onSetGoal: stat.category != nil && !stat.isArchived ? {
                            if let categoryId = stat.category?.id {
                                onSetGoal(categoryId)
                            }
                        } : nil
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
    let onSetGoal: (() -> Void)?
    
    private var hasGoal: Bool {
        guard let category = category, !isArchived else { return false }
        return UserDefaults.standard.getCategoryWeeklyGoal(categoryId: category.id) != nil
    }
    
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
                    
                    if hasGoal {
                        Image(systemName: "target")
                            .font(.caption)
                            .foregroundColor(accentColor.opacity(0.7))
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
            
            // Set/Edit goal button (only for active categories)
            if let onSetGoal = onSetGoal {
                Button(action: onSetGoal) {
                    Image(systemName: hasGoal ? "pencil" : "plus.circle")
                        .foregroundColor(accentColor)
                        .font(.subheadline)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(isArchived ? 0.05 : 0.1))
        )
    }
}

// MARK: - Collapsible Category Goals Section

struct CollapsibleCategoryGoalsSection: View {
    let title: String
    @Binding var isExpanded: Bool
    let categoriesWithGoals: [(category: Category, goalMinutes: Int)]
    let categoriesWithoutGoals: [Category]
    let accentColor: Color
    let currentWeekCompletedMinutes: (UUID) -> Int
    let onSetGoal: (UUID) -> Void
    let onAddCategory: (() -> Void)?
    var isArchived: Bool = false
    
    private let categoryManager = CategoryManager.shared
    
    private var canAddMoreCategories: Bool {
        !isArchived && (categoriesWithGoals.count + categoriesWithoutGoals.count) < categoryManager.getMaxActiveCategories()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header (Always visible)
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .animation(.none, value: isExpanded)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // Categories with goals
                    ForEach(categoriesWithGoals, id: \.category.id) { categoryGoal in
                        CompactCategoryGoalRow(
                            category: categoryGoal.category,
                            goalMinutes: categoryGoal.goalMinutes,
                            completedMinutes: currentWeekCompletedMinutes(categoryGoal.category.id),
                            accentColor: accentColor,
                            isArchived: isArchived,
                            onEdit: {
                                onSetGoal(categoryGoal.category.id)
                            }
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    // Categories without goals
                    ForEach(categoriesWithoutGoals, id: \.id) { category in
                        CompactCategoryNoGoalRow(
                            category: category,
                            accentColor: accentColor,
                            isArchived: isArchived,
                            onSetGoal: {
                                onSetGoal(category.id)
                            }
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    // Add category button after list (when there's room and not archived)
                    if let onAddCategory = onAddCategory, !isArchived {
                        if canAddMoreCategories && (!categoriesWithGoals.isEmpty || !categoriesWithoutGoals.isEmpty) {
                            Button(action: onAddCategory) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(accentColor)
                                    Text("Add Category")
                                        .foregroundColor(accentColor)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        } else if !canAddMoreCategories && (!categoriesWithGoals.isEmpty || !categoriesWithoutGoals.isEmpty) {
                            Text("Archive a category to add more")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                        }
                    }
                    
                    // Show message if no categories exist
                    if categoriesWithGoals.isEmpty && categoriesWithoutGoals.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tag")
                                .font(.system(size: 32))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text("No categories yet")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                            
                            if let onAddCategory = onAddCategory, canAddMoreCategories {
                                Button(action: onAddCategory) {
                                    Text("Create Your First Category")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(accentColor)
                                        .cornerRadius(8)
                                }
                                .padding(.top, 8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 40)
                    }
                }
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Category No Goal Row

struct CategoryNoGoalRow: View {
    let category: Category
    let accentColor: Color
    let onSetGoal: () -> Void
    
    var body: some View {
        Button(action: onSetGoal) {
            HStack(spacing: 12) {
                // Category color indicator
                Circle()
                    .fill(category.color.color)
                    .frame(width: 20, height: 20)
                
                // Category name
                Text(category.name)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                // Add goal button
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle")
                        .font(.subheadline)
                    Text("Set Goal")
                        .font(.subheadline)
                }
                .foregroundColor(accentColor)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.1))
            )
        }
    }
}

// MARK: - Category Goal Card

struct CategoryGoalCard: View {
    let category: Category
    let goalMinutes: Int
    let completedMinutes: Int
    let accentColor: Color
    let onEdit: () -> Void
    
    private var goalProgress: Double {
        guard goalMinutes > 0 else { return 0 }
        return min(1.0, Double(completedMinutes) / Double(goalMinutes))
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Category color indicator
                Circle()
                    .fill(category.color.color)
                    .frame(width: 16, height: 16)
                
                Text(category.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(accentColor)
                        .font(.subheadline)
                }
            }
            
            // Progress display
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(formatTimeGoal(completedMinutes))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(category.color.color)
                    
                    Text("/ \(formatTimeGoal(goalMinutes))")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        category.color.color,
                                        category.color.color.opacity(0.8)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * goalProgress, height: 8)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: goalProgress)
                    }
                }
                .frame(height: 8)
                
                // Goal status text
                if completedMinutes >= goalMinutes {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Goal achieved! 🎉")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    .padding(.top, 2)
                } else {
                    let remaining = goalMinutes - completedMinutes
                    Text("\(formatTimeGoal(remaining)) remaining")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 2)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Compact Category Goal Row

struct CompactCategoryGoalRow: View {
    let category: Category
    let goalMinutes: Int
    let completedMinutes: Int
    let accentColor: Color
    let isArchived: Bool
    let onEdit: () -> Void
    
    private var goalProgress: Double {
        guard goalMinutes > 0 else { return 0 }
        return min(1.0, Double(completedMinutes) / Double(goalMinutes))
    }
    
    // Format minutes as "XhYm" (compact)
    private func formatTimeGoal(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 && mins > 0 {
            return "\(hours)h\(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Category color indicator
                Circle()
                    .fill(isArchived ? category.color.color.opacity(0.4) : category.color.color)
                    .frame(width: 12, height: 12)
                
                // Category name
                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isArchived ? .white.opacity(0.6) : .white)
                
                Spacer()
                
                // Progress: XhYm / Zh
                HStack(spacing: 4) {
                    Text(formatTimeGoal(completedMinutes))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isArchived ? category.color.color.opacity(0.6) : category.color.color)
                    
                    Text("/ \(formatTimeGoal(goalMinutes))")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // Edit button
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(accentColor)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    isArchived ? category.color.color.opacity(0.4) : category.color.color,
                                    isArchived ? category.color.color.opacity(0.3) : category.color.color.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * goalProgress, height: 6)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: goalProgress)
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(isArchived ? 0.05 : 0.1))
        )
    }
}

// MARK: - Compact Category No Goal Row

struct CompactCategoryNoGoalRow: View {
    let category: Category
    let accentColor: Color
    let isArchived: Bool
    let onSetGoal: () -> Void
    
    var body: some View {
        Button(action: onSetGoal) {
            HStack(spacing: 8) {
                // Category color indicator
                Circle()
                    .fill(isArchived ? category.color.color.opacity(0.4) : category.color.color)
                    .frame(width: 12, height: 12)
                
                // Category name
                Text(category.name)
                    .font(.subheadline)
                    .foregroundColor(isArchived ? .white.opacity(0.5) : .white.opacity(0.7))
                
                Spacer()
                
                // Set Goal button
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle")
                        .font(.caption)
                    Text("Set Goal")
                        .font(.caption)
                }
                .foregroundColor(accentColor)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(isArchived ? 0.05 : 0.1))
            )
        }
    }
}

// MARK: - Category Goal Picker View

struct CategoryGoalPickerView: View {
    let categoryId: UUID
    let categoryName: String
    let accentColor: Color
    let onGoalChanged: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedHours: Int = 0
    @State private var selectedMinutes: Int = 0
    
    private var currentGoalMinutes: Int {
        UserDefaults.standard.getCategoryWeeklyGoal(categoryId: categoryId) ?? 0
    }
    
    private func saveGoal(_ minutes: Int) {
        if minutes > 0 {
            UserDefaults.standard.setCategoryWeeklyGoal(categoryId: categoryId, minutes: minutes)
        } else {
            UserDefaults.standard.removeCategoryWeeklyGoal(categoryId: categoryId)
        }
    }
    
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
                    
                    HStack(spacing: 8) {
                        Text("for")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        Text(categoryName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(accentColor)
                    }
                    
                    Text("How much focus time do you want to complete this week?")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    // Current goal display
                    Text(formatTimeGoal(currentGoalMinutes))
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
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        // Remove goal button (if goal exists)
                        if currentGoalMinutes > 0 {
                            Button(action: {
                                saveGoal(0)
                                WidgetDataManager.shared.updateWidgetData()
                                onGoalChanged()
                                dismiss()
                            }) {
                                Text("Remove Goal")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.red.opacity(0.2))
                                    .cornerRadius(12)
                            }
                        }
                        
                        // Save button
                        Button(action: {
                            saveGoal(selectedHours * 60 + selectedMinutes)
                            WidgetDataManager.shared.updateWidgetData()
                            onGoalChanged()
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
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Category Goal")
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
                let currentGoal = currentGoalMinutes
                selectedHours = currentGoal / 60
                selectedMinutes = currentGoal % 60
                // Round minutes to nearest 15
                selectedMinutes = [0, 15, 30, 45].min(by: { abs($0 - selectedMinutes) < abs($1 - selectedMinutes) }) ?? 0
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    StatsView(viewModel: TimerViewModel())
}

