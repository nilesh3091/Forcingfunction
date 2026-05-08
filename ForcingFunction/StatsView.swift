//
//  StatsView.swift
//  ForcingFunction
//
//  Statistics view
//

import SwiftUI

struct StatsView: View {
    @ObservedObject var viewModel: FocusSessionStore
    @State private var selectedDate: Date = Date()
    @State private var refreshTrigger: UUID = UUID()
    @State private var projectsExpanded: Bool = true

    private let dataStore = PomodoroDataStore.shared
    @ObservedObject private var projectStore = ProjectStore.shared
    private let calendar = Calendar.current

    private var allSessions: [PomodoroSession] {
        dataStore.getAllSessions()
    }

    private var sessionsForSelectedDay: [PomodoroSession] {
        let start = calendar.startOfDay(for: selectedDate)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(24 * 60 * 60)
        return dataStore.getSessions(from: start, to: end)
            .sorted { $0.startTime < $1.startTime }
    }

    private var workoutsForSelectedDay: [HealthWorkoutSession] {
        let start = calendar.startOfDay(for: selectedDate)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(24 * 60 * 60)
        return viewModel.healthWorkouts
            .filter { $0.startDate >= start && $0.startDate < end }
            .sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !projectStore.activeProjects.isEmpty {
                ProjectProgressSection(
                    projects: projectStore.activeProjects,
                    sessions: allSessions,
                    store: projectStore,
                    isExpanded: $projectsExpanded
                )
                Divider().overlay(HC.line)
            }

            DayTimelineView(
                sessions: sessionsForSelectedDay,
                workouts: workoutsForSelectedDay,
                selectedDate: $selectedDate,
                refreshAction: {
                    dataStore.loadSessions()
                    refreshTrigger = UUID()
                }
            )
            .id(refreshTrigger)
        }
        .background(HC.bg.ignoresSafeArea())
    }
}

// MARK: - Project Progress Section

struct ProjectProgressSection: View {
    let projects: [Project]
    let sessions: [PomodoroSession]
    let store: ProjectStore
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text("PROJECTS")
                        .font(HC.mono(10, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(HC.muted)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(HC.muted)
                }
                .padding(.horizontal, HC.pagePaddingH)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(projects) { project in
                            ProjectProgressCard(
                                project: project,
                                focusMinutes: store.totalFocusMinutes(for: project.id, in: sessions)
                            )
                        }
                    }
                    .padding(.horizontal, HC.pagePaddingH)
                    .padding(.bottom, 14)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(HC.bg)
    }
}

// MARK: - Project Progress Card

struct ProjectProgressCard: View {
    let project: Project
    let focusMinutes: Double

    private var focusHours: Double { focusMinutes / 60.0 }
    private var progress: Double { min(1.0, focusHours / max(1, project.goalHours)) }

    private var formattedHours: String {
        let h = Int(focusHours)
        let m = Int(focusMinutes) % 60
        if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        return "\(m)m"
    }

    private var goalLabel: String {
        let g = Int(project.goalHours)
        if g >= 1000 {
            let k = Double(g) / 1000.0
            return k == k.rounded() ? "\(Int(k))k h" : String(format: "%.1fk h", k)
        }
        return "\(g) h"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row
            HStack(spacing: 6) {
                Circle()
                    .fill(project.color.color)
                    .frame(width: 8, height: 8)
                Text(project.name)
                    .font(HC.text(13, weight: .semibold))
                    .foregroundStyle(HC.ink)
                    .lineLimit(1)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(HC.line)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(project.color.color)
                        .frame(width: max(4, geo.size.width * progress), height: 4)
                }
            }
            .frame(height: 4)

            // Hours label
            HStack(spacing: 0) {
                Text(formattedHours)
                    .font(HC.mono(11, weight: .medium))
                    .foregroundStyle(HC.ink)
                Text(" / \(goalLabel)")
                    .font(HC.mono(11))
                    .foregroundStyle(HC.muted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 160)
        .hcCard(radius: HC.Radius.smallCard)
    }
}

#Preview {
    StatsView(viewModel: FocusSessionStore())
}
