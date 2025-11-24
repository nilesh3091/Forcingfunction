//
//  CalendarView.swift
//  ForcingFunction
//
//  Calendar view showing pomodoro sessions by date
//

import SwiftUI

struct CalendarView: View {
    @ObservedObject var viewModel: TimerViewModel
    @State private var currentMonth: Date = Date()
    @State private var selectedDate: Date? = nil
    
    private let dataStore = PomodoroDataStore.shared
    private let calendar = Calendar.current
    
    // Get all work sessions (no breaks)
    private var workSessions: [PomodoroSession] {
        dataStore.getAllSessions().filter { $0.sessionType == .work }
    }
    
    // Get sessions for selected date (or all if none selected)
    private var filteredSessions: [PomodoroSession] {
        guard let selectedDate = selectedDate else {
            return workSessions
        }
        
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: selectedDate) ?? selectedDate
        
        return workSessions.filter { session in
            session.startTime >= startOfDay && session.startTime <= endOfDay
        }
    }
    
    // Get dates that have sessions (for calendar indicators)
    private var datesWithSessions: Set<Date> {
        Set(workSessions.map { calendar.startOfDay(for: $0.startTime) })
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Calendar Grid
                    CalendarGridView(
                        currentMonth: $currentMonth,
                        selectedDate: $selectedDate,
                        datesWithSessions: datesWithSessions,
                        accentColor: viewModel.accentColor
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                        .padding(.vertical, 12)
                    
                    // Sessions List
                    if filteredSessions.isEmpty {
                        // Empty state
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 48))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text(selectedDate == nil ? "No sessions yet" : "No sessions on this day")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.7))
                            
                            if selectedDate != nil {
                                Button("Show All Sessions") {
                                    selectedDate = nil
                                }
                                .font(.subheadline)
                                .foregroundColor(viewModel.accentColor)
                                .padding(.top, 8)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 60)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                // Header
                                HStack {
                                    if let selectedDate = selectedDate {
                                        Text(formatSelectedDateHeader(selectedDate))
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Button(action: {
                                            self.selectedDate = nil
                                        }) {
                                            Text("Show All")
                                                .font(.subheadline)
                                                .foregroundColor(viewModel.accentColor)
                                        }
                                    } else {
                                        Text("All Sessions")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(filteredSessions.count) session\(filteredSessions.count == 1 ? "" : "s")")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                                
                                // Session Cards
                                ForEach(filteredSessions) { session in
                                    PomodoroSessionCard(
                                        session: session,
                                        accentColor: viewModel.accentColor
                                    )
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func formatSelectedDateHeader(_ date: Date) -> String {
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Calendar Grid View

struct CalendarGridView: View {
    @Binding var currentMonth: Date
    @Binding var selectedDate: Date?
    let datesWithSessions: Set<Date>
    let accentColor: Color
    
    private let calendar = Calendar.current
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
    
    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let firstDayOfMonth = monthInterval.start as Date?,
              let lastDayOfMonth = calendar.date(byAdding: .day, value: -1, to: monthInterval.end) else {
            return []
        }
        
        // Get first weekday of month (0 = Sunday, 1 = Monday, etc.)
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) - 1
        
        // Get number of days in month
        let daysCount = calendar.dateComponents([.day], from: firstDayOfMonth, to: lastDayOfMonth).day ?? 0
        
        var days: [Date?] = []
        
        // Add empty cells for days before month starts
        for _ in 0..<firstWeekday {
            days.append(nil)
        }
        
        // Add days of the month
        for dayOffset in 0...daysCount {
            if let day = calendar.date(byAdding: .day, value: dayOffset, to: firstDayOfMonth) {
                days.append(day)
            }
        }
        
        return days
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Month Navigation
            HStack {
                Button(action: {
                    withAnimation {
                        if let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
                            currentMonth = previousMonth
                        }
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text(monthYearString)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
                            currentMonth = nextMonth
                        }
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            
            // Weekday Headers
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar Days Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { index, date in
                    if let date = date {
                        CalendarDayView(
                            date: date,
                            isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false,
                            hasSessions: datesWithSessions.contains(calendar.startOfDay(for: date)),
                            isToday: calendar.isDateInToday(date),
                            accentColor: accentColor
                        ) {
                            withAnimation {
                                if selectedDate != nil && calendar.isDate(selectedDate!, inSameDayAs: date) {
                                    selectedDate = nil
                                } else {
                                    selectedDate = date
                                }
                            }
                        }
                    } else {
                        // Empty cell
                        Color.clear
                            .frame(height: 32)
                    }
                }
            }
        }
    }
}

// MARK: - Calendar Day View

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let hasSessions: Bool
    let isToday: Bool
    let accentColor: Color
    let action: () -> Void
    
    private let calendar = Calendar.current
    
    private var dayNumber: Int {
        calendar.component(.day, from: date)
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(dayNumber)")
                    .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                    .foregroundColor(
                        isSelected ? .white :
                        isToday ? accentColor :
                        .white.opacity(0.9)
                    )
                
                if hasSessions {
                    Circle()
                        .fill(isSelected ? Color.white : accentColor)
                        .frame(width: 3, height: 3)
                } else {
                    Spacer()
                        .frame(height: 3)
                }
            }
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(isSelected ? accentColor : Color.clear)
            )
            .overlay(
                Circle()
                    .stroke(isToday && !isSelected ? accentColor : Color.clear, lineWidth: 1.5)
            )
        }
    }
}

