import XCTest
@testable import WebDAV

final class WebDAVTests: XCTestCase {
    func testListFiles() {
        guard let username = ProcessInfo.processInfo.environment["webdav_user"],
              let baseURL = ProcessInfo.processInfo.environment["webdav_url"],
              let password = ProcessInfo.processInfo.environment["webdav_password"] else {
            return XCTFail("You need to set the webdav_user, webdav_url, and webdav_password in the environment.")
        }
        
        let webDAV = WebDAV()
        let account = AccountStruct(username: username, baseURL: baseURL)
        
        let successExpectation = XCTestExpectation(description: "List files from WebDAV")
        
        webDAV.listFiles(atPath: "/", account: account, password: password) { success in
            XCTAssert(success)
            successExpectation.fulfill()
        }
        
        let failureExpectation = XCTestExpectation(description: "Input incorrect password to WebDAV")
        
        webDAV.listFiles(atPath: "/", account: account, password: "") { success in
            XCTAssertFalse(success)
            failureExpectation.fulfill()
        }
        
        wait(for: [successExpectation, failureExpectation], timeout: 10.0)
    }

    static var allTests = [
        ("testListFiles", testListFiles)
    ]
}

struct AccountStruct: Account {
    var username: String?
    var baseURL: String?
}
