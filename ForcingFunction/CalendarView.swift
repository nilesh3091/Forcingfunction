//
//  CalendarView.swift
//  ForcingFunction
//
//  Calendar view showing pomodoro sessions by date
//

import SwiftUI

struct CalendarView: View {
    @ObservedObject var viewModel: TimerViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack {
                    Text("Calendar View")
                        .font(.title)
                        .foregroundColor(.white)
                    
                    Text("Coming soon...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                    
                    // Placeholder for calendar implementation
                    Text("This will show your pomodoro sessions organized by date")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    CalendarView(viewModel: TimerViewModel())
}

