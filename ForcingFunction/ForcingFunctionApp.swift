//
//  ForcingFunctionApp.swift
//  ForcingFunction
//
//  Pomodoro Timer App - Main Entry Point
//
//  HOW TO RUN:
//  1. Open ForcingFunction.xcodeproj in Xcode
//  2. Select an iPhone simulator or device (iOS 16+ or 17+)
//  3. Build and run (Cmd+R)
//
//  PERMISSIONS REQUIRED:
//  - Notification permission (requested on first launch)
//    Used to notify when timer completes while app is backgrounded
//
//  CONFIGURATION:
//  - Minimum/Maximum minutes: Edit AppSettings.defaultMinMinutes and 
//    AppSettings.defaultMaxMinutes in Models.swift
//  - Default durations: Edit AppSettings defaults in Models.swift
//  - Theme colors: Modify ThemeColor enum in Models.swift
//  - Debug speed multiplier: Edit TimerViewModel.tick() method (currently 60x faster in DEBUG)
//
//  Created by Nilesh Kumar on 12/11/25.
//

import SwiftUI

@main
struct ForcingFunctionApp: App {
    init() {
        // Initialize widget data on app launch
        WidgetDataManager.shared.updateWidgetData()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Handle deep links from widget
                    // The MainTabView will handle the actual navigation
                }
        }
    }
}
