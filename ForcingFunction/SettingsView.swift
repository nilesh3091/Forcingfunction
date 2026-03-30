//
//  SettingsView.swift
//  ForcingFunction
//
//  Settings page with all configuration options
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: TimerViewModel
    
    // Helper array for pomodoro minutes
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
        // slot 0…48 → minutes 0…1440
        let minutes = slot * 30
        if minutes == 0 { return "Off" }
        let h = minutes / 60
        let m = minutes % 60
        if m == 0 { return h == 1 ? "1 h" : "\(h) h" }
        if h == 0 { return "\(m)m" }
        return "\(h)h \(m)m"
    }
    
    private var theme: AppTheme {
        viewModel.theme
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                theme.background(.primary)
                    .ignoresSafeArea()
                
                Form {
                    Section(header: Text("Session Durations").foregroundColor(theme.text(.secondary))) {
                        // Pomodoro length
                        HStack {
                            Text("Pomodoro Length")
                                .foregroundColor(theme.text(.primary))
                            Spacer()
                            Picker("", selection: $viewModel.pomodoroMinutes) {
                                ForEach(pomodoroMinutesOptions, id: \.self) { minutes in
                                    Text("\(Int(minutes)) min").tag(minutes)
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(theme.accentColor)
                            .onChange(of: viewModel.pomodoroMinutes) { _, _ in
                                viewModel.updateSettings()
                            }
                        }
                        
                        // Short break length
                        HStack {
                            Text("Short Break")
                                .foregroundColor(theme.text(.primary))
                            Spacer()
                            Picker("", selection: $viewModel.shortBreakMinutes) {
                                ForEach(1...30, id: \.self) { minutes in
                                    Text("\(minutes) min").tag(Double(minutes))
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(theme.accentColor)
                            .onChange(of: viewModel.shortBreakMinutes) { _, _ in
                                viewModel.updateSettings()
                            }
                        }
                        
                        // Long break length
                        HStack {
                            Text("Long Break")
                                .foregroundColor(theme.text(.primary))
                            Spacer()
                            Picker("", selection: $viewModel.longBreakMinutes) {
                                ForEach(5...60, id: \.self) { minutes in
                                    Text("\(minutes) min").tag(Double(minutes))
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(theme.accentColor)
                            .onChange(of: viewModel.longBreakMinutes) { _, _ in
                                viewModel.updateSettings()
                            }
                        }
                    }
                    .listRowBackground(theme.background(.card))
                    
                    Section(header: Text("Pomodoro Cycle").foregroundColor(theme.text(.secondary))) {
                        // Pomodoros before long break
                        HStack {
                            Text("Pomodoros Before Long Break")
                                .foregroundColor(theme.text(.primary))
                            Spacer()
                            Picker("", selection: $viewModel.pomodorosBeforeLongBreak) {
                                ForEach(1...10, id: \.self) { count in
                                    Text("\(count)").tag(count)
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(theme.accentColor)
                        }
                    }
                    .listRowBackground(theme.background(.card))
                    
                    Section(header: Text("Focus goal").foregroundColor(theme.text(.secondary))) {
                        Text("How long you want to focus each day. The main timer and home widget use this as today’s target.")
                            .font(.footnote)
                            .foregroundColor(theme.text(.secondary))
                        
                        HStack {
                            Text("Daily target")
                                .foregroundColor(theme.text(.primary))
                            Spacer()
                            Picker("", selection: dailyGoalSlotBinding) {
                                ForEach(0...48, id: \.self) { slot in
                                    Text(formatHalfHourSlotLabel(slot)).tag(slot)
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(theme.accentColor)
                            .onChange(of: viewModel.dailyFocusGoalMinutes) { _, _ in
                                WidgetDataManager.shared.updateWidgetData()
                            }
                        }
                    }
                    .listRowBackground(theme.background(.card))
                    
                    Section(header: Text("Dial Settings").foregroundColor(theme.text(.secondary))) {
                        // Snap increment
                        HStack {
                            Text("Snap Increment")
                                .foregroundColor(theme.text(.primary))
                            Spacer()
                            Picker("", selection: $viewModel.snapIncrement) {
                                Text("1 minute").tag(1.0)
                                Text("5 minutes").tag(5.0)
                                Text("15 minutes").tag(15.0)
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(theme.accentColor)
                        }
                    }
                    .listRowBackground(theme.background(.card))
                    
                    Section(header: Text("Behavior").foregroundColor(theme.text(.secondary))) {
                        // Auto-start next session
                        Toggle(isOn: $viewModel.autoStartNext) {
                            Text("Auto-start Next Session")
                                .foregroundColor(theme.text(.primary))
                        }
                        .tint(theme.accentColor)
                        
                        // Play sound on completion
                        Toggle(isOn: $viewModel.playSoundOnCompletion) {
                            Text("Play Sound on Completion")
                                .foregroundColor(theme.text(.primary))
                        }
                        .tint(theme.accentColor)
                        
                        // Haptics
                        Toggle(isOn: $viewModel.hapticsEnabled) {
                            Text("Haptic Feedback")
                                .foregroundColor(theme.text(.primary))
                        }
                        .tint(theme.accentColor)
                        
                        // Live Activities
                        Toggle(isOn: $viewModel.liveActivitiesEnabled) {
                            Text("Live Activities")
                                .foregroundColor(theme.text(.primary))
                        }
                        .tint(theme.accentColor)
                        .onChange(of: viewModel.liveActivitiesEnabled) { oldValue, newValue in
                            if !newValue {
                                // End any active Live Activity when disabled
                                LiveActivityManager.shared.endActivity()
                            }
                        }
                    }
                    .listRowBackground(theme.background(.card))
                    
                    Section(header: Text("Statistics").foregroundColor(theme.text(.secondary))) {
                        HStack {
                            Text("Total Focus Time")
                                .foregroundColor(theme.text(.primary))
                            Spacer()
                            Text(AngleUtilities.formatFocusTime(viewModel.totalFocusMinutes))
                                .foregroundColor(theme.accentColor)
                        }
                        
                        HStack {
                            Text("Completed Pomodoros")
                                .foregroundColor(theme.text(.primary))
                            Spacer()
                            Text("\(viewModel.completedPomodoros)")
                                .foregroundColor(theme.accentColor)
                        }
                        
                        Button(action: {
                            viewModel.totalFocusMinutes = 0
                            viewModel.completedPomodoros = 0
                        }) {
                            Text("Reset Statistics")
                                .foregroundColor(theme.error)
                        }
                    }
                    .listRowBackground(theme.background(.card))
                }
                .scrollContentBackground(.hidden)
                .preferredColorScheme(.dark)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    SettingsView(viewModel: TimerViewModel())
}

