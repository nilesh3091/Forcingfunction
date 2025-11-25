//
//  ContentView.swift
//  ForcingFunction
//
//  Main content view container
//

import SwiftUI
import UIKit

struct ContentView: View {
    var body: some View {
        MainTabView()
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // Refresh widget whenever app becomes active/opens
                WidgetDataManager.shared.updateWidgetData()
            }
    }
}

#Preview {
    ContentView()
}
