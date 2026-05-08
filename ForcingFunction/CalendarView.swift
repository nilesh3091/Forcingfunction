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
    let items: [CalendarItem]
}

private enum CalendarItem: Identifiable {
    case focus(PomodoroSession)
    case workout(HealthWorkoutSession)
    
    var id: UUID {
        switch self {
        case .focus(let s): return s.id
        case .workout(let w): return w.id
        }
    }
    
    var startTime: Date {
        switch self {
        case .focus(let s): return s.startTime
        case .workout(let w): return w.startDate
        }
    }
}

struct CalendarView: View {
    @ObservedObject var viewModel: FocusSessionStore
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
    
    private var workouts: [HealthWorkoutSession] {
        viewModel.healthWorkouts
    }
    
    // Get dates that have sessions (for calendar indicators)
    private var datesWithSessions: Set<Date> {
        var days = Set(workSessions.map { calendar.startOfDay(for: $0.startTime) })
        for w in workouts {
            days.insert(calendar.startOfDay(for: w.startDate))
        }
        return days
    }
    
    // Dates shown in the horizontal date strip (recent history window)
    private var dateStripDays: [Date] {
        guard let minSessionDate = workSessions.map({ $0.startTime }).min() else {
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
    
    private var filteredWorkouts: [HealthWorkoutSession] {
        guard let range = currentDateRange else {
            return workouts.sorted { $0.startDate > $1.startDate }
        }
        return workouts
            .filter { $0.startDate >= range.start && $0.startDate <= range.end }
            .sorted { $0.startDate > $1.startDate }
    }
    
    // Sessions grouped by day for list sections
    private var groupedSessions: [SessionDayGroup] {
        let focusItems = filteredSessions.map { CalendarItem.focus($0) }
        let workoutItems = filteredWorkouts.map { CalendarItem.workout($0) }
        let allItems = (focusItems + workoutItems)
            .sorted { $0.startTime > $1.startTime }
        
        let groupedDictionary: [Date: [CalendarItem]] = Dictionary(
            grouping: allItems,
            by: { item in
                calendar.startOfDay(for: item.startTime)
            }
        )
        
        let groups: [SessionDayGroup] = groupedDictionary.map { entry in
            let date = entry.key
            let itemsForDate = entry.value.sorted { lhs, rhs in
                lhs.startTime > rhs.startTime
            }
            return SessionDayGroup(id: date, date: date, items: itemsForDate)
        }
        
        return groups.sorted { $0.date > $1.date }
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
        makeSummarySubtitle(for: filteredSessions, workouts: filteredWorkouts)
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
        ZStack {
            HC.bg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                pageHeader
                
                Rectangle()
                    .fill(HC.line)
                    .frame(height: 1)
                    .padding(.horizontal, HC.pagePaddingH)
                
                rangeHeader
                
                Rectangle()
                    .fill(HC.line)
                    .frame(height: 1)
                    .padding(.horizontal, HC.pagePaddingH)
                
                sessionsContent
            }
        }
        .sheet(isPresented: $isCalendarPresented) {
            calendarSheet
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
    
    private func makeSummarySubtitle(for sessions: [PomodoroSession], workouts: [HealthWorkoutSession]) -> String {
        let focusCount = sessions.count
        let workoutCount = workouts.count
        guard focusCount + workoutCount > 0 else {
            return "No sessions yet"
        }
        
        let totalFocus = totalFocusedMinutes(for: sessions)
        let totalWorkouts = workouts.reduce(0) { $0 + $1.durationMinutes }
        
        let dayStartDates = sessions.map { calendar.startOfDay(for: $0.startTime) } + workouts.map { calendar.startOfDay(for: $0.startDate) }
        let distinctDays = Set<Date>(dayStartDates).count
        let streakDays = currentStreakDays()
        
        var parts: [String] = []
        if focusCount > 0 { parts.append("\(focusCount) focus") }
        if workoutCount > 0 { parts.append("\(workoutCount) workout\(workoutCount == 1 ? "" : "s")") }
        if focusCount > 0 { parts.append("\(totalFocus) min focused") }
        if workoutCount > 0 { parts.append("\(totalWorkouts) min trained") }
        
        if distinctDays > 1 {
            parts.append("\(distinctDays) days active")
        }
        
        if streakDays > 1 {
            parts.append("Streak: \(streakDays) days")
        }
        
        return parts.joined(separator: " • ")
    }

    private func currentStreakDays() -> Int {
        var allSessionDays: Set<Date> = Set(workSessions.map { calendar.startOfDay(for: $0.startTime) })
        for w in workouts {
            allSessionDays.insert(calendar.startOfDay(for: w.startDate))
        }
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
    
    private var pageHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("HISTORY")
                    .hcMonoLabel()
                Text("Sessions")
                    .font(HC.display(28))
                    .foregroundStyle(HC.ink)
                    .tracking(-0.5)
            }
            Spacer()
            browseButton
        }
        .padding(.horizontal, HC.pagePaddingH)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
    
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
                selectedSpecificDate = nil
            }
            
            DateStripView(
                dates: dateStripDays,
                selectedDate: stripSelectedDate,
                datesWithSessions: datesWithSessions,
                calendar: calendar
            ) { date in
                selectedSpecificDate = date
                selectedRange = .today
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(summaryTitle)
                    .font(HC.display(17))
                    .foregroundStyle(HC.ink)
                
                Text(summarySubtitle)
                    .font(HC.text(13))
                    .foregroundStyle(HC.muted)
            }
        }
        .padding(.horizontal, HC.pagePaddingH)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }
    
    @ViewBuilder
    private var sessionsContent: some View {
        if filteredSessions.isEmpty && filteredWorkouts.isEmpty {
            emptySessionsView
        } else {
            sessionsListView
        }
    }
    
    private var emptySessionsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(HC.muted)
            
            Text("No sessions in this range yet")
                .font(HC.text(15))
                .foregroundStyle(HC.muted)
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
        .background(HC.bg)
    }

    private func sectionView(for group: SessionDayGroup) -> some View {
        Section(
            header: DayHeaderView(
                date: group.date,
                sessions: group.items.compactMap { item in
                    if case .focus(let s) = item { return s }
                    return nil
                },
                calendar: calendar
            )
        ) {
            ForEach(group.items) { item in
                Group {
                    switch item {
                    case .focus(let session):
                        PomodoroSessionCard(session: session, accentColor: HC.red)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if session.status == .cancelled {
                                    Button(role: .destructive) {
                                        deleteSession(session)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                    case .workout(let workout):
                        WorkoutSessionCard(workout: workout, accentColor: HC.red)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(
                    EdgeInsets(
                        top: 0,
                        leading: HC.pagePaddingH,
                        bottom: 16,
                        trailing: HC.pagePaddingH
                    )
                )
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
            .font(HC.text(14, weight: .medium))
            .foregroundStyle(HC.red)
        }
    }
    
    private var calendarSheet: some View {
        NavigationView {
            ZStack {
                HC.bg.ignoresSafeArea()
                
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
                        accentColor: HC.red,
                        onDaySelected: { _ in
                            isCalendarPresented = false
                        }
                    )
                    .padding(.horizontal, HC.pagePaddingH)
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
                    .foregroundStyle(HC.ink)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Clear") {
                        selectedSpecificDate = nil
                        isCalendarPresented = false
                    }
                    .foregroundStyle(HC.red)
                }
            }
        }
    }
    
    private func deleteSession(_ session: PomodoroSession) {
        dataStore.deleteSession(byId: session.id)
        refreshTrigger = UUID()
    }
}

// MARK: - Workout Card

private struct WorkoutSessionCard: View {
    let workout: HealthWorkoutSession
    let accentColor: Color
    
    private var durationString: String {
        "\(workout.durationMinutes) min"
    }
    
    private var timeRangeString: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return "\(f.string(from: workout.startDate)) - \(f.string(from: workout.endDate))"
    }
    
    private static let workoutGreen = Color(red: 0.20, green: 0.58, blue: 0.40)
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Self.workoutGreen.opacity(0.12))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "figure.run")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Self.workoutGreen)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(workout.activityName)
                        .font(HC.text(15, weight: .semibold))
                        .foregroundStyle(HC.ink)
                    
                    Spacer()
                    
                    Text("Workout")
                        .font(HC.text(11, weight: .medium))
                        .foregroundStyle(Self.workoutGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Self.workoutGreen.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: HC.Radius.tag, style: .continuous))
                }
                
                HStack(spacing: 12) {
                    Label(durationString, systemImage: "clock.fill")
                        .font(HC.text(13))
                        .foregroundStyle(HC.muted)
                    
                    Text("•")
                        .foregroundStyle(HC.muted.opacity(0.5))
                    
                    Text(timeRangeString)
                        .font(HC.text(12))
                        .foregroundStyle(HC.muted)
                }
                
                if let source = workout.sourceName, !source.isEmpty {
                    Text(source)
                        .font(HC.text(11, weight: .medium))
                        .foregroundStyle(accentColor.opacity(0.85))
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .hcCard(radius: HC.Radius.smallCard)
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
        
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) - 1
        let daysCount = calendar.dateComponents([.day], from: firstDayOfMonth, to: lastDayOfMonth).day ?? 0
        
        var days: [Date?] = []
        
        for _ in 0..<firstWeekday {
            days.append(nil)
        }
        
        for dayOffset in 0...daysCount {
            if let day = calendar.date(byAdding: .day, value: dayOffset, to: firstDayOfMonth) {
                days.append(day)
            }
        }
        
        return days
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: {
                    withAnimation {
                        if let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
                            currentMonth = previousMonth
                        }
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(HC.text(14, weight: .semibold))
                        .foregroundStyle(HC.ink)
                        .frame(width: 32, height: 32)
                        .background(HC.card)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(HC.line, lineWidth: 1))
                }
                
                Spacer()
                
                Text(monthYearString)
                    .font(HC.display(17))
                    .foregroundStyle(HC.ink)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
                            currentMonth = nextMonth
                        }
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(HC.text(14, weight: .semibold))
                        .foregroundStyle(HC.ink)
                        .frame(width: 32, height: 32)
                        .background(HC.card)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(HC.line, lineWidth: 1))
                }
            }
            
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(HC.mono(10, weight: .medium))
                        .foregroundStyle(HC.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            
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
                    .font(HC.text(14, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(
                        isSelected ? Color.white :
                        isToday ? accentColor :
                        HC.ink
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
    
    private var isPartialCancelledIncomplete: Bool {
        guard session.status == .cancelled, session.endTime != nil else { return false }
        let elapsed = session.billedMinutes
        let planned = session.plannedDurationMinutes
        return elapsed > 0 && elapsed < planned
    }
    
    private var durationString: String {
        if isPartialCancelledIncomplete {
            let elapsed = session.billedMinutes
            let planned = Int(session.plannedDurationMinutes.rounded())
            let completed = min(Int(floor(elapsed)), planned)
            return "\(completed) / \(planned) min"
        }
        if let activeDuration = session.activeDurationMinutes {
            return "\(Int(activeDuration)) min"
        } else if let actualDuration = session.actualDurationMinutes {
            return "\(Int(actualDuration)) min"
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
        formatter.dateFormat = "MMM d"
        return formatter.string(from: session.startTime)
    }
    
    private var statusColor: Color {
        let base = session.tagColor?.color ?? accentColor
        switch session.status {
        case .completed:
            return base
        case .cancelled:
            return isPartialCancelledIncomplete ? .orange : HC.muted
        case .paused, .running:
            return .orange
        }
    }
    
    private var statusText: String {
        switch session.status {
        case .completed:
            return "Completed"
        case .cancelled:
            return isPartialCancelledIncomplete ? "Incomplete" : "Cancelled"
        case .paused:
            return "Paused"
        case .running:
            return "Running"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "timer")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(session.title?.isEmpty == false ? session.title! : "Work")
                        .font(HC.text(15, weight: .semibold))
                        .foregroundStyle(HC.ink)
                    
                    Spacer()
                    
                    Text(statusText)
                        .font(HC.text(11, weight: .medium))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: HC.Radius.tag, style: .continuous))
                }
                
                if let tag = session.tag, !tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(tag)
                        .font(HC.text(11, weight: .medium))
                        .foregroundStyle((session.tagColor?.color ?? accentColor).opacity(0.95))
                        .lineLimit(1)
                }
                
                HStack(spacing: 12) {
                    Label(durationString, systemImage: "clock.fill")
                        .font(HC.text(13))
                        .foregroundStyle(HC.muted)
                    
                    Text("•")
                        .foregroundStyle(HC.muted.opacity(0.5))
                    
                    Text(dateString)
                        .font(HC.text(13))
                        .foregroundStyle(HC.muted)
                }
                
                Text(timeRangeString)
                    .font(HC.text(12))
                    .foregroundStyle(HC.muted)
            }
        }
        .padding(16)
        .hcCard(radius: HC.Radius.smallCard)
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
                .font(HC.text(14, weight: .semibold))
                .foregroundStyle(HC.ink)
            
            Text(subtitle)
                .font(HC.text(12))
                .foregroundStyle(HC.muted)
        }
        .padding(.leading, HC.pagePaddingH)
        .padding(.bottom, 4)
        .background(HC.bg)
    }
}

