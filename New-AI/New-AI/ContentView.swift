//
//  ContentView.swift
//  New-AI
//
//  Created by Reece Harding on 2/4/25.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @StateObject private var authViewModel = AuthenticationViewModel()
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                HomeView()
            } else {
                AuthenticationView(viewModel: authViewModel)
            }
        }
    }
}

#Preview {
    ContentView()
}
