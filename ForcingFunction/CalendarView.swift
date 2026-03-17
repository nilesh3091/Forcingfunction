//
//  CalendarView.swift
//  ForcingFunction
//
//  Calendar view showing pomodoro sessions by date
//

import SwiftUI

// MARK: - History Range

private enum HistoryRange: String, CaseIterable, Identifiable {
    case today
    case week
    case month
    case all
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .today: return "Today"
        case .week: return "This Week"
        case .month: return "This Month"
        case .all: return "All Time"
        }
    }
}

// MARK: - Session Day Group

private struct SessionDayGroup: Identifiable {
    let id: Date
    let date: Date
    let sessions: [PomodoroSession]
}

struct CalendarView: View {
    @ObservedObject var viewModel: TimerViewModel
    @State private var currentMonth: Date = Date()
    @State private var selectedSpecificDate: Date? = nil
    @State private var selectedRange: HistoryRange = .today
    @State private var isCalendarPresented: Bool = false
    @State private var refreshTrigger: UUID = UUID()
    
    private let dataStore = PomodoroDataStore.shared
    private let calendar = Calendar.current
    
    // Get all work sessions (no breaks)
    private var workSessions: [PomodoroSession] {
        dataStore.getAllSessions().filter { $0.sessionType == .work }
    }
    
    // Get dates that have sessions (for calendar indicators)
    private var datesWithSessions: Set<Date> {
        Set(workSessions.map { calendar.startOfDay(for: $0.startTime) })
    }
    
