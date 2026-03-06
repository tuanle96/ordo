//
//  OrdoUITests.swift
//  OrdoUITests
//
//  Created by Anh Tuấn Lê on 6/3/26.
//

import XCTest

final class OrdoUITests: XCTestCase {
    private let backendURL = "http://127.0.0.1:3000/api/v1/mobile"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSmokeLoginBrowseAndDetail() throws {
        let app = makeApp(resetStorage: true)
        app.launch()

        signIn(app)

        XCTAssertTrue(app.otherElements["home-screen"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Browse"].tap()
        XCTAssertTrue(app.tables["browse-home-screen"].waitForExistence(timeout: 5))

        app.cells["browse-model-res-partner"].tap()
        XCTAssertTrue(app.otherElements["record-list-screen"].waitForExistence(timeout: 5))

        app.cells["record-row-1"].tap()
        XCTAssertTrue(app.staticTexts["record-detail-title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["field-value-comment"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSmokeRestoresSessionAfterRelaunch() throws {
        let firstLaunch = makeApp(resetStorage: true)
        firstLaunch.launch()
        signIn(firstLaunch)
        XCTAssertTrue(firstLaunch.otherElements["home-screen"].waitForExistence(timeout: 5))

        firstLaunch.terminate()

        let secondLaunch = makeApp(resetStorage: false)
        secondLaunch.launch()

        XCTAssertFalse(secondLaunch.buttons["login-submit-button"].exists)
        XCTAssertTrue(secondLaunch.otherElements["home-screen"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = makeApp(resetStorage: true)
            app.launch()
        }
    }

    private func makeApp(resetStorage: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ORDO_UI_TEST_MODE"] = "smoke"
        app.launchEnvironment["ORDO_UI_TEST_RESET_STORAGE"] = resetStorage ? "1" : "0"
        return app
    }

    private func signIn(_ app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Sign In"].waitForExistence(timeout: 5))

        let backendField = app.textFields["login-backend-url-field"]
        XCTAssertTrue(backendField.waitForExistence(timeout: 2))
        backendField.clearAndTypeText(backendURL)

        let passwordField = app.secureTextFields["login-password-field"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 2))
        passwordField.tap()
        passwordField.typeText("admin")

        let submitButton = app.buttons["login-submit-button"]
        XCTAssertTrue(submitButton.isHittable)
        submitButton.tap()
    }
}

private extension XCUIElement {
    func clearAndTypeText(_ text: String) {
        tap()

        if let currentValue = value as? String, !currentValue.isEmpty {
            let deleteSequence = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            typeText(deleteSequence)
        }

        typeText(text)
    }
}
