import SwiftUI

/// Google-Calendar-style single-day timeline with session blocks positioned by start/end time.
struct DayTimelineView: View {
    let theme: AppTheme
    let sessions: [PomodoroSession]
    @Binding var selectedDate: Date

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

    private func blockColor(for session: PomodoroSession) -> Color {
        switch session.sessionType {
        case .work:
            return theme.workAccent
        case .shortBreak, .longBreak:
            return theme.breakAccent
        }
    }

    private func blockOpacity(for session: PomodoroSession) -> Double {
        switch session.status {
        case .completed:
            return 0.92
        case .running, .paused:
            return 0.95
        case .cancelled:
            return 0.35
        }
    }

    private func blockBorderColor(for session: PomodoroSession) -> Color {
        switch session.status {
        case .completed:
            return theme.borderPrimary.opacity(0.45)
        case .running, .paused:
            return Color.white.opacity(0.65)
        case .cancelled:
            return Color.white.opacity(0.25)
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
                .overlay(theme.divider)
                .padding(.horizontal, 20)

            GeometryReader { geo in
                let timelineWidth = max(0, geo.size.width - leftGutterWidth - 20)
                let innerWidth = max(0, geo.size.width - 40)

                ScrollViewReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        ZStack(alignment: .topLeading) {
                            timelineGrid
                            timelineBlocks(timelineWidth: timelineWidth)
                            currentTimeLineLayer(timelineInnerWidth: innerWidth)

                            if calendar.isDateInToday(selectedDate) {
                                Color.clear
                                    .frame(width: 1, height: 1)
                                    .id(Self.timelineScrollNowId)
                                    .offset(x: 0, y: yOffset(for: Date()))
                                    .accessibilityHidden(true)
                            }
                        }
                        .frame(
                            maxWidth: .infinity,
                            minHeight: topPadding + hourHeight * 24 + bottomPadding,
                            alignment: .topLeading
                        )
                        .padding(.leading, 20)
                        .padding(.trailing, 20)
                    }
                    .onAppear {
                        scrollToNowIfToday(using: scrollProxy, animated: false)
                        DispatchQueue.main.async {
                            scrollToNowIfToday(using: scrollProxy, animated: true)
                        }
                    }
                    .onChange(of: selectedDate) { _, newDate in
                        if calendar.isDateInToday(newDate) {
                            DispatchQueue.main.async {
                                scrollToNowIfToday(using: scrollProxy, animated: true)
                            }
                        }
                    }
                }
            }
        }
        .background(theme.background(.primary).ignoresSafeArea())
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

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Timeline")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.text(.primary))

                Text(dayTitle)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .tracking(0.4)
                    .foregroundColor(theme.text(.secondary))
            }

            Spacer()

            Button {
                selectedDate = Date()
            } label: {
                Text("Today")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .tracking(0.4)
                    .foregroundColor(theme.text(.primary))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(theme.background(.secondary))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(theme.borderPrimary.opacity(0.55), lineWidth: 1)
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
            .tint(theme.accentColor)
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
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.text(.tertiary))
                        .frame(width: leftGutterWidth, height: hourHeight, alignment: .topTrailing)
                        .padding(.trailing, 10)
                        .padding(.top, 2)

                    VStack(spacing: 0) {
                        ForEach(0..<quartersPerHour, id: \.self) { quarter in
                            VStack(spacing: 0) {
                                Rectangle()
                                    .fill(
                                        quarter == 0
                                            ? theme.borderSecondary.opacity(0.5)
                                            : theme.borderSecondary.opacity(0.28)
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
            sessions: sessions,
            dayStart: dayRange.start,
            dayEnd: dayRange.end
        )

        if blocks.isEmpty {
            HStack(spacing: 0) {
                Spacer().frame(width: leftGutterWidth + 10)
                Text("No sessions")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.text(.tertiary, opacity: 0.75))
                    .padding(.top, topPadding + 10)
                Spacer()
            }
        } else {
            let laidOut = DayTimelineLayout.layout(blocks: blocks)

            ForEach(laidOut) { item in
                let y = yOffset(for: item.start)
                let endY = yOffset(for: item.end)
                // Strict duration on the timeline (no artificial minimum height).
                let height = max(1, endY - y)

                let usableWidth = max(0, timelineWidth - 10)
                let columnGap: CGFloat = 6
                let columns = max(1, item.columnCount)
                let width = (usableWidth - CGFloat(columns - 1) * columnGap) / CGFloat(columns)
                let x = leftGutterWidth + 10 + CGFloat(item.column) * (width + columnGap)

                DayTimelineBlockView(
                    theme: theme,
                    title: item.session.sessionType.displayName,
                    timeRange: timeRangeText(start: item.start, end: item.end),
                    color: blockColor(for: item.session),
                    fillOpacity: blockOpacity(for: item.session),
                    borderColor: blockBorderColor(for: item.session),
                    isCancelled: item.session.status == .cancelled
                )
                .frame(width: max(0, width), height: height, alignment: .topLeading)
                .clipped()
                .offset(x: x, y: y)
            }
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        // Google-ish: 12am, 1am, 12pm...
        let isPM = hour >= 12
        let h = hour % 12 == 0 ? 12 : hour % 12
        return "\(h)\(isPM ? "pm" : "am")"
    }

    /// Horizontal “now” line; live-updating when viewing today.
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
                                .fill(theme.warning)
                                .frame(width: max(0, timelineInnerWidth), height: 2)
                                .shadow(color: theme.warning.opacity(0.45), radius: 4, y: 1)
                                .offset(x: 0, y: y - 1)

                            Circle()
                                .fill(theme.warning)
                                .frame(width: 7, height: 7)
                                .overlay(
                                    Circle()
                                        .stroke(theme.text(.primary).opacity(0.35), lineWidth: 1)
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
    let theme: AppTheme
    let title: String
    let timeRange: String
    let color: Color
    let fillOpacity: Double
    let borderColor: Color
    let isCancelled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .tracking(0.3)
                .foregroundColor(theme.text(.primary))
                .lineLimit(1)

            Text(timeRange)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(theme.text(.secondary))
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
    let session: PomodoroSession
    let start: Date
    let end: Date

    static func makeBlocks(sessions: [PomodoroSession], dayStart: Date, dayEnd: Date) -> [DayTimelineBlock] {
        sessions.compactMap { s in
            let rawStart = s.startTime
            let rawEnd = s.endTime ?? Date()

            let start = max(dayStart, min(dayEnd, rawStart))
            let end = max(dayStart, min(dayEnd, rawEnd))

            guard end > start else { return nil }
            return DayTimelineBlock(id: s.id, session: s, start: start, end: end)
        }
        .sorted { $0.start < $1.start }
    }
}

struct DayTimelineLayoutItem: Identifiable {
    let id: UUID
    let session: PomodoroSession
    let start: Date
    let end: Date
    let column: Int
    let columnCount: Int
}

enum DayTimelineLayout {
    /// Side-by-side overlap layout (Google Calendar style).
    static func layout(blocks: [DayTimelineBlock]) -> [DayTimelineLayoutItem] {
        guard !blocks.isEmpty else { return [] }

        // 1) Build overlap groups (connected components by time overlap).
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

        // 2) For each group, assign columns via greedy sweep.
        var out: [DayTimelineLayoutItem] = []
        out.reserveCapacity(blocks.count)

        for group in groups {
            // Active columns: (endTime, columnIndex)
            var active: [(Date, Int)] = []
            var nextColumn = 0
            var assigned: [(DayTimelineBlock, Int)] = []

            for b in group.sorted(by: { $0.start < $1.start }) {
                // release finished
                active.removeAll { (end, _) in end <= b.start }

                let used = Set(active.map { $0.1 })
                var col = 0
                while used.contains(col) { col += 1 }
                nextColumn = max(nextColumn, col + 1)

                active.append((b.end, col))
                assigned.append((b, col))
            }

            // Column count for the entire overlap component.
            let columnCount = max(1, nextColumn)

            for (b, col) in assigned {
                out.append(
                    DayTimelineLayoutItem(
                        id: b.id,
                        session: b.session,
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

