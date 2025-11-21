//
//  MoreView.swift
//  ForcingFunction
//
//  More options and additional features
//

import SwiftUI

struct MoreView: View {
    @ObservedObject var viewModel: TimerViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack {
                    Text("More")
                        .font(.title)
                        .foregroundColor(.white)
                    
                    Text("Coming soon...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                    
                    // Placeholder for additional features
                    Text("Export data, about, help, etc.")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                }
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    MoreView(viewModel: TimerViewModel())
}

