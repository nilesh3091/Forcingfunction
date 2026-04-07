//
//  StatsView.swift
//  ForcingFunction
//
//  Statistics view
//

import SwiftUI

struct StatsView: View {
    @ObservedObject var viewModel: TimerViewModel
    @State private var selectedDate: Date = Date()
    @State private var refreshTrigger: UUID = UUID()

    private let dataStore = PomodoroDataStore.shared
    private let calendar = Calendar.current

    private var theme: AppTheme { viewModel.theme }

    private var sessionsForSelectedDay: [PomodoroSession] {
        let start = calendar.startOfDay(for: selectedDate)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(24 * 60 * 60)

        // Note: DataStore filters by startTime; timeline clamps blocks to day bounds.
        // Including "all sessions" here means work + breaks, all statuses that exist on disk.
        return dataStore.getSessions(from: start, to: end)
            .sorted { $0.startTime < $1.startTime }
    }
    
    var body: some View {
        NavigationView {
            DayTimelineView(
                theme: theme,
                sessions: sessionsForSelectedDay,
                selectedDate: $selectedDate
            )
            .id(refreshTrigger)
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dataStore.loadSessions()
                        refreshTrigger = UUID()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.accentColor)
                    }
                    .accessibilityLabel("Refresh")
                }
            }
        }
    }
}

#Preview {
    StatsView(viewModel: TimerViewModel())
}