// MARK: - Pomodoro Session Card

struct PomodoroSessionCard: View {
    let session: PomodoroSession
    let accentColor: Color
    
    private let calendar = Calendar.current
    private let categoryManager = CategoryManager.shared
    
    private var category: Category? {
        guard let categoryId = session.categoryId else { return nil }
        return categoryManager.getCategory(byId: categoryId)
    }
    
    private var isCategoryArchived: Bool {
        guard let category = category else { return false }
        return category.isArchived
    }
    
    private var durationString: String {
        if let activeDuration = session.activeDurationMinutes {
            let minutes = Int(activeDuration)
            return "\(minutes) min"
        } else if let actualDuration = session.actualDurationMinutes {
            let minutes = Int(actualDuration)
            return "\(minutes) min"
        } else {
            return "\(Int(session.plannedDurationMinutes)) min"
        }
    }
    
    private var timeRangeString: String {
        let startFormatter = DateFormatter()
        startFormatter.timeStyle = .short
        
        if let endTime = session.endTime {
            let endFormatter = DateFormatter()
            endFormatter.timeStyle = .short
            return "\(startFormatter.string(from: session.startTime)) - \(endFormatter.string(from: endTime))"
        } else {
            return startFormatter.string(from: session.startTime)
        }
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        if calendar.isDateInToday(session.startTime) {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: session.startTime)
        } else if calendar.isDateInYesterday(session.startTime) {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: session.startTime)
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: session.startTime)
        }
    }
    
    private var statusColor: Color {
        switch session.status {
        case .completed:
            return accentColor
        case .cancelled:
            return .gray
        case .paused, .running:
            return .orange
        }
    }
    
    private var statusText: String {
        switch session.status {
        case .completed:
            return "Completed"
        case .cancelled:
            return "Cancelled"
        case .paused:
            return "Paused"
        case .running:
            return "Running"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Session Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "timer")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(statusColor)
            }
            
            // Session Details
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Work")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    // Category badge
                    if let category = category {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(isCategoryArchived ? category.color.color.opacity(0.4) : category.color.color)
                                .frame(width: 8, height: 8)
                            Text(category.name)
                                .font(.caption)
                                .foregroundColor(isCategoryArchived ? .white.opacity(0.5) : .white.opacity(0.8))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isCategoryArchived ? Color.gray.opacity(0.1) : category.color.color.opacity(0.2))
                        )
                    }
                    
                    Spacer()
                    
                    Text(statusText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.2))
                        .cornerRadius(8)
                }
                
                HStack(spacing: 12) {
                    Label(durationString, systemImage: "clock.fill")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(dateString)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Text(timeRangeString)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

#Preview {
    CalendarView(viewModel: TimerViewModel())
}

