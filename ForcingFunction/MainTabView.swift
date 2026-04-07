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
    
    private var theme: AppTheme {
        viewModel.theme
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab content without `TabView` + `.page` — that style uses a `UIScrollView` whose
            // default `delaysContentTouches` behavior makes buttons (e.g. Start) need extra taps.
            Group {
                switch selectedTab {
                case 0:
                    TimerView(viewModel: viewModel)
                case 1:
                    CalendarView(viewModel: viewModel)
                case 2:
                    StatsView(viewModel: viewModel)
                case 3:
                    ProfileView(viewModel: viewModel)
                default:
                    TimerView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom bottom tab bar
            HStack {
                TabBarButton(
                    title: "Timer",
                    systemImage: "clock.fill",
                    index: 0,
                    selectedTab: $selectedTab,
                    theme: theme
                )
                
                TabBarButton(
                    title: "History",
                    systemImage: "clock.arrow.circlepath",
                    index: 1,
                    selectedTab: $selectedTab,
                    theme: theme
                )
                
                TabBarButton(
                    title: "Stats",
                    systemImage: "chart.bar.fill",
                    index: 2,
                    selectedTab: $selectedTab,
                    theme: theme
                )

                TabBarButton(
                    title: "Settings",
                    systemImage: "gearshape.fill",
                    index: 3,
                    selectedTab: $selectedTab,
                    theme: theme
                )
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                theme.background(.secondary)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(theme.borderPrimary.opacity(0.55))
                            .frame(height: 0.5)
                    }
            )
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
    let theme: AppTheme
    
    var body: some View {
        Button {
            withAnimation(.easeInOut) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .foregroundColor(selectedTab == index ? theme.accentColor : theme.text(.secondary))
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedTab == index ? theme.accent(opacity: 0.15) : .clear)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView()
}

