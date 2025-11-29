//
//  MainTabView.swift
//  ForcingFunction
//
//  Main tab bar navigation container
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var viewModel = TimerViewModel()
    @State private var selectedTab = 0
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Timer Tab
            TimerView(viewModel: viewModel)
                .tabItem {
                    Label("Timer", systemImage: "clock.fill")
                }
                .tag(0)
            
            // History Tab
            CalendarView(viewModel: viewModel)
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(1)
            
            // Stats Tab
            StatsView(viewModel: viewModel)
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
                .tag(2)
            
            // Tasks Tab
            MoreView(viewModel: viewModel)
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
                .tag(3)
            
            // Settings Tab
            ProfileView(viewModel: viewModel)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .preferredColorScheme(.dark)
        .accentColor(viewModel.accentColor)
        .onOpenURL { url in
            // Handle widget tap - open Stats tab
            if url.scheme == "forcingfunction" && url.host == "stats" {
                selectedTab = 2 // Stats tab
            }
        }
    }
}

#Preview {
    MainTabView()
}

