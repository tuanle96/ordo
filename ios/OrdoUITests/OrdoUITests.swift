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
        XCTAssertTrue(app.cells["browse-model-crm-lead"].exists)
        XCTAssertTrue(app.cells["browse-model-sale-order"].exists)

        app.cells["browse-model-res-partner"].tap()
        XCTAssertTrue(app.otherElements["record-list-screen"].waitForExistence(timeout: 5))

        app.cells["record-row-1"].tap()
        XCTAssertTrue(app.staticTexts["record-detail-title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["field-value-comment"].waitForExistence(timeout: 5))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.otherElements["record-list-screen"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.tables["browse-home-screen"].waitForExistence(timeout: 5))

        app.cells["browse-model-crm-lead"].tap()
        XCTAssertTrue(app.otherElements["record-list-screen"].waitForExistence(timeout: 5))
        app.cells["record-row-1"].tap()
        XCTAssertTrue(app.staticTexts["record-detail-title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["field-value-stage_id"].waitForExistence(timeout: 5))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.otherElements["record-list-screen"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.tables["browse-home-screen"].waitForExistence(timeout: 5))

        app.cells["browse-model-sale-order"].tap()
        XCTAssertTrue(app.otherElements["record-list-screen"].waitForExistence(timeout: 5))
        app.cells["record-row-1"].tap()
        XCTAssertTrue(app.staticTexts["record-detail-title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["field-value-amount_total"].waitForExistence(timeout: 5))
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
    func testDetailEditModeShowsEditorsAndHonorsVisibilityRules() throws {
        let app = makeApp(resetStorage: true)
        app.launch()

        signIn(app)
        app.tabBars.buttons["Browse"].tap()
        app.cells["browse-model-res-partner"].tap()
        app.cells["record-row-1"].tap()

        let editButton = app.buttons["detail-edit-button"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()

        XCTAssertTrue(app.textFields["field-editor-name"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["field-row-internal_note"].exists)
        XCTAssertTrue(app.staticTexts["field-value-credit_limit"].exists)
    }

    @MainActor
    func testDetailSaveFlowPersistsUpdatedValueLocally() throws {
        let app = makeApp(resetStorage: true)
        app.launch()

        signIn(app)
        app.tabBars.buttons["Browse"].tap()
        app.cells["browse-model-res-partner"].tap()
        app.cells["record-row-1"].tap()

        let editButton = app.buttons["detail-edit-button"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()

        let nicknameField = app.textFields["field-editor-nickname"]
        XCTAssertTrue(nicknameField.waitForExistence(timeout: 5))
        nicknameField.clearAndTypeText("Priority Client")

        let saveButton = app.buttons["detail-save-button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        XCTAssertTrue(app.staticTexts["field-value-nickname"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["field-value-nickname"].label, "Priority Client")
    }

    @MainActor
    func testDetailMany2OneSaveFlowPersistsSelectedRelation() throws {
        let app = makeApp(resetStorage: true)
        app.launch()

        signIn(app)
        app.tabBars.buttons["Browse"].tap()
        app.cells["browse-model-res-partner"].tap()
        app.cells["record-row-1"].tap()

        let editButton = app.buttons["detail-edit-button"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()

        let countryEditor = app.buttons["field-editor-country_id"]
        XCTAssertTrue(countryEditor.waitForExistence(timeout: 5))
        countryEditor.tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("Ca")

        let canadaOption = app.buttons["many2one-option-country_id-124"]
        XCTAssertTrue(canadaOption.waitForExistence(timeout: 5))
        canadaOption.tap()

        let saveButton = app.buttons["detail-save-button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        let countryValue = app.staticTexts["field-value-country_id"]
        XCTAssertTrue(countryValue.waitForExistence(timeout: 5))
        XCTAssertEqual(countryValue.label, "Canada")
    }

    @MainActor
    func testDetailCancelFlowSupportsKeepEditingAndDiscard() throws {
        let app = makeApp(resetStorage: true)
        app.launch()

        signIn(app)
        app.tabBars.buttons["Browse"].tap()
        app.cells["browse-model-res-partner"].tap()
        app.cells["record-row-1"].tap()

        let editButton = app.buttons["detail-edit-button"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()

        let nicknameField = app.textFields["field-editor-nickname"]
        XCTAssertTrue(nicknameField.waitForExistence(timeout: 5))
        nicknameField.clearAndTypeText("Draft Only")

        let cancelButton = app.buttons["detail-cancel-button"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()

        let keepEditingButton = app.buttons["Keep Editing"]
        XCTAssertTrue(keepEditingButton.waitForExistence(timeout: 5))
        keepEditingButton.tap()

        XCTAssertTrue(nicknameField.waitForExistence(timeout: 5))
        XCTAssertEqual(nicknameField.value as? String, "Draft Only")

        cancelButton.tap()

        let discardButton = app.buttons["Discard Changes"]
        XCTAssertTrue(discardButton.waitForExistence(timeout: 5))
        discardButton.tap()

        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        let nicknameValue = app.staticTexts["field-value-nickname"]
        XCTAssertTrue(nicknameValue.waitForExistence(timeout: 5))
        XCTAssertEqual(nicknameValue.label, "VIP 1")
    }

    @MainActor
    func testDetailSaveFailurePreservesEditStateAndDraft() throws {
        let app = makeApp(resetStorage: true, failSave: true)
        app.launch()

        signIn(app)
        app.tabBars.buttons["Browse"].tap()
        app.cells["browse-model-res-partner"].tap()
        app.cells["record-row-1"].tap()

        let editButton = app.buttons["detail-edit-button"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()

        let nicknameField = app.textFields["field-editor-nickname"]
        XCTAssertTrue(nicknameField.waitForExistence(timeout: 5))
        nicknameField.clearAndTypeText("Broken Save")

        let saveButton = app.buttons["detail-save-button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        let errorMessage = app.staticTexts["detail-error-message"]
        XCTAssertTrue(errorMessage.waitForExistence(timeout: 5))
        XCTAssertEqual(errorMessage.label, "Save failed for test.")
        XCTAssertTrue(nicknameField.waitForExistence(timeout: 5))
        XCTAssertEqual(nicknameField.value as? String, "Broken Save")
        XCTAssertTrue(app.buttons["detail-cancel-button"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = makeApp(resetStorage: true)
            app.launch()
        }
    }

    private func makeApp(resetStorage: Bool, failSave: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ORDO_UI_TEST_MODE"] = "smoke"
        app.launchEnvironment["ORDO_UI_TEST_RESET_STORAGE"] = resetStorage ? "1" : "0"
        app.launchEnvironment["ORDO_UI_TEST_FAIL_SAVE"] = failSave ? "1" : "0"
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
