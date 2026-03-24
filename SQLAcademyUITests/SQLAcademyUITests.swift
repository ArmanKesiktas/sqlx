import XCTest

@MainActor
final class SQLAcademyUITests: XCTestCase {
    func testAuthCompletesAndShowsTabs() {
        let app = launchApp(resetProgress: true)
        completeAuthIfNeeded(app)

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 4))
    }

    func testLearnPackageCanBeOpened() {
        let app = launchApp(resetProgress: true, initialTab: "learn")
        completeAuthIfNeeded(app)
        openAnyTutorPackage(app)

        XCTAssertTrue(app.buttons["tutor.start"].waitForExistence(timeout: 4))
    }

    func testTutorChatSendFlowWorksWithFallback() {
        let app = launchApp(resetProgress: true, initialTab: "learn")
        completeAuthIfNeeded(app)
        openAnyTutorPackage(app)

        XCTAssertTrue(app.buttons["tutor.start"].waitForExistence(timeout: 4))
        app.buttons["tutor.start"].tap()
        XCTAssertTrue(app.textFields["tutor.input"].waitForExistence(timeout: 5))
        app.textFields["tutor.input"].tap()
        app.textFields["tutor.input"].typeText("Bilgisayar mühendisi")
        app.buttons["tutor.send"].tap()

        XCTAssertTrue(app.staticTexts["Bilgisayar mühendisi"].waitForExistence(timeout: 4))
    }

    func testPracticeRunAndResetButtonsWork() {
        let app = launchApp(resetProgress: true, initialTab: "practice")
        completeAuthIfNeeded(app)

        XCTAssertTrue(app.buttons["practice.run"].waitForExistence(timeout: 4))
        app.buttons["practice.run"].tap()
        XCTAssertTrue(app.buttons["practice.reset"].exists)
        app.buttons["practice.reset"].tap()
    }

    func testChallengesSearchAndFilterFlowWorks() {
        let app = launchApp(resetProgress: true, initialTab: "challenges")
        completeAuthIfNeeded(app)

        let field = challengeSearchField(in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 4))
        field.tap()
        field.typeText("join")

        if app.buttons["challenges.filter.pending"].exists {
            app.buttons["challenges.filter.pending"].tap()
        }
        if app.buttons["challenges.filter.all"].exists {
            app.buttons["challenges.filter.all"].tap()
        }
        XCTAssertTrue(field.exists)
    }

    func testProfileResetProgressActionIsReachable() {
        let app = launchApp(resetProgress: true, initialTab: "profile")
        completeAuthIfNeeded(app)

        XCTAssertTrue(app.buttons["profile.reset"].waitForExistence(timeout: 4))
        app.buttons["profile.reset"].tap()
        let hasTabBar = app.tabBars.firstMatch.waitForExistence(timeout: 2)
        let returnedToAuth = app.buttons["auth.appleSignIn"].exists
        XCTAssertTrue(hasTabBar || returnedToAuth)
    }

    private func launchApp(resetProgress: Bool, initialTab: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        if resetProgress {
            app.launchEnvironment["UITEST_RESET_PROGRESS"] = "1"
        }
        app.launchEnvironment["UITEST_BYPASS_AUTH"] = "1"
        if let initialTab {
            app.launchEnvironment["UITEST_INITIAL_TAB"] = initialTab
        }
        app.launch()
        return app
    }

    private func completeAuthIfNeeded(_ app: XCUIApplication) {
        if app.buttons["auth.appleSignIn"].waitForExistence(timeout: 2) {
            XCTFail("UI tests should bypass auth via UITEST_BYPASS_AUTH.")
        }
    }

    private func tapTab(_ app: XCUIApplication, candidates: [String]) {
        for candidate in candidates where app.tabBars.buttons[candidate].exists {
            app.tabBars.buttons[candidate].tap()
            return
        }
        let fallback = app.tabBars.buttons.element(boundBy: 0)
        XCTAssertTrue(fallback.exists)
        fallback.tap()
    }

    private func openAnyTutorPackage(_ app: XCUIApplication) {
        let packageIdentifiers = [
            "learn.package.data_analytics",
            "learn.package.intermediate_sql",
            "learn.package.senior_sql"
        ]
        for identifier in packageIdentifiers {
            let button = app.buttons[identifier]
            if button.waitForExistence(timeout: 2) {
                button.tap()
                return
            }
            let element = app.otherElements[identifier]
            if element.waitForExistence(timeout: 2) {
                element.tap()
                return
            }
        }

        let titleCandidates = [
            "SQL Foundations",
            "SQL'e Giriş",
            "Intermediate SQL",
            "Senior SQL"
        ]
        for title in titleCandidates {
            let label = app.staticTexts[title]
            if label.waitForExistence(timeout: 2) {
                label.tap()
                return
            }
        }
        XCTFail("No tutor package card found.")
    }

    private func challengeSearchField(in app: XCUIApplication) -> XCUIElement {
        let candidates = [
            app.textFields["challenges.search"],
            app.textFields["Görev ara"],
            app.textFields["Search challenge"],
            app.textFields.element(boundBy: 0)
        ]
        return candidates.first(where: { $0.exists }) ?? candidates[0]
    }
}
