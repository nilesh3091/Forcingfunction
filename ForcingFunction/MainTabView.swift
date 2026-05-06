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

            HCTabBar(selectedTab: $selectedTab)
        }
        .background(HC.bg.ignoresSafeArea())
        .accentColor(HC.red)
        .preferredColorScheme(.light)
        .onOpenURL { url in
            // Handle widget tap - open Stats tab
            if url.scheme == "forcingfunction" && url.host == "stats" {
                selectedTab = 2 // Stats tab
            }
        }
    }
}

// MARK: - Hour Cards tab bar

private struct HCTabBar: View {
    @Binding var selectedTab: Int

    private static let items: [(glyph: String, label: String)] = [
        ("●", "Focus"),
        ("◍", "Log"),
        ("◐", "Shape"),
        ("◇", "Tune"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(Self.items.enumerated()), id: \.offset) { index, item in
                HCTabButton(
                    glyph: item.glyph,
                    label: item.label,
                    isActive: selectedTab == index
                ) {
                    selectedTab = index
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 22)
        .background(
            HC.bg
                .overlay(alignment: .top) {
                    Rectangle().fill(HC.line).frame(height: 1)
                }
        )
    }
}

private struct HCTabButton: View {
    let glyph: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(glyph)
                    .font(HC.text(18, weight: .bold))
                    .foregroundStyle(isActive ? HC.red : HC.muted)
                Text(label)
                    .font(HC.text(11, weight: isActive ? .bold : .medium))
                    .foregroundStyle(isActive ? HC.ink : HC.muted)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView()
}

