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
        username.typeText("nativefixture")
        let password = app.secureTextFields["Password"]
        password.tap()
        password.typeText("wrongpassword")
        app.buttons["Sign in"].tap()
        XCTAssertTrue(app.staticTexts["Check your username and password."].waitForExistence(timeout: 20))
        print("iOS displayed the rejected login error")

        password.tap()
        password.typeText("correctpassword")
        app.buttons["Sign in"].tap()
        XCTAssertTrue(app.staticTexts["Connected"].waitForExistence(timeout: 25))
        print("iOS authenticated HTTPS and opened the cookie-authenticated WebSocket")

        let composer = app.textViews["Message"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        composer.tap()
        composer.typeText("First turn")
        app.buttons["Send"].tap()
        XCTAssertTrue(app.staticTexts["First reply streamed correctly."].waitForExistence(timeout: 25))

        composer.tap()
        composer.typeText("Second turn")
        app.buttons["Send"].tap()
        XCTAssertTrue(app.staticTexts["Second reply resumed correctly."].waitForExistence(timeout: 30))
        print("iOS rendered both turns, including the resumed reply")
    }
}
