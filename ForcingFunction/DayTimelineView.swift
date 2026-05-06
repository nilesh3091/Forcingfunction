import SwiftUI

/// Google-Calendar-style single-day timeline with session blocks positioned by start/end time.
struct DayTimelineView: View {
    let sessions: [PomodoroSession]
    let workouts: [HealthWorkoutSession]
    @Binding var selectedDate: Date
    var refreshAction: (() -> Void)? = nil

    private static let breakColor = Color(red: 0.20, green: 0.58, blue: 0.40)

    private let calendar = Calendar.current
    /// Anchor for `ScrollViewReader` — must match `.id` on the invisible marker.
    private static let timelineScrollNowId = "timelineScrollNow"

    // Layout (each hour = four 15-minute bands). Larger hourHeight → clearer quarters & proportional blocks.
    private let hourHeight: CGFloat = 120
    private let quartersPerHour: Int = 4
    private var quarterHeight: CGFloat { hourHeight / CGFloat(quartersPerHour) }
    private let leftGutterWidth: CGFloat = 54
    private let topPadding: CGFloat = 12
    private let bottomPadding: CGFloat = 24

    private var dayRange: (start: Date, end: Date) {
        let start = calendar.startOfDay(for: selectedDate)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(24 * 60 * 60)
        return (start, end)
    }

