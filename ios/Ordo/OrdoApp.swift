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
    @StateObject private var recentItems: RecentItemsStore

    init() {
        _appState = StateObject(wrappedValue: UITestAppStateFactory.make() ?? AppState.live())

        let environment = ProcessInfo.processInfo.environment
        let recentItemsDefaults = environment["ORDO_UI_TEST_MODE"] == "smoke"
            ? (UserDefaults(suiteName: "com.ordo.app.ui-tests") ?? .standard)
            : .standard

        _recentItems = StateObject(wrappedValue: RecentItemsStore(defaults: recentItemsDefaults))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(recentItems)
        }
    }
}
