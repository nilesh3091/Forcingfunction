//
//  ProfileView.swift
//  ForcingFunction
//
//  Profile/Settings view (moved from sheet to tab)
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: TimerViewModel
    
    var body: some View {
        SettingsView(viewModel: viewModel)
    }
}

#Preview {
    ProfileView(viewModel: TimerViewModel())
}

