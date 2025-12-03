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
        VStack(spacing: 0) {
            // Swipeable pages
            TabView(selection: $selectedTab) {
                // Timer Tab
                TimerView(viewModel: viewModel)
                    .tag(0)
                
                // History Tab
                CalendarView(viewModel: viewModel)
                    .tag(1)
                
                // Stats Tab
                StatsView(viewModel: viewModel)
                    .tag(2)
                
                // Tasks Tab
                MoreView(viewModel: viewModel, selectedTab: $selectedTab)
                    .tag(3)
                
                // Settings Tab
                ProfileView(viewModel: viewModel)
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // Custom bottom tab bar
            HStack {
                TabBarButton(
                    title: "Timer",
                    systemImage: "clock.fill",
                    index: 0,
                    selectedTab: $selectedTab,
                    accentColor: viewModel.accentColor
                )
                
                TabBarButton(
                    title: "History",
                    systemImage: "clock.arrow.circlepath",
                    index: 1,
                    selectedTab: $selectedTab,
                    accentColor: viewModel.accentColor
                )
                
                TabBarButton(
                    title: "Stats",
                    systemImage: "chart.bar.fill",
                    index: 2,
                    selectedTab: $selectedTab,
                    accentColor: viewModel.accentColor
                )
                
                TabBarButton(
                    title: "Tasks",
                    systemImage: "checklist",
                    index: 3,
                    selectedTab: $selectedTab,
                    accentColor: viewModel.accentColor
                )
                
                TabBarButton(
                    title: "Settings",
                    systemImage: "gearshape.fill",
                    index: 4,
                    selectedTab: $selectedTab,
                    accentColor: viewModel.accentColor
                )
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(Color(.systemBackground).opacity(0.95))
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

private struct TabBarButton: View {
    let title: String
    let systemImage: String
    let index: Int
    @Binding var selectedTab: Int
    let accentColor: Color
    
    var body: some View {
        Button {
            withAnimation(.easeInOut) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .foregroundColor(selectedTab == index ? accentColor : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedTab == index ? accentColor.opacity(0.15) : .clear)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView()
}