    // Dates shown in the horizontal date strip (recent history window)
    private var dateStripDays: [Date] {
        guard let minSessionDate = workSessions.map({ $0.startTime }).min() else {
            // No sessions yet – show just the last 7 days ending today
            let today = calendar.startOfDay(for: Date())
            let offsets = (-6)...0
            return offsets.compactMap { offset in
                calendar.date(byAdding: .day, value: offset, to: today)
            }
        }
        
        let today = calendar.startOfDay(for: Date())
        let earliestAllowed = calendar.date(byAdding: .day, value: -60, to: today) ?? today
        let stripStart = max(calendar.startOfDay(for: minSessionDate), earliestAllowed)
        let stripEnd = today
        
        var days: [Date] = []
        var current = stripStart
        while current <= stripEnd {
            days.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return days
    }
    
    // Date range for current selection (nil = all time)
    private var currentDateRange: (start: Date, end: Date)? {
        if let specific = selectedSpecificDate {
            let startOfDay = calendar.startOfDay(for: specific)
            let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: specific) ?? specific
            return (startOfDay, endOfDay)
        }
        
        switch selectedRange {
        case .today:
            let today = Date()
            let startOfDay = calendar.startOfDay(for: today)
            let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: today) ?? today
            return (startOfDay, endOfDay)
        case .week:
            if let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) {
                return (interval.start, interval.end)
            }
            return nil
        case .month:
            if let interval = calendar.dateInterval(of: .month, for: Date()) {
                return (interval.start, interval.end)
            }
            return nil
        case .all:
            return nil
        }
    }
    
    // Sessions filtered by current date range
    private var filteredSessions: [PomodoroSession] {
        guard let range = currentDateRange else {
            return workSessions.sorted { $0.startTime > $1.startTime }
        }
        
        return workSessions
            .filter { session in
                session.startTime >= range.start && session.startTime <= range.end
            }
            .sorted { $0.startTime > $1.startTime }
    }
    
    // Sessions grouped by day for list sections
    private var groupedSessions: [SessionDayGroup] {
        let groupedDictionary: [Date: [PomodoroSession]] = Dictionary(
            grouping: filteredSessions,
            by: { session in
                calendar.startOfDay(for: session.startTime)
            }
        )
        
        let groups: [SessionDayGroup] = groupedDictionary.map { entry in
            let date = entry.key
            let sessionsForDate = entry.value.sorted { lhs, rhs in
                lhs.startTime > rhs.startTime
            }
            return SessionDayGroup(id: date, date: date, sessions: sessionsForDate)
        }
        
        return groups.sorted { lhs, rhs in
            lhs.date > rhs.date
        }
    }
    
    private var summaryTitle: String {
        if let specific = selectedSpecificDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: specific)
        }
        
        switch selectedRange {
        case .today:
            return "Today"
        case .week:
            return "This Week"
        case .month:
            return "This Month"
        case .all:
            return "All Sessions"
        }
    }
    
    private var summarySubtitle: String {
        makeSummarySubtitle(for: filteredSessions)
    }
    
    // Selected date to highlight in the strip
    private var stripSelectedDate: Date? {
        if let specific = selectedSpecificDate {
            return calendar.startOfDay(for: specific)
        }
        if selectedRange == .today {
            return calendar.startOfDay(for: Date())
        }
        return nil
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    rangeHeader
                    Divider()
                        .background(Color.gray.opacity(0.3))
                        .padding(.horizontal, 20)
                    sessionsContent
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    browseButton
                }
            }
            .sheet(isPresented: $isCalendarPresented) {
                calendarSheet
            }
        }
    }
    
    private func totalFocusedMinutes(for sessions: [PomodoroSession]) -> Int {
        sessions.reduce(0) { partialResult, session in
            if let activeDuration = session.activeDurationMinutes {
                return partialResult + Int(activeDuration)
            } else if let actualDuration = session.actualDurationMinutes {
                return partialResult + Int(actualDuration)
            } else {
                return partialResult + Int(session.plannedDurationMinutes)
            }
        }
    }
    
    private func makeSummarySubtitle(for sessions: [PomodoroSession]) -> String {
        let sessionCount = sessions.count
        guard sessionCount > 0 else {
            return "No sessions yet"
        }
        
        let totalMinutes = totalFocusedMinutes(for: sessions)
        let dayStartDates = sessions.map { calendar.startOfDay(for: $0.startTime) }
        let distinctDays = Set<Date>(dayStartDates).count
        let streakDays = currentStreakDays()
        
        var parts: [String] = []
        parts.append("\(sessionCount) session\(sessionCount == 1 ? "" : "s")")
        parts.append("\(totalMinutes) min focused")
        
        if distinctDays > 1 {
            parts.append("\(distinctDays) days active")
        }
        
        if streakDays > 1 {
            parts.append("Streak: \(streakDays) days")
        }
        
        return parts.joined(separator: " • ")
    }

    private func currentStreakDays() -> Int {
        // Streak is based on any day with at least one session, counting back from today
        let allSessionDays: Set<Date> = Set(workSessions.map { calendar.startOfDay(for: $0.startTime) })
        guard !allSessionDays.isEmpty else { return 0 }
        
        var streak = 0
        var currentDay = calendar.startOfDay(for: Date())
        
        while allSessionDays.contains(currentDay) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else {
                break
            }
            currentDay = previousDay
        }
        
        return streak
    }

    // MARK: - Subviews
    
    private var rangeHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Range", selection: $selectedRange) {
                ForEach(HistoryRange.allCases) { range in
                    Text(range.title)
                        .tag(range)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedRange) { _ in
                // Clear specific day selection when changing base range
                selectedSpecificDate = nil
            }
            
            DateStripView(
                dates: dateStripDays,
                selectedDate: stripSelectedDate,
                datesWithSessions: datesWithSessions,
                calendar: calendar,
                accentColor: viewModel.accentColor
            ) { date in
                // Tapping a pill focuses on that specific day
                selectedSpecificDate = date
                selectedRange = .today
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(summaryTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(summarySubtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }
    
    @ViewBuilder
    private var sessionsContent: some View {
        if filteredSessions.isEmpty {
            emptySessionsView
        } else {
            sessionsListView
        }
    }
    
    private var emptySessionsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No sessions in this range yet")
                .font(.headline)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
    
    private var sessionsListView: some View {
        List {
            ForEach(groupedSessions) { group in
                sectionView(for: group)
            }
        }
        .id(refreshTrigger)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.black)
    }

    private func sectionView(for group: SessionDayGroup) -> some View {
        Section(
            header: DayHeaderView(
                date: group.date,
                sessions: group.sessions,
                calendar: calendar
            )
        ) {
            ForEach(group.sessions) { session in
                PomodoroSessionCard(
                    session: session,
                    accentColor: viewModel.accentColor
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(
                    EdgeInsets(
                        top: 0,
                        leading: 20,
                        bottom: 16,
                        trailing: 20
                    )
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if session.status == .cancelled {
                        Button(role: .destructive) {
                            deleteSession(session)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
    
    private var browseButton: some View {
        Button {
            isCalendarPresented = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                Text("Browse")
            }
            .font(.subheadline)
            .foregroundColor(viewModel.accentColor)
        }
    }
    
    private var calendarSheet: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    CalendarGridView(
                        currentMonth: $currentMonth,
                        selectedDate: Binding(
                            get: { selectedSpecificDate },
                            set: { newValue in
                                selectedSpecificDate = newValue
                            }
                        ),
                        datesWithSessions: datesWithSessions,
                        accentColor: viewModel.accentColor,
                        onDaySelected: { _ in
                            // When a day is selected, dismiss and use that specific date
                            isCalendarPresented = false
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                    
                    Spacer()
                }
            }
            .navigationTitle("Browse History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isCalendarPresented = false
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Clear") {
                        selectedSpecificDate = nil
                        isCalendarPresented = false
                    }
                    .foregroundColor(viewModel.accentColor)
                }
            }
        }
    }
    
    private func deleteSession(_ session: PomodoroSession) {
        dataStore.deleteSession(byId: session.id)
        // Trigger view refresh
        refreshTrigger = UUID()
    }
}

// MARK: - Calendar Grid View

struct CalendarGridView: View {
    @Binding var currentMonth: Date
    @Binding var selectedDate: Date?
    let datesWithSessions: Set<Date>
    let accentColor: Color
    let onDaySelected: ((Date) -> Void)?
    
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
                                if let currentSelected = selectedDate, calendar.isDate(currentSelected, inSameDayAs: date) {
                                    selectedDate = nil
                                } else {
                                    selectedDate = date
                                }
                            }
                            onDaySelected?(date)
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

// MARK: - Day Header View

private struct DayHeaderView: View {
    let date: Date
    let sessions: [PomodoroSession]
    let calendar: Calendar
    
    private var title: String {
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
    
    private var subtitle: String {
        let count = sessions.count
        let minutes = sessions.reduce(0) { total, session in
            if let activeDuration = session.activeDurationMinutes {
                return total + Int(activeDuration)
            } else if let actualDuration = session.actualDurationMinutes {
                return total + Int(actualDuration)
            } else {
                return total + Int(session.plannedDurationMinutes)
            }
        }
        
        return "\(count) session\(count == 1 ? "" : "s") • \(minutes) min"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.leading, 20)
        .padding(.bottom, 4)
        .background(Color.black)
    }
}

// MARK: - Date Strip

private struct DateStripView: View {
    let dates: [Date]
    let selectedDate: Date?
    let datesWithSessions: Set<Date>
    let calendar: Calendar
    let accentColor: Color
    let onSelect: (Date) -> Void
    
    private var weekdayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(dates, id: \.self) { date in
                    let dayStart = calendar.startOfDay(for: date)
                    let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: dayStart) } ?? false
                    let isToday = calendar.isDateInToday(dayStart)
                    let hasSessions = datesWithSessions.contains(dayStart)
                    let isFuture = dayStart > calendar.startOfDay(for: Date())
                    
                    DatePillView(
                        date: date,
                        weekdayFormatter: weekdayFormatter,
                        isSelected: isSelected,
                        isToday: isToday,
                        hasSessions: hasSessions,
                        isFuture: isFuture,
                        accentColor: accentColor
                    ) {
                        onSelect(dayStart)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct DatePillView: View {
    let date: Date
    let weekdayFormatter: DateFormatter
    let isSelected: Bool
    let isToday: Bool
    let hasSessions: Bool
    let isFuture: Bool
    let accentColor: Color
    let action: () -> Void
    
    private var dayNumber: String {
        let day = Calendar.current.component(.day, from: date)
        return String(day)
    }
    
    private var weekdayText: String {
        weekdayFormatter.string(from: date)
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(weekdayText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(labelColor)
                
                ZStack {
                    Circle()
                        .strokeBorder(borderColor, lineWidth: isSelected ? 2 : 1)
                        .background(
                            Circle()
                                .fill(backgroundColor)
                        )
                        .frame(width: 32, height: 32)
                    
                    Text(dayNumber)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(numberColor)
                }
            }
            .padding(.horizontal, 2)
        }
        .buttonStyle(.plain)
    }
    
    private var labelColor: Color {
        if isSelected {
            return .white
        }
        if isToday {
            return accentColor
        }
        if isFuture {
            return .white.opacity(0.3)
        }
        return .white.opacity(0.6)
    }
    
    private var borderColor: Color {
        if isSelected {
            return .clear
        }
        if isToday {
            return accentColor
        }
        if hasSessions {
            return accentColor.opacity(0.6)
        }
        return .white.opacity(0.2)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return .white
        }
        return .clear
    }
    
    private var numberColor: Color {
        if isSelected {
            return .black
        }
        if isToday {
            return accentColor
        }
        if isFuture {
            return .white.opacity(0.3)
        }
        return hasSessions ? .white : .white.opacity(0.7)
    }
}

#Preview {
    CalendarView(viewModel: TimerViewModel())
}
