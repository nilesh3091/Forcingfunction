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
//  - Theme colors: Fixed palette in `AppTheme.standard` (Models.swift)
//  - Debug speed multiplier: Edit TimerViewModel.tick() method (currently 60x faster in DEBUG)
//
//  Created by Nilesh Kumar on 12/11/25.
//

import SwiftUI
import UIKit
import UserNotifications
import SwiftData

@main
struct ForcingFunctionApp: App {
    private let modelContainer: ModelContainer
    private let focusRepository: any FocusRepository

    init() {
        do {
            modelContainer = try ModelContainer(
                for: SDProject.self,
                SDProjectTag.self,
                SDFocusSession.self,
                SDSessionEventRecord.self
            )
        } catch {
            fatalError("SwiftData ModelContainer init failed: \(error)")
        }

        focusRepository = SwiftDataFocusRepository(container: modelContainer)

        LegacyJSONToSwiftDataMigrator(container: modelContainer, repository: focusRepository).migrateIfNeeded()

        PomodoroDataStore.configureShared(repository: focusRepository)
        ProjectStore.configureShared(repository: focusRepository)

        // Initialize widget data on app launch
        WidgetDataManager.shared.updateWidgetData()
        
        // Set up notification delegate to handle timer completion in background
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environment(\.focusRepository, focusRepository)
                .onOpenURL { url in
                    // Handle deep links from widget
                    // The MainTabView will handle the actual navigation
                }
        }
    }
}

private struct LegacyJSONToSwiftDataMigrator {
    private let container: ModelContainer
    private let repository: any FocusRepository

    private let markerKey = "hasMigratedLegacyJSONToSwiftData_v1"

    init(container: ModelContainer, repository: any FocusRepository) {
        self.container = container
        self.repository = repository
    }

    func migrateIfNeeded() {
        if UserDefaults.standard.bool(forKey: markerKey) {
            return
        }

        // If the store already has data (e.g., after reinstall/restore), don't re-import.
        do {
            let ctx = ModelContext(container)
            let anySessions = try ctx.fetchCount(FetchDescriptor<SDFocusSession>()) > 0
            let anyProjects = try ctx.fetchCount(FetchDescriptor<SDProject>()) > 0
            if anySessions || anyProjects {
                UserDefaults.standard.set(true, forKey: markerKey)
                return
            }
        } catch {
            // If this fails, fall through to attempt import; worst-case it no-ops if files are missing.
        }

        do {
            let legacyProjects = try readLegacyProjects()
            try importLegacyProjects(legacyProjects)

            let legacySessions = try readLegacySessions()
            try importLegacySessions(legacySessions)

            UserDefaults.standard.set(true, forKey: markerKey)
        } catch {
            // Keep running; migration is best-effort and must never prevent launch.
            print("LegacyJSONToSwiftDataMigrator: migration failed — \(error)")
        }
    }

    private func readLegacyProjects() throws -> [Project] {
        let url = legacyDocumentsURL(fileName: "projects.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try readFileData(url: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Project].self, from: data)
    }

    private func readLegacySessions() throws -> [PomodoroSession] {
        let url = legacyDocumentsURL(fileName: "pomodoro_sessions.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try readFileData(url: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([PomodoroSession].self, from: data)
    }

    private func importLegacyProjects(_ projects: [Project]) throws {
        for p in projects {
            try repository.upsertProject(
                id: p.id,
                name: p.name,
                colorRaw: p.color.rawValue,
                goalHours: p.goalHours,
                createdDate: p.createdDate,
                isArchived: p.isArchived
            )
        }

        // Two-pass tag import so parent references resolve.
        // 1) Insert all tags with project linkage and no parent.
        for p in projects {
            for t in p.tags {
                try repository.upsertTag(
                    id: t.id,
                    name: t.name,
                    createdDate: t.createdDate,
                    projectId: p.id,
                    parentId: nil
                )
            }
        }
        // 2) Update parent linkage.
        for p in projects {
            for t in p.tags where t.parentId != nil {
                try repository.upsertTag(
                    id: t.id,
                    name: t.name,
                    createdDate: t.createdDate,
                    projectId: p.id,
                    parentId: t.parentId
                )
            }
        }
    }

    private func importLegacySessions(_ sessions: [PomodoroSession]) throws {
        for s in sessions {
            try repository.upsertSession(
                id: s.id,
                startTime: s.startTime,
                endTime: s.endTime,
                plannedMinutes: s.plannedDurationMinutes,
                statusRaw: s.status.rawValue,
                kindRaw: s.sessionType.rawValue,
                title: s.title,
                projectId: s.projectId,
                tagId: s.projectTagId,
                events: s.events
            )
        }
    }

    private func legacyDocumentsURL(fileName: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    private func readFileData(url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        return try handle.readToEnd() ?? Data()
    }
}
