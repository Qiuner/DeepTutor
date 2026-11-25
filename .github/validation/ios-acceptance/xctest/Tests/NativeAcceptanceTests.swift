import XCTest

final class NativeAcceptanceTests: XCTestCase {
    @MainActor
    func testLoginStreamingAndReconnect() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "org.reactjs.native.example.DeepTutorMobile")
        app.launch()

        let address = app.textFields.matching(
            NSPredicate(format: "label == %@ OR placeholderValue == %@", "Server address", "https://tutor.example.com")
        ).firstMatch
        XCTAssertTrue(address.waitForExistence(timeout: 60))
        address.tap()
        address.typeText("https://localhost:18001")
        app.buttons["Connect"].tap()

        let username = app.textFields["Username"]
        XCTAssertTrue(username.waitForExistence(timeout: 25))
        username.tap()
        typeAndVerify("nativefixture", into: username)
        let password = app.secureTextFields["Password"]
        password.tap()
        typeSecurely("wrongpassword", into: password)
        app.buttons["Sign in"].tap()
        XCTAssertTrue(app.staticTexts["Check your username and password."].waitForExistence(timeout: 20))
        print("iOS displayed the rejected login error")

        password.tap()
        typeSecurely("correctpassword", into: password)
        app.buttons["Sign in"].tap()
        XCTAssertTrue(app.staticTexts["Connected"].waitForExistence(timeout: 25))
        print("iOS authenticated HTTPS and opened the cookie-authenticated WebSocket")

        let composer = app.textViews["Message"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        composer.tap()
        typeAndVerify("First turn", into: composer)
        app.buttons["Send"].tap()
        XCTAssertTrue(app.staticTexts["First reply streamed correctly."].waitForExistence(timeout: 25))

        composer.tap()
        typeAndVerify("Second turn", into: composer)
        app.buttons["Send"].tap()
        XCTAssertTrue(app.staticTexts["Second reply resumed correctly."].waitForExistence(timeout: 30))
        print("iOS rendered both turns, including the resumed reply")
    }

    @MainActor
    private func typeAndVerify(_ text: String, into field: XCUIElement) {
        var prefix = ""
        for character in text {
            field.typeText(String(character))
            prefix.append(character)
            let value = NSPredicate(format: "value == %@", prefix)
            let entryApplied = XCTNSPredicateExpectation(predicate: value, object: field)
            XCTAssertEqual(XCTWaiter.wait(for: [entryApplied], timeout: 4), .completed,
                           "Input did not retain the typed character at position \(prefix.count)")
        }
    }

    @MainActor
    private func typeSecurely(_ text: String, into field: XCUIElement) {
        for character in text {
            field.typeText(String(character))
        }
    }
}