// MARK: - Date Strip

private struct DateStripView: View {
    let dates: [Date]
    let selectedDate: Date?
    let datesWithSessions: Set<Date>
    let calendar: Calendar
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
                        isFuture: isFuture
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
                    .font(HC.mono(11, weight: .medium))
                    .foregroundStyle(labelColor)
                
                ZStack {
                    Circle()
                        .fill(backgroundColor)
                        .frame(width: 32, height: 32)
                    
                    Circle()
                        .strokeBorder(borderColor, lineWidth: isSelected ? 0 : 1)
                        .frame(width: 32, height: 32)
                    
                    Text(dayNumber)
                        .font(HC.text(15, weight: .semibold))
                        .foregroundStyle(numberColor)
                }
            }
            .padding(.horizontal, 2)
        }
        .buttonStyle(.plain)
    }
    
    private var labelColor: Color {
        if isSelected { return .white }
        if isToday { return HC.red }
        if isFuture { return HC.muted.opacity(0.4) }
        return HC.muted
    }
    
    private var borderColor: Color {
        if isSelected { return .clear }
        if isToday { return HC.red }
        if hasSessions { return HC.red.opacity(0.4) }
        return HC.line
    }
    
    private var backgroundColor: Color {
        if isSelected { return HC.ink }
        return .clear
    }
    
    private var numberColor: Color {
        if isSelected { return .white }
        if isToday { return HC.red }
        if isFuture { return HC.muted.opacity(0.4) }
        return hasSessions ? HC.ink : HC.muted
    }
}

#Preview {
    CalendarView(viewModel: FocusSessionStore())
}
