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
        
        webDAV.listFiles(atPath: "/", account: account, password: password) { files in
            XCTAssertNotNil(files)
            successExpectation.fulfill()
        }
        
        let failureExpectation = XCTestExpectation(description: "Input incorrect password to WebDAV")
        
        webDAV.listFiles(atPath: "/", account: account, password: "") { files in
            XCTAssertNil(files)
            failureExpectation.fulfill()
        }
        
        wait(for: [successExpectation, failureExpectation], timeout: 10.0)
    }
    
    func testUploadData() {
        guard let username = ProcessInfo.processInfo.environment["webdav_user"],
              let baseURL = ProcessInfo.processInfo.environment["webdav_url"],
              let password = ProcessInfo.processInfo.environment["webdav_password"] else {
            return XCTFail("You need to set the webdav_user, webdav_url, and webdav_password in the environment.")
        }
        
        let webDAV = WebDAV()
        let account = AccountStruct(username: username, baseURL: baseURL)
        
        let expectation = XCTestExpectation(description: "Upload data to WebDAV")
        
        let data = UUID().uuidString.data(using: .utf8)!
        
        webDAV.upload(data: data, toPath: "WebDAVSwiftUploadTest.txt", account: account, password: password) { success in
            XCTAssert(success)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }

    static var allTests = [
        ("testListFiles", testListFiles)
    ]
}

struct AccountStruct: Account {
    var username: String?
    var baseURL: String?
}
