import SwiftUI

/// Full-screen manager for creating, editing, and archiving Projects and their tags.
struct ProjectManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = ProjectStore.shared

    @State private var showAddProject = false
    @State private var editingProject: Project? = nil
    @State private var showArchived = false

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(HC.mono(10, weight: .medium))
            .tracking(1.2)
            .foregroundStyle(HC.muted)
    }

    var body: some View {
        NavigationView {
            ZStack {
                HC.bg.ignoresSafeArea()

                List {
                    if store.activeProjects.isEmpty && !showArchived {
                        emptyState
                    } else {
                        activeSection
                        if !store.projects.filter(\.isArchived).isEmpty {
                            archivedToggleSection
                            if showArchived { archivedSection }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Projects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(HC.text(16, weight: .semibold))
                        .foregroundStyle(HC.red)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showAddProject = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(HC.red)
                    }
                }
            }
            .sheet(isPresented: $showAddProject) {
                ProjectEditView(project: nil)
            }
            .sheet(item: $editingProject) { project in
                ProjectEditView(project: project)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var emptyState: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 36))
                    .foregroundStyle(HC.muted)
                Text("No projects yet")
                    .font(HC.text(15, weight: .medium))
                    .foregroundStyle(HC.ink)
                Text("Create a project to start tracking hours toward mastery.")
                    .font(HC.text(13))
                    .foregroundStyle(HC.muted)
                    .multilineTextAlignment(.center)
                Button {
                    showAddProject = true
                } label: {
                    Text("New Project")
                        .font(HC.text(14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 9)
                        .background(HC.red, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
        .listRowBackground(HC.card)
    }

    private var activeSection: some View {
        Section(header: sectionHeader("Active")) {
            ForEach(store.activeProjects) { project in
                ProjectRow(project: project) {
                    editingProject = project
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        store.delete(id: project.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        store.archive(id: project.id)
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                    .tint(.orange)
                }
            }

            Button {
                showAddProject = true
            } label: {
                Label("New Project", systemImage: "plus")
                    .font(HC.text(15))
                    .foregroundStyle(HC.red)
            }
        }
        .listRowBackground(HC.card)
        .listRowSeparatorTint(HC.line)
    }

    private var archivedToggleSection: some View {
        Section {
            Button {
                withAnimation { showArchived.toggle() }
            } label: {
                HStack {
                    Text(showArchived ? "Hide Archived" : "Show Archived")
                        .font(HC.text(14))
                        .foregroundStyle(HC.muted)
                    Spacer()
                    Image(systemName: showArchived ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(HC.muted)
                }
            }
        }
        .listRowBackground(HC.card)
        .listRowSeparatorTint(HC.line)
    }

    private var archivedSection: some View {
        Section(header: sectionHeader("Archived")) {
            ForEach(store.projects.filter(\.isArchived)) { project in
                ProjectRow(project: project, dimmed: true) {
                    editingProject = project
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        store.delete(id: project.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        store.unarchive(id: project.id)
                    } label: {
                        Label("Restore", systemImage: "arrow.uturn.left")
                    }
                    .tint(.blue)
                }
            }
        }
        .listRowBackground(HC.card)
        .listRowSeparatorTint(HC.line)
    }
}

// MARK: - Project Row

private struct ProjectRow: View {
    let project: Project
    var dimmed: Bool = false
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                Circle()
                    .fill(project.color.color.opacity(dimmed ? 0.4 : 1))
                    .frame(width: 12, height: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(HC.text(15, weight: .medium))
                        .foregroundStyle(dimmed ? HC.muted : HC.ink)
                    Text("\(project.tags.count) tag\(project.tags.count == 1 ? "" : "s")")
                        .font(HC.mono(11))
                        .foregroundStyle(HC.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(HC.muted)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Project Edit / Create View

struct ProjectEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = ProjectStore.shared

    /// nil = creating new project; non-nil = editing existing
    let project: Project?

    @State private var name: String
    @State private var color: CategoryColor
    @State private var goalHours: Double

    @State private var expandedTagIds: Set<UUID> = []
    @State private var editingTagId: UUID? = nil
    @State private var editingTagName: String = ""
    @State private var addingTagUnder: UUID? = nil   // project UUID sentinel for top-level
    @State private var inlineNewTagName: String = ""

    init(project: Project?) {
        self.project = project
        _name = State(initialValue: project?.name ?? "")
        _color = State(initialValue: project?.color ?? .blue)
        _goalHours = State(initialValue: project?.goalHours ?? 10_000)
    }

    private var isCreating: Bool { project == nil }

    private var currentProject: Project? {
        guard let id = project?.id else { return nil }
        return store.project(id: id)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(HC.mono(10, weight: .medium))
            .tracking(1.2)
            .foregroundStyle(HC.muted)
    }

    var body: some View {
        NavigationView {
            ZStack {
                HC.bg.ignoresSafeArea()

                Form {
                    detailsSection
                    if !isCreating { tagsSection }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(isCreating ? "New Project" : "Edit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCreating ? "Create" : "Save") {
                        saveAndDismiss()
                    }
                    .font(HC.text(16, weight: .semibold))
                    .foregroundStyle(HC.red)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(HC.text(16))
                        .foregroundStyle(HC.muted)
                }
            }
        }
    }

    // MARK: - Sections

    private var detailsSection: some View {
        Section(header: sectionHeader("Project")) {
            HStack {
                Circle()
                    .fill(color.color)
                    .frame(width: 14, height: 14)
                TextField("Project name", text: $name)
                    .font(HC.text(16))
                    .foregroundStyle(HC.ink)
            }

            HStack {
                Text("Color")
                    .font(HC.text(15))
                    .foregroundStyle(HC.ink)
                Spacer()
                Picker("", selection: $color) {
                    ForEach(CategoryColor.allCases, id: \.self) { c in
                        HStack {
                            Circle().fill(c.color).frame(width: 10, height: 10)
                            Text(c.rawValue)
                        }
                        .tag(c)
                    }
                }
                .pickerStyle(.menu)
                .foregroundStyle(HC.red)
            }

            HStack {
                Text("Goal")
                    .font(HC.text(15))
                    .foregroundStyle(HC.ink)
                Spacer()
                TextField("Hours", value: $goalHours, format: .number)
                    .font(HC.text(15))
                    .foregroundStyle(HC.ink)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .frame(width: 80)
                Text("hours")
                    .font(HC.text(14))
                    .foregroundStyle(HC.muted)
            }
        }
        .listRowBackground(HC.card)
        .listRowSeparatorTint(HC.line)
    }

    @ViewBuilder
    private var tagsSection: some View {
        if let proj = currentProject {
            Section(header: sectionHeader("Tags")) {
                ForEach(proj.topLevelTags) { parentTag in
                    editableTagRow(parentTag, project: proj)
                }

                // Add top-level tag
                if addingTagUnder == proj.id {
                    inlineAddRow(parentId: nil, projectId: proj.id)
                } else {
                    Button {
                        addingTagUnder = proj.id
                        inlineNewTagName = ""
                    } label: {
                        Label("Add tag", systemImage: "plus")
                            .font(HC.text(14))
                            .foregroundStyle(HC.muted)
                    }
                }
            }
            .listRowBackground(HC.card)
            .listRowSeparatorTint(HC.line)
        }
    }

    @ViewBuilder
    private func editableTagRow(_ tag: ProjectTag, project: Project) -> some View {
        let children = project.subTags(of: tag.id)
        let isExpanded = expandedTagIds.contains(tag.id)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if editingTagId == tag.id {
                    TextField("Tag name", text: $editingTagName)
                        .font(HC.text(15))
                        .foregroundStyle(HC.ink)
                        .submitLabel(.done)
                        .onSubmit { commitTagRename(tag: tag, projectId: project.id) }
                    Button {
                        commitTagRename(tag: tag, projectId: project.id)
                    } label: {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(HC.red)
                    }.buttonStyle(.plain)
                    Button {
                        editingTagId = nil
                    } label: {
                        Image(systemName: "xmark.circle").foregroundStyle(HC.muted)
                    }.buttonStyle(.plain)
                } else {
                    Text(tag.name)
                        .font(HC.text(15))
                        .foregroundStyle(HC.ink)
                    Spacer()
                    // Expand
                    if !children.isEmpty || addingTagUnder == tag.id {
                        Button {
                            if isExpanded { expandedTagIds.remove(tag.id) }
                            else { expandedTagIds.insert(tag.id) }
                        } label: {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12))
                                .foregroundStyle(HC.muted)
                        }.buttonStyle(.plain)
                    }
                    // Add child
                    Button {
                        expandedTagIds.insert(tag.id)
                        addingTagUnder = tag.id
                        inlineNewTagName = ""
                    } label: {
                        Image(systemName: "plus").font(.system(size: 12)).foregroundStyle(HC.muted)
                    }.buttonStyle(.plain)
                    // Edit
                    Button {
                        editingTagId = tag.id
                        editingTagName = tag.name
                    } label: {
                        Image(systemName: "pencil").font(.system(size: 12)).foregroundStyle(HC.muted)
                    }.buttonStyle(.plain)
                    // Delete
                    Button(role: .destructive) {
                        store.deleteTag(id: tag.id, from: project.id)
                    } label: {
                        Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(HC.muted)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.vertical, 5)

            if isExpanded || addingTagUnder == tag.id {
                ForEach(children) { child in
                    editableSubTagRow(child, parentTag: tag, project: project)
                }
                if addingTagUnder == tag.id {
                    inlineAddRow(parentId: tag.id, projectId: project.id)
                        .padding(.leading, 24)
                }
            }
        }
    }

    @ViewBuilder
    private func editableSubTagRow(_ tag: ProjectTag, parentTag: ProjectTag, project: Project) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 11))
                .foregroundStyle(HC.muted)
                .padding(.leading, 16)

            if editingTagId == tag.id {
                TextField("Tag name", text: $editingTagName)
                    .font(HC.text(14))
                    .submitLabel(.done)
                    .onSubmit { commitTagRename(tag: tag, projectId: project.id) }
                Button {
                    commitTagRename(tag: tag, projectId: project.id)
                } label: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(HC.red)
                }.buttonStyle(.plain)
                Button {
                    editingTagId = nil
                } label: {
                    Image(systemName: "xmark.circle").foregroundStyle(HC.muted)
                }.buttonStyle(.plain)
            } else {
                Text(tag.name)
                    .font(HC.text(14))
                    .foregroundStyle(HC.ink)
                Spacer()
                Button {
                    editingTagId = tag.id
                    editingTagName = tag.name
                } label: {
                    Image(systemName: "pencil").font(.system(size: 11)).foregroundStyle(HC.muted)
                }.buttonStyle(.plain)
                Button(role: .destructive) {
                    store.deleteTag(id: tag.id, from: project.id)
                } label: {
                    Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(HC.muted)
                }.buttonStyle(.plain)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func inlineAddRow(parentId: UUID?, projectId: UUID) -> some View {
        HStack(spacing: 8) {
            if parentId != nil {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 11)).foregroundStyle(HC.muted)
                    .padding(.leading, 16)
            }
            TextField("Tag name", text: $inlineNewTagName)
                .font(HC.text(14))
                .foregroundStyle(HC.ink)
                .submitLabel(.done)
                .onSubmit { commitNewTag(parentId: parentId, projectId: projectId) }
                .autocorrectionDisabled()
            Button {
                commitNewTag(parentId: parentId, projectId: projectId)
            } label: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(HC.red)
            }.buttonStyle(.plain)
            Button {
                addingTagUnder = nil; inlineNewTagName = ""
            } label: {
                Image(systemName: "xmark.circle").foregroundStyle(HC.muted)
            }.buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func saveAndDismiss() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let existing = project {
            var updated = existing
            updated.name = trimmed
            updated.color = color
            updated.goalHours = goalHours
            store.update(updated)
        } else {
            let newProject = Project(name: trimmed, color: color, goalHours: goalHours)
            store.add(newProject)
        }
        dismiss()
    }

    private func commitTagRename(tag: ProjectTag, projectId: UUID) {
        let trimmed = editingTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            var updated = tag
            updated.name = trimmed
            store.updateTag(updated, in: projectId)
        }
        editingTagId = nil
    }

    private func commitNewTag(parentId: UUID?, projectId: UUID) {
        let trimmed = inlineNewTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { addingTagUnder = nil; return }
        let tag = ProjectTag(name: trimmed, parentId: parentId)
        store.addTag(tag, to: projectId)
        inlineNewTagName = ""
        addingTagUnder = nil
    }
}

#Preview {
    ProjectManagerView()
}
