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
    private var repository: (any FocusRepository)?

    private init() {
        load()
    }

    // MARK: - Persistence

    func load() {
        if let repository {
            loadFromRepository(repository: repository)
            return
        }
        projects = []
    }

    // Phase 2: app code no longer reads/writes legacy JSON.

    // MARK: - Project CRUD

    func add(_ project: Project) {
        projects.append(project)
        persistUpsert(project)
    }

    func update(_ updated: Project) {
        guard let idx = projects.firstIndex(where: { $0.id == updated.id }) else { return }
        projects[idx] = updated
        persistUpsert(updated)
    }

    func delete(id: UUID) {
        projects.removeAll { $0.id == id }
        if let repository {
            do {
                try repository.deleteProject(id: id)
                loadFromRepository(repository: repository)
            } catch {
                print("ProjectStore: deleteProject repo error — \(error)")
            }
        }
    }

    func archive(id: UUID) {
        guard let idx = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[idx].isArchived = true
        persistUpsert(projects[idx])
    }

    func unarchive(id: UUID) {
        guard let idx = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[idx].isArchived = false
        persistUpsert(projects[idx])
    }

    func project(id: UUID) -> Project? {
        projects.first { $0.id == id }
    }

    // MARK: - Tag CRUD (mutates a project's tags array)

    func addTag(_ tag: ProjectTag, to projectId: UUID) {
        guard let idx = projects.firstIndex(where: { $0.id == projectId }) else { return }
        projects[idx].tags.append(tag)
        persistUpsert(projects[idx])
    }

    func updateTag(_ updated: ProjectTag, in projectId: UUID) {
        guard let pIdx = projects.firstIndex(where: { $0.id == projectId }),
              let tIdx = projects[pIdx].tags.firstIndex(where: { $0.id == updated.id }) else { return }
        projects[pIdx].tags[tIdx] = updated
        persistUpsert(projects[pIdx])
    }

    /// Deletes a tag and all its children from a project.
    func deleteTag(id tagId: UUID, from projectId: UUID) {
        guard let pIdx = projects.firstIndex(where: { $0.id == projectId }) else { return }
        // Remove children first, then the tag itself
        projects[pIdx].tags.removeAll { $0.parentId == tagId || $0.id == tagId }
        persistUpsert(projects[pIdx])
    }

    // MARK: - Stats

    /// Total active focus minutes deposited into a project across a session array.
    func totalFocusMinutes(for projectId: UUID, in sessions: [PomodoroSession]) -> Double {
        sessions
            .filter { $0.projectId == projectId && $0.sessionType == .work }
            .map(\.billedMinutes)
            .reduce(0, +)
    }

    /// Total active focus minutes deposited into a specific project tag.
    func totalFocusMinutes(forTag tagId: UUID, in sessions: [PomodoroSession]) -> Double {
        sessions
            .filter { $0.projectTagId == tagId && $0.sessionType == .work }
            .map(\.billedMinutes)
            .reduce(0, +)
    }

    // MARK: - Convenience

    var activeProjects: [Project] {
        projects.filter { !$0.isArchived }
    }

    // MARK: - SwiftData-backed configuration

    static func configureShared(repository: any FocusRepository) {
        shared.repository = repository
        shared.load()
    }

    private func loadFromRepository(repository: any FocusRepository) {
        do {
            let sdProjects = try repository.fetchProjects(includeArchived: true)
            projects = sdProjects.map { p in
                let tags: [ProjectTag] = p.tags.map { t in
                    ProjectTag(id: t.id, name: t.name, parentId: t.parent?.id, createdDate: t.createdDate)
                }
                return Project(
                    id: p.id,
                    name: p.name,
                    color: CategoryColor(rawValue: p.colorRaw) ?? .teal,
                    goalHours: p.goalHours,
                    tags: tags,
                    createdDate: p.createdDate,
                    isArchived: p.isArchived
                )
            }.sorted { $0.createdDate < $1.createdDate }
        } catch {
            print("ProjectStore: loadFromRepository error — \(error)")
            projects = []
        }
    }

    private func persistUpsert(_ project: Project) {
        if let repository {
            do {
                try repository.upsertProject(
                    id: project.id,
                    name: project.name,
                    colorRaw: project.color.rawValue,
                    goalHours: project.goalHours,
                    createdDate: project.createdDate,
                    isArchived: project.isArchived
                )
                for tag in project.tags {
                    try repository.upsertTag(
                        id: tag.id,
                        name: tag.name,
                        createdDate: tag.createdDate,
                        projectId: project.id,
                        parentId: tag.parentId
                    )
                }
                loadFromRepository(repository: repository)
            } catch {
                print("ProjectStore: persistUpsert repo error — \(error)")
            }
        }
    }
}
