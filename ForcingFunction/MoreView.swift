//
//  MoreView.swift
//  ForcingFunction
//
//  Tasks view with creation, editing, deletion, and archiving
//

import SwiftUI

struct MoreView: View {
    @ObservedObject var viewModel: TimerViewModel
    @Binding var selectedTab: Int
    @State private var tasks: [PomodoroTask] = []
    @State private var archivedTasks: [PomodoroTask] = []
    @State private var showingArchived = false
    @State private var isCreatingNewTask = false
    @State private var editingTaskId: UUID?
    @State private var editingTitle = ""
    @State private var taskDataStore = TaskDataStore.shared
    @State private var selectedCategoryId: UUID? = nil  // Filter by category
    private let categoryManager = CategoryManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Category filter (only for active tasks, and only if categories exist)
                    if !showingArchived && !categoryManager.getActiveCategories().isEmpty {
                        CategoryFilterView(
                            selectedCategoryId: $selectedCategoryId,
                            onCategorySelected: { categoryId in
                                selectedCategoryId = categoryId
                                loadTasks()
                            }
                        )
                    }
                    
                    // Toggle archived view
                    if !archivedTasks.isEmpty {
                        Button(action: {
                            withAnimation {
                                showingArchived.toggle()
                                selectedCategoryId = nil  // Clear filter when switching
                            }
                        }) {
                            HStack {
                                Text(showingArchived ? "Show Active Tasks" : "Show Archived Tasks (\(archivedTasks.count))")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Spacer()
                                
                                Image(systemName: showingArchived ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                    }
                    
                    // Tasks list
                    if showingArchived {
                        // Archived tasks
                        if archivedTasks.isEmpty {
                            Spacer()
                            Text("No archived tasks")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                            Spacer()
                        } else {
                            List {
                                ForEach(archivedTasks) { task in
                                    TaskRowView(
                                        task: task,
                                        viewModel: viewModel,
                                        selectedTab: $selectedTab,
                                        taskDataStore: taskDataStore,
                                        onUpdate: loadTasks
                                    )
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                }
                            }
                            .listStyle(PlainListStyle())
                            .scrollContentBackground(.hidden)
                        }
                    } else {
                        // Active tasks
                        if tasks.isEmpty && !isCreatingNewTask {
                            Spacer()
                            VStack(spacing: 12) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray.opacity(0.5))
                                
                                Text("No tasks yet")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.gray)
                                
                                Text("Create a task to start tracking pomodoro time")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            Spacer()
                        } else {
                            List {
                                // Inline new task editor (embedded in list, appears at the top)
                                if isCreatingNewTask && !showingArchived {
                                    InlineNewTaskView(
                                        viewModel: viewModel,
                                        onTaskCreated: {
                                            isCreatingNewTask = false
                                            loadTasks()
                                        },
                                        onCancel: {
                                            isCreatingNewTask = false
                                        }
                                    )
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .id("newTaskEditor") // Give it a stable ID for focus system
                                }
                                
                                // Existing tasks
                                ForEach(tasks) { task in
                                    TaskRowView(
                                        task: task,
                                        viewModel: viewModel,
                                        selectedTab: $selectedTab,
                                        taskDataStore: taskDataStore,
                                        onUpdate: loadTasks
                                    )
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                }
                            }
                            .listStyle(PlainListStyle())
                            .scrollContentBackground(.hidden)
                        }
                    }
                }
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadTasks()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                loadTasks()
            }
            .onReceive(NotificationCenter.default.publisher(for: .categoriesDidChange)) { _ in
                loadTasks()
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                if newValue == 3 { // Tasks tab
                    loadTasks()
                }
            }
            .overlay(
                // Floating Action Button - only show when NOT creating new task
                Group {
                    if !showingArchived && !isCreatingNewTask {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                // Plus button to add new task
                                Button(action: {
                                    withAnimation {
                                        isCreatingNewTask = true
                                    }
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 56, height: 56)
                                        .background(viewModel.accentColor)
                                        .clipShape(Circle())
                                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                                }
                                .padding(.trailing, 20)
                                .padding(.bottom, 20)
                            }
                        }
                    }
                }
            )
        }
    }
    
    private func loadTasks() {
        var activeTasks = taskDataStore.getActiveTasks()
        
        // Apply category filter if selected
        if let categoryId = selectedCategoryId {
            activeTasks = activeTasks.filter { $0.categoryId == categoryId }
        }
        
        tasks = activeTasks
        archivedTasks = taskDataStore.getArchivedTasks()
    }
}

