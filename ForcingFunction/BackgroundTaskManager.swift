//
//  BackgroundTaskManager.swift
//  ForcingFunction
//
//  Manages background tasks to keep Live Activity updates running
//

import Foundation
import UIKit

class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var updateTimer: Timer?
    private var isRunning = false
    
    private init() {}
    
    /// Start background task for Live Activity updates
    func startBackgroundUpdates(updateHandler: @escaping () -> Void) {
        guard !isRunning else { return }
        
        isRunning = true
        
        // Start background task
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        
        // Schedule periodic updates every 5 seconds
        // Must run on main thread for UI updates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
                guard let self = self, self.isRunning else {
                    timer.invalidate()
                    return
                }
                updateHandler()
                
                // Extend background task if needed
                if self.backgroundTaskID == .invalid {
                    // Task expired, start a new one
                    self.backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
                        self?.endBackgroundTask()
                    }
                }
            }
        }
        
        // Run initial update
        updateHandler()
    }
    
    /// Stop background updates
    func stopBackgroundUpdates() {
        isRunning = false
        updateTimer?.invalidate()
        updateTimer = nil
        endBackgroundTask()
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
}

