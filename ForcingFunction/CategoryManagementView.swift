//
//  CategoryManagementView.swift
//  ForcingFunction
//
//  Category management UI for Settings
//

import SwiftUI

struct CategoryManagementView: View {
    @State private var activeCategories: [Category] = []
    @State private var archivedCategories: [Category] = []
    @State private var showingCreateCategory = false
    @State private var showingEditCategory: Category? = nil
    @State private var showingArchiveConfirmation: Category? = nil
    @State private var showingUnarchiveLimitAlert = false
    @State private var categoryToUnarchive: Category? = nil
    
    private let categoryManager = CategoryManager.shared
    let accentColor: Color
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Active Categories Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Active Categories")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(activeCategories.count)/\(categoryManager.getMaxActiveCategories())")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        if activeCategories.isEmpty {
                            // Empty state
                            VStack(spacing: 12) {
                                Image(systemName: "tag")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray.opacity(0.5))
                                
                                Text("No categories yet")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.6))
                                
                                if activeCategories.count < categoryManager.getMaxActiveCategories() {
                                    Button(action: {
                                        showingCreateCategory = true
                                    }) {
                                        Text("Create Your First Category")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 10)
                                            .background(accentColor)
                                            .cornerRadius(8)
                                    }
                                    .padding(.top, 8)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            // Active categories list
                            ForEach(activeCategories) { category in
                                CategoryRowView(
                                    category: category,
                                    accentColor: accentColor,
                                    sessionCount: categoryManager.getSessionCount(for: category.id),
                                    onEdit: {
                                        showingEditCategory = category
                                    },
                                    onArchive: {
                                        showingArchiveConfirmation = category
                                    }
                                )
                                .padding(.horizontal, 20)
                            }
                            
                            // Add category button
                            if activeCategories.count < categoryManager.getMaxActiveCategories() {
                                Button(action: {
                                    showingCreateCategory = true
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(accentColor)
                                        Text("Add Category")
                                            .foregroundColor(accentColor)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                            } else {
                                Text("Archive a category to add more")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.horizontal, 20)
                                    .padding(.top, 8)
                            }
                        }
                    }
                    
                    // Archived Categories Section
                    if !archivedCategories.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Archived Categories")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                            
                            ForEach(archivedCategories) { category in
                                ArchivedCategoryRowView(
                                    category: category,
                                    accentColor: accentColor,
                                    sessionCount: categoryManager.getSessionCount(for: category.id),
                                    canUnarchive: activeCategories.count < categoryManager.getMaxActiveCategories(),
                                    onUnarchive: {
                                        if activeCategories.count < categoryManager.getMaxActiveCategories() {
                                            _ = categoryManager.unarchiveCategory(category)
                                            loadCategories()
                                        } else {
                                            categoryToUnarchive = category
                                            showingUnarchiveLimitAlert = true
                                        }
                                    }
                                )
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            loadCategories()
        }
        .sheet(isPresented: $showingCreateCategory) {
            CreateEditCategoryView(
                accentColor: accentColor,
                onSave: { name, color in
                    _ = categoryManager.createCategory(name: name, color: color)
                    loadCategories()
                }
            )
        }
        .sheet(item: $showingEditCategory) { category in
            CreateEditCategoryView(
                category: category,
                accentColor: accentColor,
                onSave: { name, color in
                    var updatedCategory = category
                    updatedCategory.name = name
                    updatedCategory.color = color
                    categoryManager.updateCategory(updatedCategory)
                    loadCategories()
                }
            )
        }
        .alert("Archive Category", isPresented: .constant(showingArchiveConfirmation != nil)) {
            Button("Archive", role: .destructive) {
                if let category = showingArchiveConfirmation {
                    categoryManager.archiveCategory(category)
                    loadCategories()
                    showingArchiveConfirmation = nil
                }
            }
            Button("Cancel", role: .cancel) {
                showingArchiveConfirmation = nil
            }
        } message: {
            if let category = showingArchiveConfirmation {
                Text("Archive '\(category.name)'? This will hide it from the timer dropdown. Historical sessions will keep this category.")
            }
        }
        .alert("Limit Reached", isPresented: $showingUnarchiveLimitAlert) {
            Button("OK", role: .cancel) {
                categoryToUnarchive = nil
            }
        } message: {
            Text("You have \(categoryManager.getMaxActiveCategories()) active categories. Archive one to unarchive this category.")
        }
    }
    
    private func loadCategories() {
        activeCategories = categoryManager.getActiveCategories()
        archivedCategories = categoryManager.getArchivedCategories()
    }
}

struct CategoryRowView: View {
    let category: Category
    let accentColor: Color
    let sessionCount: Int
    let onEdit: () -> Void
    let onArchive: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Color indicator
            Circle()
                .fill(category.color.color)
                .frame(width: 24, height: 24)
            
            // Category name and count
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(sessionCount) session\(sessionCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Edit button
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(accentColor)
                    .font(.system(size: 16))
            }
            
            // Archive button
            Button(action: onArchive) {
                Image(systemName: "archivebox")
                    .foregroundColor(.orange)
                    .font(.system(size: 16))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

struct ArchivedCategoryRowView: View {
    let category: Category
    let accentColor: Color
    let sessionCount: Int
    let canUnarchive: Bool
    let onUnarchive: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Color indicator (muted)
            Circle()
                .fill(category.color.color.opacity(0.4))
                .frame(width: 24, height: 24)
            
            // Category name and count
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.6))
                
                Text("\(sessionCount) session\(sessionCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            // Unarchive button
            Button(action: onUnarchive) {
                Text("Unarchive")
                    .font(.subheadline)
                    .foregroundColor(canUnarchive ? accentColor : .gray)
            }
            .disabled(!canUnarchive)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

struct CreateEditCategoryView: View {
    let category: Category?
    let accentColor: Color
    let onSave: (String, CategoryColor) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var categoryName: String = ""
    @State private var selectedColor: CategoryColor = .red
    
    init(category: Category? = nil, accentColor: Color, onSave: @escaping (String, CategoryColor) -> Void) {
        self.category = category
        self.accentColor = accentColor
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Name input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category Name")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        TextField("Enter category name", text: $categoryName)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Color picker
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Color")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 5), spacing: 16) {
                            ForEach(CategoryColor.allCases, id: \.self) { color in
                                Button(action: {
                                    selectedColor = color
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(color.color)
                                            .frame(width: 44, height: 44)
                                        
                                        if selectedColor == color {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.white)
                                                .font(.system(size: 18, weight: .bold))
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                    
                    // Save button
                    Button(action: {
                        guard !categoryName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        onSave(categoryName.trimmingCharacters(in: .whitespaces), selectedColor)
                        dismiss()
                    }) {
                        Text(category == nil ? "Create Category" : "Save Changes")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(accentColor)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(category == nil ? "New Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(accentColor)
                }
            }
            .onAppear {
                if let category = category {
                    categoryName = category.name
                    selectedColor = category.color
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}











