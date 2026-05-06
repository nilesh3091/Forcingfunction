//
//  ProjectStore.swift
//  ForcingFunction
//
//  Persistence and CRUD for mastery Projects.
//

import Foundation
import Combine

class ProjectStore: ObservableObject {
    static let shared = ProjectStore()

    @Published private(set) var projects: [Project] = []

    private let fileName = "projects.json"

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    private init() {
        load()
    }

    // MARK: - Persistence

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            projects = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            projects = try decoder.decode([Project].self, from: data)
                .sorted { $0.createdDate < $1.createdDate }
        } catch {
            print("ProjectStore: load error — \(error)")
            projects = []
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(projects)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("ProjectStore: save error — \(error)")
        }
    }

    // MARK: - Project CRUD

    func add(_ project: Project) {
        projects.append(project)
        save()
    }

    func update(_ updated: Project) {
        guard let idx = projects.firstIndex(where: { $0.id == updated.id }) else { return }
        projects[idx] = updated
        save()
    }

    func delete(id: UUID) {
        projects.removeAll { $0.id == id }
        save()
    }

    func archive(id: UUID) {
        guard let idx = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[idx].isArchived = true
        save()
    }

    func unarchive(id: UUID) {
        guard let idx = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[idx].isArchived = false
        save()
    }

    func project(id: UUID) -> Project? {
        projects.first { $0.id == id }
    }

    // MARK: - Tag CRUD (mutates a project's tags array)

    func addTag(_ tag: ProjectTag, to projectId: UUID) {
        guard let idx = projects.firstIndex(where: { $0.id == projectId }) else { return }
        projects[idx].tags.append(tag)
        save()
    }

    func updateTag(_ updated: ProjectTag, in projectId: UUID) {
        guard let pIdx = projects.firstIndex(where: { $0.id == projectId }),
              let tIdx = projects[pIdx].tags.firstIndex(where: { $0.id == updated.id }) else { return }
        projects[pIdx].tags[tIdx] = updated
        save()
    }

    /// Deletes a tag and all its children from a project.
    func deleteTag(id tagId: UUID, from projectId: UUID) {
        guard let pIdx = projects.firstIndex(where: { $0.id == projectId }) else { return }
        // Remove children first, then the tag itself
        projects[pIdx].tags.removeAll { $0.parentId == tagId || $0.id == tagId }
        save()
    }

    // MARK: - Stats

    /// Total active focus minutes deposited into a project across a session array.
    func totalFocusMinutes(for projectId: UUID, in sessions: [PomodoroSession]) -> Double {
        sessions
            .filter { $0.projectId == projectId && $0.sessionType == .work }
            .compactMap { $0.activeDurationMinutes }
            .reduce(0, +)
    }

    /// Total active focus minutes deposited into a specific project tag.
    func totalFocusMinutes(forTag tagId: UUID, in sessions: [PomodoroSession]) -> Double {
        sessions
            .filter { $0.projectTagId == tagId && $0.sessionType == .work }
            .compactMap { $0.activeDurationMinutes }
            .reduce(0, +)
    }

    // MARK: - Convenience

    var activeProjects: [Project] {
        projects.filter { !$0.isArchived }
    }
}
