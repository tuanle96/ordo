//
//  ContentView.swift
//  Ordo
//
//  Created by Anh Tuấn Lê on 6/3/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.phase {
            case .launching:
                NavigationStack {
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Restoring your workspace…")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("launching-screen")
                    .navigationTitle("Ordo")
                }
            case .login:
                LoginView()
            case .authenticated:
                MainTabView()
            }
        }
        .task {
            await appState.restoreSessionIfNeeded()
        }
        .animation(.smooth, value: appState.phase)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState.preview)
}
