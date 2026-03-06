//
//  OrdoApp.swift
//  Ordo
//
//  Created by Anh Tuấn Lê on 6/3/26.
//

import SwiftUI

@main
struct OrdoApp: App {
    @StateObject private var appState: AppState

    init() {
        _appState = StateObject(wrappedValue: AppState.live())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
