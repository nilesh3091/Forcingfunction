import SwiftUI

struct PomodoroSetupSheet: View {
    @ObservedObject var viewModel: TimerViewModel
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var projectStore = ProjectStore.shared

    /// Transient UI state
    @State private var showProjectManager = false
    @State private var newTagParentId: UUID? = nil          // parent under which inline tag is added
    @State private var expandedTagIds: Set<UUID> = []       // expanded parent tags
    @State private var inlineNewTagName: String = ""         // text in inline tag field
    @State private var addingTagUnder: UUID? = nil           // currently open inline-add row

    // MARK: - Derived state

    private var selectedProject: Project? {
        guard let id = UUID(uuidString: viewModel.setupProjectId) else { return nil }
        return projectStore.project(id: id)
    }

    private var selectedTagId: UUID? {
        UUID(uuidString: viewModel.setupTagId)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(HC.mono(10, weight: .medium))
            .tracking(1.2)
            .foregroundStyle(HC.muted)
    }

    private func selectProject(_ project: Project) {
        viewModel.setupProjectId = project.id.uuidString
        viewModel.setupTagId = ""
        expandedTagIds = []
        addingTagUnder = nil
    }

    private func clearProject() {
        viewModel.setupProjectId = ""
        viewModel.setupTagId = ""
        expandedTagIds = []
        addingTagUnder = nil
    }

    private func commitInlineTag(parentId: UUID?, projectId: UUID) {
        let name = inlineNewTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { addingTagUnder = nil; return }
        let tag = ProjectTag(name: name, parentId: parentId)
        projectStore.addTag(tag, to: projectId)
        inlineNewTagName = ""
        addingTagUnder = nil
        // Auto-select the newly created tag
        viewModel.setupTagId = tag.id.uuidString
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                HC.bg.ignoresSafeArea()

                Form {
                    sessionNameSection
                    projectSection
                    if selectedProject != nil {
                        tagSection
                    }
                    clearSection
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(HC.text(16, weight: .semibold))
                        .foregroundStyle(HC.red)
                }
            }
            .sheet(isPresented: $showProjectManager) {
                ProjectManagerView()
            }
        }
    }

    // MARK: - Sections

    private var sessionNameSection: some View {
        Section(header: sectionHeader("Session")) {
            TextField("Name (optional)", text: $viewModel.setupTitle)
                .font(HC.text(16))
                .foregroundStyle(HC.ink)
        }
        .listRowBackground(HC.card)
        .listRowSeparatorTint(HC.line)
    }

    private var projectSection: some View {
        Section(header: projectSectionHeader) {
            if projectStore.activeProjects.isEmpty {
                Button {
                    showProjectManager = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Create your first project")
                    }
                    .font(HC.text(15))
                    .foregroundStyle(HC.red)
                }
            } else {
                // Horizontal chip scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // "None" chip
                        ProjectChip(
                            label: "None",
                            color: HC.muted,
                            isSelected: selectedProject == nil
                        ) {
                            clearProject()
                        }

                        ForEach(projectStore.activeProjects) { project in
                            ProjectChip(
                                label: project.name,
                                color: project.color.color,
                                isSelected: selectedProject?.id == project.id
                            ) {
                                selectProject(project)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .listRowBackground(HC.card)
        .listRowSeparatorTint(HC.line)
    }

    private var projectSectionHeader: some View {
        HStack {
            sectionHeader("Project")
            Spacer()
            Button {
                showProjectManager = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12))
                    .foregroundStyle(HC.muted)
            }
        }
    }

    @ViewBuilder
    private var tagSection: some View {
        if let project = selectedProject {
            Section(header: sectionHeader("Tag")) {
                ForEach(project.topLevelTags) { parentTag in
                    tagRow(parentTag, project: project)
                }

                // Inline add top-level tag
                if addingTagUnder == project.id {
                    inlineAddTagRow(parentId: nil, projectId: project.id)
                } else {
                    Button {
                        addingTagUnder = project.id
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
    private func tagRow(_ tag: ProjectTag, project: Project) -> some View {
        let children = project.subTags(of: tag.id)
        let hasChildren = !children.isEmpty
        let isExpanded = expandedTagIds.contains(tag.id)
        let isSelected = selectedTagId == tag.id

        VStack(alignment: .leading, spacing: 0) {
            // Parent tag row
            HStack {
                Button {
                    viewModel.setupTagId = isSelected ? "" : tag.id.uuidString
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16))
                            .foregroundStyle(isSelected ? HC.red : HC.muted)
                        Text(tag.name)
                            .font(HC.text(15))
                            .foregroundStyle(HC.ink)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Expand/collapse if children exist
                if hasChildren || addingTagUnder == tag.id {
                    Button {
                        if isExpanded {
                            expandedTagIds.remove(tag.id)
                        } else {
                            expandedTagIds.insert(tag.id)
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(HC.muted)
                    }
                    .buttonStyle(.plain)
                }

                // Add sub-tag button
                Button {
                    expandedTagIds.insert(tag.id)
                    addingTagUnder = tag.id
                    inlineNewTagName = ""
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(HC.muted)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
            .padding(.vertical, 4)

            // Children (when expanded)
            if isExpanded || addingTagUnder == tag.id {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(children) { child in
                        subTagRow(child, project: project)
                    }

                    if addingTagUnder == tag.id {
                        inlineAddTagRow(parentId: tag.id, projectId: project.id)
                            .padding(.leading, 28)
                    } else if children.isEmpty {
                        EmptyView()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func subTagRow(_ tag: ProjectTag, project: Project) -> some View {
        let isSelected = selectedTagId == tag.id
        HStack(spacing: 8) {
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 11))
                .foregroundStyle(HC.muted)
                .padding(.leading, 20)

            Button {
                viewModel.setupTagId = isSelected ? "" : tag.id.uuidString
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(isSelected ? HC.red : HC.muted)
                    Text(tag.name)
                        .font(HC.text(14))
                        .foregroundStyle(HC.ink)
                }
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func inlineAddTagRow(parentId: UUID?, projectId: UUID) -> some View {
        HStack(spacing: 8) {
            if parentId != nil {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 11))
                    .foregroundStyle(HC.muted)
                    .padding(.leading, 20)
            }
            TextField("Tag name", text: $inlineNewTagName)
                .font(HC.text(14))
                .foregroundStyle(HC.ink)
                .submitLabel(.done)
                .onSubmit { commitInlineTag(parentId: parentId, projectId: projectId) }
                .autocorrectionDisabled()

            Button {
                commitInlineTag(parentId: parentId, projectId: projectId)
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(HC.red)
            }
            .buttonStyle(.plain)

            Button {
                addingTagUnder = nil
                inlineNewTagName = ""
            } label: {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(HC.muted)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var clearSection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.setupTitle = ""
                viewModel.setupTag = ""
                viewModel.setupProjectId = ""
                viewModel.setupTagId = ""
            } label: {
                Text("Clear setup")
                    .font(HC.text(16))
            }
            .foregroundStyle(HC.red)
        }
        .listRowBackground(HC.card)
        .listRowSeparatorTint(HC.line)
    }
}

// MARK: - Project Chip

private struct ProjectChip: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(HC.text(13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? HC.ink : HC.muted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: HC.Radius.pill, style: .continuous)
                    .fill(isSelected ? HC.card : HC.bg)
                    .overlay(
                        RoundedRectangle(cornerRadius: HC.Radius.pill, style: .continuous)
                            .strokeBorder(isSelected ? color.opacity(0.5) : HC.line, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PomodoroSetupSheet(viewModel: TimerViewModel())
}
