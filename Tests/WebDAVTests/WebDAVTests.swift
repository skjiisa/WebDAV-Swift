import XCTest
@testable import WebDAV

final class WebDAVTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(WebDAV().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
