import XCTest

final class WorkbenchUITests: XCTestCase {
    @MainActor
    private func launchApp() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Build task console"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    func testLaunchShowsSeededWorkspaceAndTasks() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Workbench"].exists)
        XCTAssertTrue(app.staticTexts["Build task console"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Review persistence layer"].exists)
    }

    @MainActor
    func testCreateAndRunTaskWorkflow() {
        let app = launchApp()
        app.buttons.matching(identifier: "task.new").firstMatch.click()

        let titleField = app.textFields["task.new.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        titleField.click()
        titleField.typeText("Verify UI workflow")

        let promptEditor = app.textViews["task.new.prompt"]
        promptEditor.click()
        promptEditor.typeText("Exercise the deterministic UI test provider.")

        let createButton = app.buttons.matching(identifier: "task.new.create").firstMatch
        XCTAssertTrue(createButton.isEnabled)
        createButton.click()

        XCTAssertTrue(app.staticTexts["Verify UI workflow"].waitForExistence(timeout: 2))

        let runButton = app.buttons.matching(identifier: "task.detail.run").firstMatch
        XCTAssertTrue(runButton.waitForExistence(timeout: 2))
        runButton.click()

        XCTAssertTrue(
            app.descendants(matching: .any)["task.status.Completed"]
                .waitForExistence(timeout: 8)
        )
    }
}