    private var dayTitle: String {
        if calendar.isDateInToday(selectedDate) { return "Today" }
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: selectedDate)
    }

    private var pixelsPerMinute: CGFloat {
        hourHeight / 60.0
    }

    private func yOffset(for date: Date) -> CGFloat {
        let start = dayRange.start
        let minutes = max(0, min(24 * 60, date.timeIntervalSince(start) / 60.0))
        return topPadding + CGFloat(minutes) * pixelsPerMinute
    }

    private func blockColor(for item: TimelineItem) -> Color {
        switch item.kind {
        case .focus:
            return item.session.map { s in
                switch s.sessionType {
                case .work: return HC.red
                case .shortBreak, .longBreak: return Self.breakColor
                }
            } ?? HC.red
        case .workout:
            return Self.breakColor
        }
    }

    private func blockOpacity(for item: TimelineItem) -> Double {
        switch item.kind {
        case .workout:
            return 0.85
        case .focus:
            guard let s = item.session else { return 0.92 }
            switch s.status {
            case .completed:
                return 0.92
            case .running, .paused:
                return 0.95
            case .cancelled:
                return 0.35
            }
        }
    }

    private func blockBorderColor(for item: TimelineItem) -> Color {
        switch item.kind {
        case .workout:
            return Self.breakColor.opacity(0.4)
        case .focus:
            guard let s = item.session else { return HC.line }
            switch s.status {
            case .completed:
                return HC.line
            case .running, .paused:
                return HC.red.opacity(0.6)
            case .cancelled:
                return HC.line.opacity(0.35)
            }
        }
    }

    private func timeRangeText(start: Date, end: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return "\(f.string(from: start))–\(f.string(from: end))"
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .overlay(HC.line)
                .padding(.horizontal, 20)

            GeometryReader { geo in
                let timelineWidth = max(0, geo.size.width - leftGutterWidth - 20)
                let innerWidth = max(0, geo.size.width - 40)
                let totalScrollHeight = topPadding + hourHeight * 24 + bottomPadding

                ScrollViewReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        timelineScrollableContent(
                            totalScrollHeight: totalScrollHeight,
                            timelineWidth: timelineWidth,
                            innerWidth: innerWidth
                        )
                        .padding(.leading, 20)
                        .padding(.trailing, 20)
                    }
                    .onAppear {
                        scheduleScrollToNow(using: scrollProxy)
                    }
                    .onChange(of: selectedDate) { _, newDate in
                        if calendar.isDateInToday(newDate) {
                            scheduleScrollToNow(using: scrollProxy)
                        }
                    }
                }
            }
        }
        .background(HC.bg.ignoresSafeArea())
    }

    private func scrollToNowIfToday(using proxy: ScrollViewProxy, animated: Bool) {
        guard calendar.isDateInToday(selectedDate) else { return }
        let anchor = UnitPoint(x: 0.5, y: 0.38)
        if animated {
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(Self.timelineScrollNowId, anchor: anchor)
            }
        } else {
            proxy.scrollTo(Self.timelineScrollNowId, anchor: anchor)
        }
    }

    /// Scroll after layout is ready (tab switch / `NavigationView` often scrolls too early).
    private func scheduleScrollToNow(using proxy: ScrollViewProxy) {
        guard calendar.isDateInToday(selectedDate) else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            scrollToNowIfToday(using: proxy, animated: false)
            try? await Task.sleep(for: .milliseconds(120))
            scrollToNowIfToday(using: proxy, animated: false)
            try? await Task.sleep(for: .milliseconds(150))
            scrollToNowIfToday(using: proxy, animated: true)
        }
    }

    @ViewBuilder
    private func timelineScrollableContent(
        totalScrollHeight: CGFloat,
        timelineWidth: CGFloat,
        innerWidth: CGFloat
    ) -> some View {
        if calendar.isDateInToday(selectedDate) {
            VStack(spacing: 0) {
                Color.clear.frame(height: yOffset(for: Date()))
                Color.clear
                    .frame(width: 1, height: 1)
                    .id(Self.timelineScrollNowId)
                    .accessibilityHidden(true)
                Color.clear.frame(height: max(1, totalScrollHeight - yOffset(for: Date()) - 1))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)
            .overlay(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    timelineGrid
                    timelineBlocks(timelineWidth: timelineWidth)
                    currentTimeLineLayer(timelineInnerWidth: innerWidth)
                }
                .frame(maxWidth: .infinity, minHeight: totalScrollHeight, alignment: .topLeading)
                .allowsHitTesting(true)
            }
        } else {
            ZStack(alignment: .topLeading) {
                timelineGrid
                timelineBlocks(timelineWidth: timelineWidth)
                currentTimeLineLayer(timelineInnerWidth: innerWidth)
            }
            .frame(maxWidth: .infinity, minHeight: totalScrollHeight, alignment: .topLeading)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Timeline")
                    .font(HC.display(24))
                    .foregroundStyle(HC.ink)

                Text(dayTitle)
                    .font(HC.text(13))
                    .tracking(0.4)
                    .foregroundStyle(HC.muted)
            }

            Spacer()

            if let refresh = refreshAction {
                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(HC.text(14, weight: .semibold))
                        .foregroundStyle(HC.red)
                }
                .buttonStyle(.plain)
            }

            Button {
                selectedDate = Date()
            } label: {
                Text("Today")
                    .font(HC.text(12, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(HC.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(HC.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(HC.line, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)

            DatePicker(
                "",
                selection: $selectedDate,
                displayedComponents: [.date]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(HC.red)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var timelineGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(alignment: .top, spacing: 0) {
                    Text(hourLabel(hour))
                        .font(HC.text(11, weight: .medium))
                        .foregroundStyle(HC.muted)
                        .frame(width: leftGutterWidth, height: hourHeight, alignment: .topTrailing)
                        .padding(.trailing, 10)
                        .padding(.top, 2)

                    VStack(spacing: 0) {
                        ForEach(0..<quartersPerHour, id: \.self) { quarter in
                            VStack(spacing: 0) {
                                Rectangle()
                                    .fill(
                                        quarter == 0
                                            ? HC.line.opacity(0.5)
                                            : HC.line.opacity(0.28)
                                    )
                                    .frame(height: 0.5)
                                Spacer()
                                    .frame(height: max(0, quarterHeight - 0.5))
                            }
                            .frame(height: quarterHeight)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: hourHeight)
            }
        }
        .padding(.top, topPadding)
    }

    @ViewBuilder
    private func timelineBlocks(timelineWidth: CGFloat) -> some View {
        let blocks = DayTimelineBlock.makeBlocks(
            items: TimelineItem.makeItems(sessions: sessions, workouts: workouts),
            dayStart: dayRange.start,
            dayEnd: dayRange.end
        )

        if blocks.isEmpty {
            HStack(spacing: 0) {
                Spacer().frame(width: leftGutterWidth + 10)
                Text("No sessions")
                    .font(HC.text(12, weight: .medium))
                    .foregroundStyle(HC.muted.opacity(0.75))
                    .padding(.top, topPadding + 10)
                Spacer()
            }
        } else {
            let laidOut = DayTimelineLayout.layout(blocks: blocks)

            ForEach(laidOut) { item in
                let y = yOffset(for: item.start)
                let endY = yOffset(for: item.end)
                let height = max(1, endY - y)

                let usableWidth = max(0, timelineWidth - 10)
                let columnGap: CGFloat = 6
                let columns = max(1, item.columnCount)
                let width = (usableWidth - CGFloat(columns - 1) * columnGap) / CGFloat(columns)
                let x = leftGutterWidth + 10 + CGFloat(item.column) * (width + columnGap)

                DayTimelineBlockView(
                    title: item.title,
                    timeRange: timeRangeText(start: item.start, end: item.end),
                    color: blockColor(for: item.item),
                    fillOpacity: blockOpacity(for: item.item),
                    borderColor: blockBorderColor(for: item.item),
                    isCancelled: item.isCancelled
                )
                .frame(width: max(0, width), height: height, alignment: .topLeading)
                .clipped()
                .offset(x: x, y: y)
            }
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let isPM = hour >= 12
        let h = hour % 12 == 0 ? 12 : hour % 12
        return "\(h)\(isPM ? "pm" : "am")"
    }

    /// Horizontal "now" line; live-updating when viewing today.
    @ViewBuilder
    private func currentTimeLineLayer(timelineInnerWidth: CGFloat) -> some View {
        if calendar.isDateInToday(selectedDate) {
            TimelineView(.animation(minimumInterval: 1.0)) { context in
                let now = context.date
                if calendar.isDate(now, inSameDayAs: selectedDate) {
                    let y = yOffset(for: now)
                    let dayEndY = topPadding + CGFloat(24 * 60) * pixelsPerMinute
                    if y >= topPadding - 2, y <= dayEndY + 2 {
                        ZStack(alignment: .topLeading) {
                            Rectangle()
                                .fill(HC.red)
                                .frame(width: max(0, timelineInnerWidth), height: 2)
                                .shadow(color: HC.red.opacity(0.45), radius: 4, y: 1)
                                .offset(x: 0, y: y - 1)

                            Circle()
                                .fill(HC.red)
                                .frame(width: 7, height: 7)
                                .overlay(
                                    Circle()
                                        .stroke(HC.ink.opacity(0.35), lineWidth: 1)
                                )
                                .offset(x: leftGutterWidth - 2, y: y - 3.5)
                        }
                        .frame(
                            maxWidth: .infinity,
                            minHeight: topPadding + hourHeight * 24 + bottomPadding,
                            alignment: .topLeading
                        )
                        .allowsHitTesting(false)
                        .accessibilityLabel("Current time")
                        .accessibilityValue(
                            DateFormatter.localizedString(from: now, dateStyle: .none, timeStyle: .short)
                        )
                    }
                }
            }
        }
    }
}

private struct DayTimelineBlockView: View {
    let title: String
    let timeRange: String
    let color: Color
    let fillOpacity: Double
    let borderColor: Color
    let isCancelled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(HC.text(12, weight: .semibold))
                .tracking(0.3)
                .foregroundStyle(HC.ink)
                .lineLimit(1)

            Text(timeRange)
                .font(HC.text(11))
                .foregroundStyle(HC.muted)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.opacity(fillOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(borderColor, style: StrokeStyle(lineWidth: 1, dash: isCancelled ? [5, 4] : []))
                )
        )
        .shadow(color: color.opacity(isCancelled ? 0.0 : 0.18), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Block model + layout

struct DayTimelineBlock: Identifiable {
    let id: UUID
    let item: TimelineItem
    let start: Date
    let end: Date

    static func makeBlocks(items: [TimelineItem], dayStart: Date, dayEnd: Date) -> [DayTimelineBlock] {
        items.compactMap { i in
            let rawStart = i.start
            let rawEnd = i.end

            let start = max(dayStart, min(dayEnd, rawStart))
            let end = max(dayStart, min(dayEnd, rawEnd))

            guard end > start else { return nil }
            return DayTimelineBlock(id: i.id, item: i, start: start, end: end)
        }
        .sorted { $0.start < $1.start }
    }
}

struct DayTimelineLayoutItem: Identifiable {
    let id: UUID
    let item: TimelineItem
    let start: Date
    let end: Date
    let column: Int
    let columnCount: Int
    
    var title: String { item.title }
    var isCancelled: Bool { item.isCancelled }
}

enum DayTimelineLayout {
    /// Side-by-side overlap layout (Google Calendar style).
    static func layout(blocks: [DayTimelineBlock]) -> [DayTimelineLayoutItem] {
        guard !blocks.isEmpty else { return [] }

        var groups: [[DayTimelineBlock]] = []
        var current: [DayTimelineBlock] = []
        var currentMaxEnd: Date?

        for b in blocks {
            if current.isEmpty {
                current = [b]
                currentMaxEnd = b.end
                continue
            }

            if let maxEnd = currentMaxEnd, b.start < maxEnd {
                current.append(b)
                if b.end > maxEnd { currentMaxEnd = b.end }
            } else {
                groups.append(current)
                current = [b]
                currentMaxEnd = b.end
            }
        }
        if !current.isEmpty { groups.append(current) }

        var out: [DayTimelineLayoutItem] = []
        out.reserveCapacity(blocks.count)

        for group in groups {
            var active: [(Date, Int)] = []
            var nextColumn = 0
            var assigned: [(DayTimelineBlock, Int)] = []

            for b in group.sorted(by: { $0.start < $1.start }) {
                active.removeAll { (end, _) in end <= b.start }

                let used = Set(active.map { $0.1 })
                var col = 0
                while used.contains(col) { col += 1 }
                nextColumn = max(nextColumn, col + 1)

                active.append((b.end, col))
                assigned.append((b, col))
            }

            let columnCount = max(1, nextColumn)

            for (b, col) in assigned {
                out.append(
                    DayTimelineLayoutItem(
                        id: b.id,
                        item: b.item,
                        start: b.start,
                        end: b.end,
                        column: col,
                        columnCount: columnCount
                    )
                )
            }
        }

        return out
    }
}

// MARK: - Timeline model (focus + workouts)

struct TimelineItem: Identifiable {
    enum Kind {
        case focus
        case workout
    }
    
    let id: UUID
    let kind: Kind
    let start: Date
    let end: Date
    let title: String
    let isCancelled: Bool
    let session: PomodoroSession?
    
    static func makeItems(sessions: [PomodoroSession], workouts: [HealthWorkoutSession]) -> [TimelineItem] {
        let focus: [TimelineItem] = sessions.map { s in
            TimelineItem(
                id: s.id,
                kind: .focus,
                start: s.startTime,
                end: s.endTime ?? Date(),
                title: s.sessionType.displayName,
                isCancelled: s.status == .cancelled,
                session: s
            )
        }
        
        let w: [TimelineItem] = workouts.map { wk in
            TimelineItem(
                id: wk.id,
                kind: .workout,
                start: wk.startDate,
                end: wk.endDate,
                title: wk.activityName,
                isCancelled: false,
                session: nil
            )
        }
        
        return (focus + w).sorted { $0.start < $1.start }
    }
}
