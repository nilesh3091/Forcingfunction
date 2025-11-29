//
//  TaskDataStore.swift
//  ForcingFunction
//
//  Manages persistence of task data
//

import Foundation

class TaskDataStore {
    static let shared = TaskDataStore()
    
    private let fileName = "tasks.json"
    private var tasks: [PomodoroTask] = []
    
    private init() {
        loadTasks()
    }
    
    // MARK: - File Management
    
    private var fileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(fileName)
    }
    
    // MARK: - Load Tasks
    
    /// Load all tasks from disk
    func loadTasks() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            tasks = []
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            tasks = try decoder.decode([PomodoroTask].self, from: data)
            
            // Sort by created date (most recent first)
            tasks.sort { $0.createdDate > $1.createdDate }
        } catch {
            print("Error loading tasks: \(error)")
            tasks = []
        }
    }
    
    // MARK: - Save Tasks
    
    /// Save all tasks to disk
    @discardableResult
    private func saveTasks() -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(tasks)
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            print("Error saving tasks: \(error)")
            return false
        }
    }
    
    // MARK: - Task Management
    
    /// Add a new task
    func addTask(_ task: PomodoroTask) {
        tasks.append(task)
        tasks.sort { $0.createdDate > $1.createdDate }
        saveTasks()
    }
    
    /// Update an existing task
    func updateTask(_ task: PomodoroTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            saveTasks()
        }
    }
    
    /// Get all tasks
    func getAllTasks() -> [PomodoroTask] {
        return tasks
    }
    
    /// Get active (non-archived) tasks
    func getActiveTasks() -> [PomodoroTask] {
        return tasks.filter { !$0.isArchived }
    }
    
    /// Get archived tasks
    func getArchivedTasks() -> [PomodoroTask] {
        return tasks.filter { $0.isArchived }
    }
    
    /// Get task by ID
    func getTask(byId id: UUID) -> PomodoroTask? {
        return tasks.first { $0.id == id }
    }
    
    /// Delete a task by ID
    func deleteTask(byId id: UUID) {
        tasks.removeAll { $0.id == id }
        saveTasks()
    }
    
    /// Complete a task (marks as completed and archived)
    func completeTask(byId id: UUID) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].isCompleted = true
            tasks[index].isArchived = true
            tasks[index].completedDate = Date()
            saveTasks()
        }
    }
    
    /// Add pomodoro time to a task
    func addPomodoroTime(toTaskId id: UUID, minutes: Double) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].totalPomodoroMinutes += minutes
            saveTasks()
        }
    }
}


