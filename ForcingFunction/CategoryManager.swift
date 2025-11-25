//
//  CategoryManager.swift
//  ForcingFunction
//
//  Manages category storage and retrieval
//

import Foundation

class CategoryManager {
    static let shared = CategoryManager()
    
    private let categoriesKey = "pomodoro_categories"
    private let maxActiveCategories = 4
    
    private init() {
        // Ensure we have valid data on init
        loadCategories()
    }
    
    // MARK: - Storage
    
    private var categories: [Category] = []
    
    private func loadCategories() {
        guard let data = UserDefaults.standard.data(forKey: categoriesKey) else {
            categories = []
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            categories = try decoder.decode([Category].self, from: data)
        } catch {
            print("Error loading categories: \(error)")
            categories = []
        }
    }
    
    private func saveCategories() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(categories)
            UserDefaults.standard.set(data, forKey: categoriesKey)
        } catch {
            print("Error saving categories: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    /// Get all active categories (alphabetically sorted, max 4)
    func getActiveCategories() -> [Category] {
        return categories
            .filter { !$0.isArchived }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    /// Get all archived categories (alphabetically sorted)
    func getArchivedCategories() -> [Category] {
        return categories
            .filter { $0.isArchived }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    /// Get category by ID
    func getCategory(byId id: UUID) -> Category? {
        return categories.first { $0.id == id }
    }
    
    /// Check if we can activate more categories
    func canActivateMore() -> Bool {
        return getActiveCategories().count < maxActiveCategories
    }
    
    /// Get count of active categories
    func getActiveCount() -> Int {
        return getActiveCategories().count
    }
    
    /// Get max active categories
    func getMaxActiveCategories() -> Int {
        return maxActiveCategories
    }
    
    /// Create a new category
    func createCategory(name: String, color: CategoryColor) -> Category? {
        // Check if we can add more active categories
        guard canActivateMore() else {
            return nil
        }
        
        // Check if name already exists (case-insensitive)
        let existingCategory = categories.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame && !$0.isArchived }
        if existingCategory != nil {
            return nil // Category with this name already exists
        }
        
        let newCategory = Category(
            name: name,
            color: color,
            isArchived: false
        )
        
        categories.append(newCategory)
        saveCategories()
        return newCategory
    }
    
    /// Update a category
    func updateCategory(_ category: Category) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
            saveCategories()
        }
    }
    
    /// Archive a category
    func archiveCategory(_ category: Category) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index].isArchived = true
            categories[index].archivedDate = Date()
            saveCategories()
        }
    }
    
    /// Unarchive a category
    func unarchiveCategory(_ category: Category) -> Bool {
        // Check if we can activate more
        guard canActivateMore() else {
            return false
        }
        
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index].isArchived = false
            categories[index].archivedDate = nil
            saveCategories()
            return true
        }
        
        return false
    }
    
    /// Get session count for a category
    func getSessionCount(for categoryId: UUID) -> Int {
        let dataStore = PomodoroDataStore.shared
        let allSessions = dataStore.getAllSessions()
        return allSessions.filter { $0.categoryId == categoryId }.count
    }
}



