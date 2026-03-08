//
//  OrdoApp.swift
//  Ordo
//
//  Created by Anh Tuấn Lê on 6/3/26.
//

import SwiftUI

@main
struct OrdoApp: App {
    @State private var appState: AppState
    @State private var recentItems: RecentItemsStore

    init() {
        _appState = State(initialValue: UITestAppStateFactory.make() ?? AppState.live())

        let environment = ProcessInfo.processInfo.environment
        let recentItemsDefaults = environment["ORDO_UI_TEST_MODE"] == "smoke"
            ? (UserDefaults(suiteName: "com.ordo.app.ui-tests") ?? .standard)
            : .standard

        _recentItems = State(initialValue: RecentItemsStore(defaults: recentItemsDefaults))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(recentItems)
        }
    }
}
