//
//  OrdoUITestsLaunchTests.swift
//  OrdoUITests
//
//  Created by Anh Tuấn Lê on 6/3/26.
//

import XCTest

final class OrdoUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ORDO_UI_TEST_MODE"] = "smoke"
        app.launchEnvironment["ORDO_UI_TEST_RESET_STORAGE"] = "1"
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
