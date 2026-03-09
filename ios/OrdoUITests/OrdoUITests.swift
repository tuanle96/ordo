//
//  OrdoUITests.swift
//  OrdoUITests
//
//  Created by Anh Tuấn Lê on 6/3/26.
//

import XCTest

final class OrdoUITests: XCTestCase {
    private let backendURL = "http://localhost:38424/api/v1/mobile"
    private let odooURL = "http://127.0.0.1:38421"
    private let database = "odoo17"
    private let username = "admin"
    private let standardTimeout: TimeInterval = 20
    private let extendedTimeout: TimeInterval = 30

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        XCUIApplication().terminate()
    }

    @MainActor
    func testSmokeLoginBrowseAndDetail() throws {
        let app = makeApp(resetStorage: true)
        app.launch()

        signIn(app)

        assertHomeScreen(app)

        tapBrowseTab(app)
        XCTAssertTrue(app.buttons["browse-model-crm-lead"].waitForExistence(timeout: standardTimeout))
        XCTAssertTrue(app.buttons["browse-model-sale-order"].exists)

        app.buttons["browse-model-res-partner"].tap()
        XCTAssertTrue(app.buttons["record-row-1"].waitForExistence(timeout: standardTimeout))

        openFirstRecordDetail(app)
        XCTAssertTrue(app.staticTexts["record-detail-title"].waitForExistence(timeout: standardTimeout))
        XCTAssertTrue(app.staticTexts["field-value-nickname"].waitForExistence(timeout: standardTimeout))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["record-row-1"].waitForExistence(timeout: standardTimeout))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["browse-model-crm-lead"].waitForExistence(timeout: standardTimeout))

        app.buttons["browse-model-crm-lead"].tap()
        XCTAssertTrue(app.buttons["record-row-1"].waitForExistence(timeout: standardTimeout))
        openFirstRecordDetail(app)
        XCTAssertTrue(app.staticTexts["record-detail-title"].waitForExistence(timeout: standardTimeout))
        XCTAssertTrue(app.staticTexts["field-value-stage_id"].waitForExistence(timeout: standardTimeout))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["record-row-1"].waitForExistence(timeout: standardTimeout))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["browse-model-sale-order"].waitForExistence(timeout: standardTimeout))

        app.buttons["browse-model-sale-order"].tap()
        XCTAssertTrue(app.buttons["record-row-1"].waitForExistence(timeout: standardTimeout))
        openFirstRecordDetail(app)
        XCTAssertTrue(app.staticTexts["record-detail-title"].waitForExistence(timeout: standardTimeout))
        XCTAssertTrue(app.staticTexts["field-value-amount_total"].waitForExistence(timeout: standardTimeout))
    }

    @MainActor
    func testSmokeRestoresSessionAfterRelaunch() throws {
        let firstLaunch = makeApp(resetStorage: true)
        firstLaunch.launch()
        signIn(firstLaunch)
        XCTAssertTrue(firstLaunch.otherElements["main-tab-screen"].waitForExistence(timeout: standardTimeout))
        assertHomeScreen(firstLaunch)

        firstLaunch.terminate()

        let secondLaunch = makeApp(resetStorage: false)
        secondLaunch.launch()

        XCTAssertTrue(secondLaunch.otherElements["main-tab-screen"].waitForExistence(timeout: standardTimeout))
        XCTAssertFalse(secondLaunch.buttons["login-submit-button"].exists)
        assertHomeScreen(secondLaunch)
    }

    @MainActor
    func testDetailEditModeShowsEditorsAndHonorsVisibilityRules() throws {
        let app = makeApp(resetStorage: true)
        app.launch()

        signIn(app)
        tapBrowseTab(app)
        XCTAssertTrue(app.buttons["browse-model-res-partner"].waitForExistence(timeout: standardTimeout))
        app.buttons["browse-model-res-partner"].tap()
        openFirstRecordDetail(app)

        openEditMode(app)

        XCTAssertTrue(app.textFields["field-editor-name"].waitForExistence(timeout: standardTimeout))
        XCTAssertFalse(app.otherElements["field-row-internal_note"].exists)
        XCTAssertTrue(app.staticTexts["field-value-credit_limit"].waitForExistence(timeout: standardTimeout))
    }

    @MainActor
    func testDetailSaveFlowPersistsUpdatedValueLocally() throws {
        let app = makeApp(resetStorage: true)
        app.launch()

        signIn(app)
        tapBrowseTab(app)
        XCTAssertTrue(app.buttons["browse-model-res-partner"].waitForExistence(timeout: standardTimeout))
        app.buttons["browse-model-res-partner"].tap()
        openFirstRecordDetail(app)

        openEditMode(app)

        let nicknameField = app.textFields["field-editor-nickname"]
        XCTAssertTrue(nicknameField.waitForExistence(timeout: extendedTimeout))
        nicknameField.clearAndTypeText("Priority Client")

        let saveButton = app.buttons["detail-save-button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: standardTimeout))
        saveButton.tap()

        waitForReadOnlyDetail(app)
        XCTAssertTrue(app.staticTexts["field-value-nickname"].waitForExistence(timeout: standardTimeout))
        XCTAssertEqual(app.staticTexts["field-value-nickname"].label, "Priority Client")
    }

    @MainActor
    func testDetailMany2OneSaveFlowPersistsSelectedRelation() throws {
        let app = makeApp(resetStorage: true)
        app.launch()

        signIn(app)
        tapBrowseTab(app)
        XCTAssertTrue(app.buttons["browse-model-res-partner"].waitForExistence(timeout: standardTimeout))
        app.buttons["browse-model-res-partner"].tap()
        openFirstRecordDetail(app)

        openEditMode(app)

        let countryEditor = app.buttons["field-editor-country_id"]
        XCTAssertTrue(countryEditor.waitForExistence(timeout: extendedTimeout))
        countryEditor.tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: standardTimeout))
        searchField.tap()
        searchField.typeText("Ca")

        let canadaOption = app.buttons["many2one-option-country_id-124"]
        XCTAssertTrue(canadaOption.waitForExistence(timeout: standardTimeout))
        canadaOption.tap()

        let saveButton = app.buttons["detail-save-button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: standardTimeout))
        saveButton.tap()

        waitForReadOnlyDetail(app)
        let countryValue = app.staticTexts["field-value-country_id"]
        XCTAssertTrue(countryValue.waitForExistence(timeout: standardTimeout))
        XCTAssertEqual(countryValue.label, "Canada")
    }

    @MainActor
    func testDetailCancelFlowSupportsKeepEditingAndDiscard() throws {
        let app = makeApp(resetStorage: true)
        app.launch()

        signIn(app)
        tapBrowseTab(app)
        XCTAssertTrue(app.buttons["browse-model-res-partner"].waitForExistence(timeout: standardTimeout))
        app.buttons["browse-model-res-partner"].tap()
        openFirstRecordDetail(app)

        openEditMode(app)

        let nicknameField = app.textFields["field-editor-nickname"]
        XCTAssertTrue(nicknameField.waitForExistence(timeout: extendedTimeout))
        nicknameField.clearAndTypeText("Draft Only")

        let cancelButton = app.buttons["detail-cancel-button"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: standardTimeout))
        cancelButton.tap()

        let keepEditingButton = app.buttons["Keep Editing"]
        XCTAssertTrue(keepEditingButton.waitForExistence(timeout: standardTimeout))
        keepEditingButton.tap()

        XCTAssertTrue(nicknameField.waitForExistence(timeout: standardTimeout))
        XCTAssertEqual(nicknameField.value as? String, "Draft Only")

        cancelButton.tap()

        let discardButton = app.buttons["Discard Changes"]
        XCTAssertTrue(discardButton.waitForExistence(timeout: standardTimeout))
        discardButton.tap()

        waitForReadOnlyDetail(app)
        let nicknameValue = app.staticTexts["field-value-nickname"]
        XCTAssertTrue(nicknameValue.waitForExistence(timeout: standardTimeout))
        XCTAssertEqual(nicknameValue.label, "VIP 1")
    }

    @MainActor
    func testDetailMany2ManySaveFlowPersistsSelectedTags() throws {
        let app = makeApp(resetStorage: true)
        app.launch()

        signIn(app)
        tapBrowseTab(app)
        XCTAssertTrue(app.buttons["browse-model-res-partner"].waitForExistence(timeout: standardTimeout))
        app.buttons["browse-model-res-partner"].tap()
        openFirstRecordDetail(app)

        openEditMode(app)

        let tagsEditor = app.buttons["field-editor-category_id"]
        XCTAssertTrue(tagsEditor.waitForExistence(timeout: extendedTimeout))
        tagsEditor.tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: standardTimeout))
        searchField.tap()
        searchField.typeText("Re")

        let retailOption = app.buttons["many2many-option-category_id-3"]
        XCTAssertTrue(retailOption.waitForExistence(timeout: standardTimeout))
        retailOption.tap()

        let doneButton = app.buttons["many2many-done-category_id"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: standardTimeout))
        doneButton.tap()

        let saveButton = app.buttons["detail-save-button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: standardTimeout))
        saveButton.tap()

        waitForReadOnlyDetail(app)
        let tagsValue = app.staticTexts["field-value-category_id"]
        XCTAssertTrue(tagsValue.waitForExistence(timeout: standardTimeout))
        XCTAssertEqual(tagsValue.label, "VIP, Wholesale, Retail")
    }

    @MainActor
    func testDetailSaveFailurePreservesEditStateAndDraft() throws {
        let app = makeApp(resetStorage: true, failSave: true)
        app.launch()

        signIn(app)
        tapBrowseTab(app)
        XCTAssertTrue(app.buttons["browse-model-res-partner"].waitForExistence(timeout: standardTimeout))
        app.buttons["browse-model-res-partner"].tap()
        openFirstRecordDetail(app)

        openEditMode(app)

        let nicknameField = app.textFields["field-editor-nickname"]
        XCTAssertTrue(nicknameField.waitForExistence(timeout: extendedTimeout))
        nicknameField.clearAndTypeText("Broken Save")

        let saveButton = app.buttons["detail-save-button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: standardTimeout))
        saveButton.tap()

        let errorMessage = app.staticTexts["detail-error-message"]
        XCTAssertTrue(errorMessage.waitForExistence(timeout: standardTimeout))
        XCTAssertEqual(errorMessage.label, "Save failed for test.")
        XCTAssertTrue(nicknameField.waitForExistence(timeout: standardTimeout))
        XCTAssertEqual(nicknameField.value as? String, "Broken Save")
        XCTAssertTrue(app.buttons["detail-cancel-button"].exists)
    }

    @MainActor
    func testWorkflowActionConfirmUpdatesStatusAndHidesButton() throws {
        let app = makeApp(resetStorage: true)
        app.launch()

        signIn(app)
        tapBrowseTab(app)
        XCTAssertTrue(app.buttons["browse-model-sale-order"].waitForExistence(timeout: standardTimeout))
        app.buttons["browse-model-sale-order"].tap()
        openFirstRecordDetail(app)

        let actionButton = app.buttons["detail-action-action_confirm"]
        XCTAssertTrue(actionButton.waitForExistence(timeout: standardTimeout))
        actionButton.tap()

        let confirmButton = app.alerts.buttons["Confirm"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: standardTimeout))
        confirmButton.tap()

        let statusValue = app.staticTexts["record-detail-status"]
        XCTAssertTrue(statusValue.waitForExistence(timeout: standardTimeout))
        XCTAssertEqual(statusValue.label, "Sales Order")
        XCTAssertFalse(actionButton.waitForExistence(timeout: 2))
    }

    @MainActor
    func testHomeShowsRecentlyViewedRecordAfterRelaunch() throws {
        let firstLaunch = makeApp(resetStorage: true)
        firstLaunch.launch()

        signIn(firstLaunch)
        tapBrowseTab(firstLaunch)
        XCTAssertTrue(firstLaunch.buttons["browse-model-res-partner"].waitForExistence(timeout: standardTimeout))
        firstLaunch.buttons["browse-model-res-partner"].tap()
        openFirstRecordDetail(firstLaunch)
        XCTAssertTrue(firstLaunch.staticTexts["record-detail-title"].waitForExistence(timeout: standardTimeout))

        firstLaunch.terminate()

        let secondLaunch = makeApp(resetStorage: false)
        secondLaunch.launch()

        XCTAssertTrue(secondLaunch.otherElements["main-tab-screen"].waitForExistence(timeout: standardTimeout))
        XCTAssertTrue(secondLaunch.buttons["recent-item-res.partner-1"].waitForExistence(timeout: standardTimeout))
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
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment["ORDO_UI_TEST_MODE"] = "smoke"
        app.launchEnvironment["ORDO_UI_TEST_RESET_STORAGE"] = resetStorage ? "1" : "0"
        app.launchEnvironment["ORDO_UI_TEST_FAIL_SAVE"] = failSave ? "1" : "0"
        app.launchEnvironment["ORDO_UI_TEST_STORAGE_NAMESPACE"] = storageNamespace
        return app
    }

    private var storageNamespace: String {
        let sanitized = name.replacingOccurrences(
            of: "[^A-Za-z0-9]+",
            with: "-",
            options: .regularExpression
        )
        return sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private func signIn(_ app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Sign In"].waitForExistence(timeout: standardTimeout))

        let odooField = app.textFields["login-odoo-url-field"]
        XCTAssertTrue(odooField.waitForExistence(timeout: standardTimeout))
        odooField.replaceTextIfNeeded(odooURL)

        let databaseField = app.textFields["login-database-field"]
        XCTAssertTrue(reveal(databaseField, in: app, timeout: standardTimeout))
        databaseField.replaceTextIfNeeded(database)

        let usernameField = app.textFields["login-username-field"]
        XCTAssertTrue(reveal(usernameField, in: app, timeout: standardTimeout))
        usernameField.replaceTextIfNeeded(username)

        let advancedSettingsButton = app.buttons["Advanced Settings"]
        XCTAssertTrue(reveal(advancedSettingsButton, in: app, timeout: standardTimeout))

        if !app.textFields["login-backend-url-field"].exists {
            advancedSettingsButton.tap()
        }

        let backendField = app.textFields["login-backend-url-field"]
        XCTAssertTrue(reveal(backendField, in: app, timeout: standardTimeout))
        backendField.replaceTextIfNeeded(backendURL)

        let passwordField = app.secureTextFields["login-password-field"]
        XCTAssertTrue(reveal(passwordField, in: app, timeout: standardTimeout))
        passwordField.tap()
        passwordField.typeText("admin")

        let keyboardDoneButton = app.buttons["Done"]
        if keyboardDoneButton.exists {
            keyboardDoneButton.tap()
        }

        let submitButton = app.buttons["login-submit-button"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: standardTimeout))
        XCTAssertTrue(submitButton.waitForEnabled(timeout: standardTimeout))
        XCTAssertTrue(submitButton.isHittable)
        submitButton.tap()

        XCTAssertTrue(app.otherElements["main-tab-screen"].waitForExistence(timeout: standardTimeout))
    }

    private func assertHomeScreen(_ app: XCUIApplication) {
        XCTAssertTrue(app.otherElements["main-tab-screen"].waitForExistence(timeout: extendedTimeout))
        let homeButton = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeButton.waitForExistence(timeout: standardTimeout))
        XCTAssertTrue(browseTabButton(in: app).waitForExistence(timeout: standardTimeout))
    }

    private func browseTabButton(in app: XCUIApplication) -> XCUIElement {
        let iconMatchedButton = app.tabBars.buttons["rectangle.stack.person.crop"]
        if iconMatchedButton.exists {
            return iconMatchedButton
        }

        return app.tabBars.buttons.matching(NSPredicate(format: "label == %@", "Browse")).firstMatch
    }

    private func tapBrowseTab(_ app: XCUIApplication) {
        let browseButton = browseTabButton(in: app)
        XCTAssertTrue(browseButton.waitForExistence(timeout: standardTimeout))
        browseButton.tap()
    }

    private func openEditMode(_ app: XCUIApplication) {
        waitForReadOnlyDetail(app)

        let editButton = app.buttons["detail-edit-button"]
        XCTAssertTrue(editButton.waitForExistence(timeout: extendedTimeout))
        editButton.tap()

        let cancelButton = app.buttons["detail-cancel-button"]
        if !cancelButton.waitForExistence(timeout: 5) {
            editButton.tap()
        }

        XCTAssertTrue(cancelButton.waitForExistence(timeout: extendedTimeout))
        XCTAssertTrue(app.textFields["field-editor-name"].waitForExistence(timeout: extendedTimeout))
    }

    private func openFirstRecordDetail(_ app: XCUIApplication) {
        let row = app.buttons["record-row-1"]
        XCTAssertTrue(row.waitForExistence(timeout: extendedTimeout))
        row.tap()

        let title = app.staticTexts["record-detail-title"]
        if !title.waitForExistence(timeout: standardTimeout) {
            row.tap()
        }

        waitForReadOnlyDetail(app)
    }

    private func waitForReadOnlyDetail(_ app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["record-detail-title"].waitForExistence(timeout: extendedTimeout))
        XCTAssertTrue(app.buttons["detail-edit-button"].waitForExistence(timeout: standardTimeout))
        let primarySection = app.descendants(matching: .any)["schema-section-primary-0"]
        let firstTabSection = app.descendants(matching: .any)["schema-section-tab-0-0"]
        let nameValue = app.staticTexts["field-value-name"]
        XCTAssertTrue(
            primarySection.waitForExistence(timeout: 5)
                || firstTabSection.waitForExistence(timeout: 5)
                || nameValue.waitForExistence(timeout: standardTimeout)
        )
    }

    private func reveal(
        _ element: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval,
        maxSwipes: Int = 6
    ) -> Bool {
        if element.waitForExistence(timeout: min(timeout, 2)) {
            return true
        }

        for _ in 0..<maxSwipes {
            app.swipeUp()

            if element.waitForExistence(timeout: 1.5) {
                return true
            }
        }

        return element.exists
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

    func replaceTextIfNeeded(_ text: String) {
        guard (value as? String) != text else { return }
        clearAndTypeText(text)
    }

    func waitForEnabled(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