struct TaskRowView: View {
    let task: PomodoroTask
    @ObservedObject var viewModel: TimerViewModel
    @Binding var selectedTab: Int
    let taskDataStore: TaskDataStore
    let onUpdate: () -> Void
    
    @State private var isEditing = false
    @State private var editingTitle = ""
    @State private var editingCategoryId: UUID? = nil
    @FocusState private var isTextFieldFocused: Bool
    private let categoryManager = CategoryManager.shared
    
    var body: some View {
        HStack(spacing: 16) {
            // Checkbox - can toggle for both active and archived tasks
            Button(action: {
                if task.isCompleted {
                    // Uncomplete the task
                    taskDataStore.uncompleteTask(byId: task.id)
                } else {
                    // Complete the task
                    taskDataStore.completeTask(byId: task.id)
                    // Clear selected task if this was the selected one
                    if viewModel.selectedTaskId == task.id {
                        viewModel.selectedTaskId = nil
                    }
                }
                onUpdate()
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(task.isCompleted ? viewModel.accentColor : .gray.opacity(0.5))
            }
            .buttonStyle(PlainButtonStyle())
            
            // Task content
            VStack(alignment: .leading, spacing: 4) {
                if isEditing {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Task title", text: $editingTitle)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                saveEdit()
                            }
                            .onAppear {
                                editingTitle = task.title
                                editingCategoryId = task.categoryId
                                isTextFieldFocused = true
                            }
                        
                        // Category selector when editing
                        if !categoryManager.getActiveCategories().isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "tag")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Menu {
                                    Button(action: {
                                        editingCategoryId = nil
                                    }) {
                                        Label("No Category", systemImage: editingCategoryId == nil ? "checkmark" : "")
                                    }
                                    
                                    ForEach(categoryManager.getActiveCategories()) { category in
                                        Button(action: {
                                            editingCategoryId = category.id
                                        }) {
                                            Label(category.name, systemImage: editingCategoryId == category.id ? "checkmark" : "")
                                        }
                                    }
                                } label: {
                                    if let categoryId = editingCategoryId,
                                       let category = categoryManager.getCategory(byId: categoryId) {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(category.color.color)
                                                .frame(width: 8, height: 8)
                                            Text(category.name)
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                    } else {
                                        Text("No Category")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                    }
                } else {
                    Text(task.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .strikethrough(task.isCompleted)
                    
                    // Category and time display
                    HStack(spacing: 8) {
                        // Category badge
                        if let categoryId = task.categoryId,
                           let category = CategoryManager.shared.getCategory(byId: categoryId) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(category.color.color)
                                    .frame(width: 8, height: 8)
                                Text(category.name)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        
                        // Time display
                        if task.totalPomodoroMinutes > 0 {
                            Text(task.formattedTime)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            }
            
            Spacer()
            
            // 3-dots menu (only show when not editing)
            if !isEditing {
                TaskMenuView(
                    task: task,
                    onEdit: {
                        isEditing = true
                    },
                    onDelete: {
                        taskDataStore.deleteTask(byId: task.id)
                        if viewModel.selectedTaskId == task.id {
                            viewModel.selectedTaskId = nil
                        }
                        onUpdate()
                    },
                    onCategoryChange: {
                        onUpdate()
                    }
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing && !task.isArchived {
                // Only navigate if timer is idle
                if viewModel.timerState == .idle {
                    viewModel.selectedTaskId = task.id
                    selectedTab = 0 // Switch to Timer tab
                }
            }
        }
        .onChange(of: isTextFieldFocused) { oldValue, newValue in
            if !newValue && isEditing {
                // Lost focus, save edit
                saveEdit()
            }
        }
    }
    
    private func saveEdit() {
        guard isEditing else { return }
        
        let trimmedTitle = editingTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else {
            isEditing = false
            return
        }
        
        var updatedTask = task
        updatedTask.title = trimmedTitle
        updatedTask.categoryId = editingCategoryId
        taskDataStore.updateTask(updatedTask)
        isEditing = false
        onUpdate()
    }
}

struct InlineNewTaskView: View {
    @ObservedObject var viewModel: TimerViewModel
    let onTaskCreated: () -> Void
    let onCancel: () -> Void
    
    @State private var taskTitle = ""
    @State private var selectedCategoryId: UUID? = nil
    @FocusState private var isFocused: Bool
    private let categoryManager = CategoryManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                // Checkbox indicator (unchecked circle, matching TaskRowView)
                Image(systemName: "circle")
                    .font(.system(size: 24))
                    .foregroundColor(.gray.opacity(0.5))
                
                // Task title field
                TextField("New To-Do", text: $taskTitle)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .focused($isFocused)
                    .onSubmit {
                        if !taskTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                            saveTask()
                        }
                    }
                
                Spacer()
                
                // Action buttons on the right (matching TaskRowView edit button placement)
                HStack(spacing: 12) {
                    // Cancel button
                    Button(action: {
                        cancelTask()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Save/Confirm button
                    Button(action: {
                        saveTask()
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(taskTitle.trimmingCharacters(in: .whitespaces).isEmpty ? .gray.opacity(0.5) : viewModel.accentColor)
                    }
                    .disabled(taskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Category selector
            if !categoryManager.getActiveCategories().isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "tag")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Menu {
                        Button(action: {
                            selectedCategoryId = nil
                        }) {
                            Label("No Category", systemImage: selectedCategoryId == nil ? "checkmark" : "")
                        }
                        
                        ForEach(categoryManager.getActiveCategories()) { category in
                            Button(action: {
                                selectedCategoryId = category.id
                            }) {
                                Label(category.name, systemImage: selectedCategoryId == category.id ? "checkmark" : "")
                            }
                        }
                    } label: {
                        if let categoryId = selectedCategoryId,
                           let category = categoryManager.getCategory(byId: categoryId) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(category.color.color)
                                    .frame(width: 8, height: 8)
                                Text(category.name)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        } else {
                            Text("No Category")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    
                    Spacer()
                }
                .padding(.leading, 40)  // Align with task title
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .onAppear {
            // Auto-focus with a slight delay to ensure view is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isFocused = true
            }
        }
    }
    
    private func saveTask() {
        let trimmedTitle = taskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else {
            cancelTask()
            return
        }
        
        let newTask = PomodoroTask(
            title: trimmedTitle,
            notes: nil,
            categoryId: selectedCategoryId
        )
        TaskDataStore.shared.addTask(newTask)
        
        // Reset and notify
        taskTitle = ""
        isFocused = false
        onTaskCreated()
    }
    
    private func cancelTask() {
        taskTitle = ""
        isFocused = false
        onCancel()
    }
}

// MARK: - Category Filter View

struct CategoryFilterView: View {
    @Binding var selectedCategoryId: UUID?
    let onCategorySelected: (UUID?) -> Void
    private let categoryManager = CategoryManager.shared
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All tasks filter
                Button(action: {
                    selectedCategoryId = nil
                    onCategorySelected(nil)
                }) {
                    Text("All")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(selectedCategoryId == nil ? .black : .white.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedCategoryId == nil ? Color.white : Color.gray.opacity(0.2))
                        .cornerRadius(20)
                }
                
                // Category filters
                ForEach(categoryManager.getActiveCategories()) { category in
                    Button(action: {
                        selectedCategoryId = category.id
                        onCategorySelected(category.id)
                    }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(category.color.color)
                                .frame(width: 10, height: 10)
                            Text(category.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(selectedCategoryId == category.id ? .black : .white.opacity(0.7))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedCategoryId == category.id ? Color.white : Color.gray.opacity(0.2))
                        .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Task Menu View

struct TaskMenuView: View {
    let task: PomodoroTask
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onCategoryChange: () -> Void
    
    @State private var showingCategoryPicker = false
    private let categoryManager = CategoryManager.shared
    private let taskDataStore = TaskDataStore.shared
    
    var body: some View {
        Menu {
            // Edit option (only for active tasks)
            if !task.isArchived {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
                
                // Change Category option
                Menu {
                    Button(action: {
                        changeCategory(to: nil)
                    }) {
                        Label("No Category", systemImage: task.categoryId == nil ? "checkmark" : "")
                    }
                    
                    ForEach(categoryManager.getActiveCategories()) { category in
                        Button(action: {
                            changeCategory(to: category.id)
                        }) {
                            Label(category.name, systemImage: task.categoryId == category.id ? "checkmark" : "")
                        }
                    }
                } label: {
                    Label("Category", systemImage: "tag")
                }
            }
            
            Divider()
            
            // Delete option (for all tasks)
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func changeCategory(to categoryId: UUID?) {
        var updatedTask = task
        updatedTask.categoryId = categoryId
        taskDataStore.updateTask(updatedTask)
        onCategoryChange()
    }
}

#Preview {
    MoreView(viewModel: TimerViewModel(), selectedTab: .constant(3))
}
