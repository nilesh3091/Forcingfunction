import SwiftUI

struct PomodoroSetupSheet: View {
    @ObservedObject var viewModel: TimerViewModel
    @Environment(\.dismiss) private var dismiss
    
    private var theme: AppTheme { viewModel.theme }
    
    private var tagPreviewText: String {
        let t = viewModel.setupTag.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "No tag" : t
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                theme.background(.primary)
                    .ignoresSafeArea()
                
                Form {
                    Section(header: Text("Pomodoro").foregroundColor(theme.text(.secondary))) {
                        TextField("Name (optional)", text: $viewModel.setupTitle)
                            .foregroundColor(theme.text(.primary))
                    }
                    .listRowBackground(theme.background(.card))
                    
                    Section(header: Text("Tag").foregroundColor(theme.text(.secondary))) {
                        TextField("Tag (optional)", text: $viewModel.setupTag)
                            .foregroundColor(theme.text(.primary))
                        
                        HStack {
                            Text("Color")
                                .foregroundColor(theme.text(.primary))
                            Spacer()
                            Picker("", selection: Binding(
                                get: { viewModel.setupTagColor },
                                set: { viewModel.setupTagColor = $0 }
                            )) {
                                ForEach(CategoryColor.allCases, id: \.self) { c in
                                    Text(c.rawValue).tag(c)
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(theme.accentColor)
                            .disabled(viewModel.setupTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        
                        HStack {
                            Text("Preview")
                                .foregroundColor(theme.text(.primary))
                            Spacer()
                            Text(tagPreviewText)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(
                                    viewModel.setupTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? theme.text(.tertiary)
                                    : viewModel.setupTagColor.color
                                )
                                .lineLimit(1)
                        }
                    }
                    .listRowBackground(theme.background(.card))
                    
                    Section {
                        Button(role: .destructive) {
                            viewModel.setupTitle = ""
                            viewModel.setupTag = ""
                            // Keep color as-is; it only matters when a tag is present.
                        } label: {
                            Text("Clear setup")
                        }
                        .foregroundColor(theme.error)
                    }
                    .listRowBackground(theme.background(.card))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(theme.accentColor)
                }
            }
        }
        .fontDesign(.rounded)
    }
}

#Preview {
    PomodoroSetupSheet(viewModel: TimerViewModel())
}

