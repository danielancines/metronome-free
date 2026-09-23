//
//  SwiftUI_MetronomeUITests.swift
//  SwiftUI.MetronomeUITests
//
//  Created by Daniel Ancines on 23/09/26.
//

import XCTest

final class SwiftUI_MetronomeUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testSpeedTrainerSettingsAreReachable() throws {
        let app = XCUIApplication()
        app.launch()

        let toggleRow = app.buttons["Speed Trainer"]
        XCTAssertTrue(toggleRow.waitForExistence(timeout: 5), "Speed Trainer row should exist")
        toggleRow.tap()

        let settingsButton = app.buttons["Speed Trainer Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings button should appear after enabling")
        XCTAssertTrue(settingsButton.isHittable, "Settings button should be reachable on screen")
        settingsButton.tap()

        let startBPMLabel = app.staticTexts["Start BPM"]
        XCTAssertTrue(startBPMLabel.waitForExistence(timeout: 5), "Start BPM field should appear in the sheet")
        XCTAssertTrue(startBPMLabel.isHittable, "Start BPM field should be visible and reachable, not cut off")

        let stepper = app.steppers["Stepper.Start BPM"]
        XCTAssertTrue(stepper.waitForExistence(timeout: 5), "Start BPM stepper should exist in the sheet")
        let incrementButton = stepper.buttons["Increment"]
        XCTAssertTrue(incrementButton.isHittable, "Stepper increment control should be tappable, not cut off")
        let valueBefore = engineStartBPMText(app)
        incrementButton.tap()
        let valueAfter = engineStartBPMText(app)
        XCTAssertNotEqual(valueBefore, valueAfter, "Tapping increment should actually change the Start BPM value")

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        XCTAssertTrue(doneButton.isHittable)
        doneButton.tap()
    }

    private func engineStartBPMText(_ app: XCUIApplication) -> String {
        app.staticTexts["Value.Start BPM"].label
    }

    @MainActor
    func testPlaybackSurvivesBackgrounding() throws {
        let app = XCUIApplication()
        app.launch()

        let playButton = app.buttons["Play"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 5), "Play button should exist")
        playButton.tap()

        // Confirm it actually started before backgrounding.
        XCTAssertTrue(app.buttons["Stop"].waitForExistence(timeout: 3), "Should be playing after tapping Play")

        // Send the app to the background by activating SpringBoard (the home screen) —
        // like locking the screen or switching apps would.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        springboard.activate()
        XCTAssertTrue(springboard.wait(for: .runningForeground, timeout: 5), "SpringBoard should have come to the foreground")

        // Note: app.state is not used to confirm backgrounding here — it read back
        // "runningForeground" even after SpringBoard was confirmed frontmost, which
        // points to a stale/unreliable value in this XCUITest/Xcode combination rather
        // than the app actually failing to background.

        // Simulate a locked-screen playback duration.
        Thread.sleep(forTimeInterval: 6)

        // Bring it back and confirm the metronome is still playing —
        // if the audio session had been interrupted/stopped by the OS,
        // our interruption handler would have flipped this to Play.
        app.activate()
        XCTAssertTrue(app.buttons["Stop"].waitForExistence(timeout: 5), "Metronome should still be playing after returning from background")

        app.buttons["Stop"].tap()
    }

    @MainActor
    func testSessionTimerAndHistoryRecording() throws {
        let app = XCUIApplication()
        app.launch()

        // Start from a clean slate — earlier test runs may have left sessions behind.
        app.buttons["Practice History"].tap()
        if app.buttons["trash"].waitForExistence(timeout: 3) {
            app.buttons["trash"].tap()
            let confirmClearAll = app.buttons["Clear All"]
            XCTAssertTrue(confirmClearAll.waitForExistence(timeout: 3), "Clearing history should ask for confirmation")
            confirmClearAll.tap()
        }
        XCTAssertTrue(app.staticTexts["No practice sessions yet"].waitForExistence(timeout: 3), "History should be empty after clearing")
        app.buttons["Done"].tap()

        let timerText = app.otherElements["Session time"]
        XCTAssertTrue(timerText.waitForExistence(timeout: 5), "Session timer should exist")
        let valueBeforePlay = timerText.value as? String

        app.buttons["Play"].tap()
        XCTAssertTrue(app.buttons["Stop"].waitForExistence(timeout: 3), "Should start playing")

        // Let the session run long enough to clear the minimum-duration-to-log threshold.
        Thread.sleep(forTimeInterval: 5)

        let valueWhilePlaying = timerText.value as? String
        XCTAssertNotEqual(valueBeforePlay, valueWhilePlaying, "Timer should have advanced while playing")
        XCTAssertNotEqual(valueWhilePlaying, "00:00", "Timer should show elapsed time, not zero")

        app.buttons["Stop"].tap()

        app.buttons["Practice History"].tap()
        let summary = app.staticTexts["HistorySummaryCount"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "History should show a summary once a session is recorded")
        XCTAssertEqual(summary.label, "1 session", "Exactly one session should have been recorded")

        let firstRow = app.descendants(matching: .any).matching(identifier: "SessionRow").firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "Recorded session row should be visible under Today")

        // Swipe to delete, then cancel — the session should remain.
        firstRow.swipeLeft()
        let swipeDeleteButton = app.buttons["Delete"].firstMatch
        XCTAssertTrue(swipeDeleteButton.waitForExistence(timeout: 3), "Swiping should reveal a Delete action")
        swipeDeleteButton.tap()
        let cancelButton = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3), "Deleting a session should ask for confirmation")
        cancelButton.tap()
        XCTAssertEqual(summary.label, "1 session", "Session should remain after cancelling the delete")

        // Swipe to delete again, this time confirm — the session should be removed.
        firstRow.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        let confirmDeleteButton = app.buttons["Delete"].firstMatch
        XCTAssertTrue(confirmDeleteButton.waitForExistence(timeout: 3), "Confirmation dialog should offer a Delete button")
        confirmDeleteButton.tap()
        XCTAssertTrue(app.staticTexts["No practice sessions yet"].waitForExistence(timeout: 5), "Session should be gone after confirming the delete")

        app.buttons["Done"].tap()
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
