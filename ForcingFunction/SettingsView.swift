//
//  SettingsView.swift
//  ForcingFunction
//
//  Settings page with all configuration options
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: TimerViewModel
    
    private let pomodoroMinutesOptions: [Double] = [0, 15, 30, 45, 60]
    
    /// 30-minute slots: 0 = off … 48 = 24 h (`slot * 30` minutes).
    private var dailyGoalSlotBinding: Binding<Int> {
        Binding(
            get: {
                min(48, viewModel.dailyFocusGoalMinutes / 30)
            },
            set: { slot in
                viewModel.dailyFocusGoalMinutes = min(48, max(0, slot)) * 30
            }
        )
    }
    
    private func formatHalfHourSlotLabel(_ slot: Int) -> String {
        let minutes = slot * 30
        if minutes == 0 { return "Off" }
        let h = minutes / 60
        let m = minutes % 60
        if m == 0 { return h == 1 ? "1 h" : "\(h) h" }
        if h == 0 { return "\(m)m" }
        return "\(h)h \(m)m"
    }
    
    var body: some View {
        ZStack {
            HC.bg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                pageHeader
                
                Rectangle()
                    .fill(HC.line)
                    .frame(height: 1)
                
                Form {
                    Section(header: sectionHeader("Appearance")) {
                        HStack {
                            Text("Mode")
                                .font(HC.text(16))
                                .foregroundStyle(HC.ink)
                            Spacer()
                            Picker("", selection: Binding(
                                get: { viewModel.appAppearance },
                                set: { viewModel.appAppearance = $0 }
                            )) {
                                ForEach(AppAppearance.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundStyle(HC.red)
                        }
                    }
                    .listRowBackground(HC.card)
                    .listRowSeparatorTint(HC.line)
                    
                    Section(header: sectionHeader("Session Durations")) {
                        HStack {
                            Text("Pomodoro Length")
                                .font(HC.text(16))
                                .foregroundStyle(HC.ink)
                            Spacer()
                            Picker("", selection: $viewModel.pomodoroMinutes) {
                                ForEach(pomodoroMinutesOptions, id: \.self) { minutes in
                                    Text("\(Int(minutes)) min").tag(minutes)
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundStyle(HC.red)
                            .onChange(of: viewModel.pomodoroMinutes) { _, _ in
                                viewModel.updateSettings()
                            }
                        }
                        
                        HStack {
                            Text("Short Break")
                                .font(HC.text(16))
                                .foregroundStyle(HC.ink)
                            Spacer()
                            Picker("", selection: $viewModel.shortBreakMinutes) {
                                ForEach(1...30, id: \.self) { minutes in
                                    Text("\(minutes) min").tag(Double(minutes))
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundStyle(HC.red)
                            .onChange(of: viewModel.shortBreakMinutes) { _, _ in
                                viewModel.updateSettings()
                            }
                        }
                        
                        HStack {
                            Text("Long Break")
                                .font(HC.text(16))
                                .foregroundStyle(HC.ink)
                            Spacer()
                            Picker("", selection: $viewModel.longBreakMinutes) {
                                ForEach(5...60, id: \.self) { minutes in
                                    Text("\(minutes) min").tag(Double(minutes))
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundStyle(HC.red)
                            .onChange(of: viewModel.longBreakMinutes) { _, _ in
                                viewModel.updateSettings()
                            }
                        }
                    }
                    .listRowBackground(HC.card)
                    .listRowSeparatorTint(HC.line)
                    
                    Section(header: sectionHeader("Pomodoro Cycle")) {
                        HStack {
                            Text("Pomodoros Before Long Break")
                                .font(HC.text(16))
                                .foregroundStyle(HC.ink)
                            Spacer()
                            Picker("", selection: $viewModel.pomodorosBeforeLongBreak) {
                                ForEach(1...10, id: \.self) { count in
                                    Text("\(count)").tag(count)
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundStyle(HC.red)
                        }
                    }
                    .listRowBackground(HC.card)
                    .listRowSeparatorTint(HC.line)
                    
                    Section(header: sectionHeader("Focus Goal")) {
                        Text("How long you want to focus each day. The main timer and home widget use this as today's target.")
                            .font(HC.text(13))
                            .foregroundStyle(HC.muted)
                        
                        HStack {
                            Text("Daily target")
                                .font(HC.text(16))
                                .foregroundStyle(HC.ink)
                            Spacer()
                            Picker("", selection: dailyGoalSlotBinding) {
                                ForEach(0...48, id: \.self) { slot in
                                    Text(formatHalfHourSlotLabel(slot)).tag(slot)
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundStyle(HC.red)
                            .onChange(of: viewModel.dailyFocusGoalMinutes) { _, _ in
                                WidgetDataManager.shared.updateWidgetData()
                            }
                        }
                    }
                    .listRowBackground(HC.card)
                    .listRowSeparatorTint(HC.line)
                    
                    Section(header: sectionHeader("Dial Settings")) {
                        HStack {
                            Text("Snap Increment")
                                .font(HC.text(16))
                                .foregroundStyle(HC.ink)
                            Spacer()
                            Picker("", selection: $viewModel.snapIncrement) {
                                Text("1 minute").tag(1.0)
                                Text("5 minutes").tag(5.0)
                                Text("15 minutes").tag(15.0)
                            }
                            .pickerStyle(.menu)
                            .foregroundStyle(HC.red)
                        }
                    }
                    .listRowBackground(HC.card)
                    .listRowSeparatorTint(HC.line)
                    
                    Section(header: sectionHeader("Behavior")) {
                        Toggle(isOn: $viewModel.autoStartNext) {
                            Text("Auto-start Next Session")
                                .font(HC.text(16))
                                .foregroundStyle(HC.ink)
                        }
                        .tint(HC.red)
                        
                        Toggle(isOn: $viewModel.playSoundOnCompletion) {
                            Text("Play Sound on Completion")
                                .font(HC.text(16))
                                .foregroundStyle(HC.ink)
                        }
                        .tint(HC.red)
                        
                        Toggle(isOn: $viewModel.hapticsEnabled) {
                            Text("Haptic Feedback")
                                .font(HC.text(16))
                                .foregroundStyle(HC.ink)
                        }
                        .tint(HC.red)
                        
                        Toggle(isOn: $viewModel.liveActivitiesEnabled) {
                            Text("Live Activities")
                                .font(HC.text(16))
                                .foregroundStyle(HC.ink)
                        }
                        .tint(HC.red)
                        .onChange(of: viewModel.liveActivitiesEnabled) { oldValue, newValue in
                            if !newValue {
                                LiveActivityManager.shared.endActivity()
                            }
                        }
                    }
                    .listRowBackground(HC.card)
                    .listRowSeparatorTint(HC.line)
                    
                    Section(header: sectionHeader("Statistics")) {
                        HStack {
                            Text("Total Focus Time")
                                .font(HC.text(16))
                                .foregroundStyle(HC.ink)
                            Spacer()
                            Text(AngleUtilities.formatFocusTime(viewModel.totalFocusMinutes))
                                .font(HC.text(16, weight: .semibold))
                                .foregroundStyle(HC.red)
                        }
                        
                        HStack {
                            Text("Completed Pomodoros")
                                .font(HC.text(16))
                                .foregroundStyle(HC.ink)
                            Spacer()
                            Text("\(viewModel.completedPomodoros)")
                                .font(HC.text(16, weight: .semibold))
                                .foregroundStyle(HC.red)
                        }
                        
                        Button(action: {
                            viewModel.totalFocusMinutes = 0
                            viewModel.completedPomodoros = 0
                        }) {
                            Text("Reset Statistics")
                                .font(HC.text(16))
                                .foregroundStyle(HC.red)
                        }
                    }
                    .listRowBackground(HC.card)
                    .listRowSeparatorTint(HC.line)
                }
                .scrollContentBackground(.hidden)
            }
        }
    }
    
    private var pageHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("APP")
                    .hcMonoLabel()
                Text("Settings")
                    .font(HC.display(28))
                    .foregroundStyle(HC.ink)
                    .tracking(-0.5)
            }
            Spacer()
        }
        .padding(.horizontal, HC.pagePaddingH)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(HC.mono(10, weight: .medium))
            .tracking(1.2)
            .foregroundStyle(HC.muted)
    }
}

#Preview {
    SettingsView(viewModel: TimerViewModel())
}
