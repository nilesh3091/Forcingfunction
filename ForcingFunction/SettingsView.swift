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
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                Form {
                    Section(header: Text("Session Durations").foregroundColor(.white.opacity(0.7))) {
                        // Pomodoro length
                        HStack {
                            Text("Pomodoro Length")
                                .foregroundColor(.white)
                            Spacer()
                            Picker("", selection: $viewModel.pomodoroMinutes) {
                                ForEach(pomodoroMinutesOptions, id: \.self) { minutes in
                                    Text("\(Int(minutes)) min").tag(minutes)
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(viewModel.accentColor)
                            .onChange(of: viewModel.pomodoroMinutes) {
                                viewModel.updateSettings()
                            }
                        }
                        
                        // Short break length
                        HStack {
                            Text("Short Break")
                                .foregroundColor(.white)
                            Spacer()
                            Picker("", selection: $viewModel.shortBreakMinutes) {
                                ForEach(1...30, id: \.self) { minutes in
                                    Text("\(minutes) min").tag(Double(minutes))
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(viewModel.accentColor)
                            .onChange(of: viewModel.shortBreakMinutes) {
                                viewModel.updateSettings()
                            }
                        }
                        
                        // Long break length
                        HStack {
                            Text("Long Break")
                                .foregroundColor(.white)
                            Spacer()
                            Picker("", selection: $viewModel.longBreakMinutes) {
                                ForEach(5...60, id: \.self) { minutes in
                                    Text("\(minutes) min").tag(Double(minutes))
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(viewModel.accentColor)
                            .onChange(of: viewModel.longBreakMinutes) {
                                viewModel.updateSettings()
                            }
                        }
                    }
                    .listRowBackground(Color.gray.opacity(0.1))
                    
                    Section(header: Text("Pomodoro Cycle").foregroundColor(.white.opacity(0.7))) {
                        // Pomodoros before long break
                        HStack {
                            Text("Pomodoros Before Long Break")
                                .foregroundColor(.white)
                            Spacer()
                            Picker("", selection: $viewModel.pomodorosBeforeLongBreak) {
                                ForEach(1...10, id: \.self) { count in
                                    Text("\(count)").tag(count)
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(viewModel.accentColor)
                        }
                    }
                    .listRowBackground(Color.gray.opacity(0.1))
                    
                    Section(header: Text("Dial Settings").foregroundColor(.white.opacity(0.7))) {
                        // Snap increment
                        HStack {
                            Text("Snap Increment")
                                .foregroundColor(.white)
                            Spacer()
                            Picker("", selection: $viewModel.snapIncrement) {
                                Text("1 minute").tag(1.0)
                                Text("5 minutes").tag(5.0)
                                Text("15 minutes").tag(15.0)
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(viewModel.accentColor)
                        }
                    }
                    .listRowBackground(Color.gray.opacity(0.1))
                    
                    Section(header: Text("Behavior").foregroundColor(.white.opacity(0.7))) {
                        // Auto-start next session
                        Toggle(isOn: $viewModel.autoStartNext) {
                            Text("Auto-start Next Session")
                                .foregroundColor(.white)
                        }
                        .tint(viewModel.accentColor)
                        
                        // Play sound on completion
                        Toggle(isOn: $viewModel.playSoundOnCompletion) {
                            Text("Play Sound on Completion")
                                .foregroundColor(.white)
                        }
                        .tint(viewModel.accentColor)
                        
                        // Haptics
                        Toggle(isOn: $viewModel.hapticsEnabled) {
                            Text("Haptic Feedback")
                                .foregroundColor(.white)
                        }
                        .tint(viewModel.accentColor)
                        
                        // Live Activities
                        Toggle(isOn: $viewModel.liveActivitiesEnabled) {
                            Text("Live Activities")
                                .foregroundColor(.white)
                        }
                        .tint(viewModel.accentColor)
                        .onChange(of: viewModel.liveActivitiesEnabled) { enabled in
                            if !enabled {
                                // End any active Live Activity when disabled
                                LiveActivityManager.shared.endActivity()
                            }
                        }
                    }
                    .listRowBackground(Color.gray.opacity(0.1))
                    
                    Section(header: Text("Appearance").foregroundColor(.white.opacity(0.7))) {
                        // Theme color
                        HStack {
                            Text("Theme Color")
                                .foregroundColor(.white)
                            Spacer()
                            Picker("", selection: $viewModel.themeColorString) {
                                ForEach(ThemeColor.allCases, id: \.self) { color in
                                    HStack {
                                        Circle()
                                            .fill(color == .red ? Color.red : (color == .blue ? Color.blue : Color.green))
                                            .frame(width: 16, height: 16)
                                        Text(color.rawValue)
                                    }
                                    .tag(color.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(viewModel.accentColor)
                        }
                    }
                    .listRowBackground(Color.gray.opacity(0.1))
                    
                    Section(header: Text("Statistics").foregroundColor(.white.opacity(0.7))) {
                        HStack {
                            Text("Total Focus Time")
                                .foregroundColor(.white)
                            Spacer()
                            Text(AngleUtilities.formatFocusTime(viewModel.totalFocusMinutes))
                                .foregroundColor(viewModel.accentColor)
                        }
                        
                        HStack {
                            Text("Completed Pomodoros")
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(viewModel.completedPomodoros)")
                                .foregroundColor(viewModel.accentColor)
                        }
                        
                        Button(action: {
                            viewModel.totalFocusMinutes = 0
                            viewModel.completedPomodoros = 0
                        }) {
                            Text("Reset Statistics")
                                .foregroundColor(.red)
                        }
                    }
                    .listRowBackground(Color.gray.opacity(0.1))
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

