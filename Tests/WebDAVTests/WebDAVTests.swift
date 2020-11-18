import XCTest
@testable import WebDAV

final class WebDAVTests: XCTestCase {
    var webDAV = WebDAV()
    
    func testListFiles() {
        guard let (account, password) = getAccount() else { return XCTFail() }
        
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
        guard let (account, password) = getAccount() else { return XCTFail() }
        
        let expectation = XCTestExpectation(description: "Upload data to WebDAV")
        
        let data = UUID().uuidString.data(using: .utf8)!
        
        webDAV.upload(data: data, toPath: "WebDAVSwiftUploadTest.txt", account: account, password: password) { success in
            XCTAssert(success)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    @available(iOS 10.0, *)
    func testUploadFile() throws {
        guard let (account, password) = getAccount() else { return XCTFail() }
        
        let expectation = XCTestExpectation(description: "Upload file to WebDAV")
        
        let data = UUID().uuidString.data(using: .utf8)!
        let tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("WebDAVSwiftUploadTest.txt")
        try data.write(to: tempFileURL)
        
        webDAV.upload(file: tempFileURL, toPath: "WebDAVSwiftUploadTest.txt", account: account, password: password) { success in
            try? FileManager.default.removeItem(at: tempFileURL)
            XCTAssert(success)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testDownloadData() {
        guard let (account, password) = getAccount() else { return XCTFail() }
        
        let path = "WebDAVSwiftUploadTest.txt"
        
        // Upload a file
        
        let uploadExpectation = XCTestExpectation(description: "Upload data to WebDAV")
        
        let uuid = UUID().uuidString
        let data = uuid.data(using: .utf8)!
        
        webDAV.upload(data: data, toPath: path, account: account, password: password) { success in
            XCTAssert(success)
            uploadExpectation.fulfill()
        }
        
        wait(for: [uploadExpectation], timeout: 10.0)
        
        //Download that file
        
        let downloadExpectation = XCTestExpectation(description: "Download data from WebDAV")
        
        webDAV.download(fileAtPath: path, account: account, password: password) { data in
            guard let data = data else { return XCTFail("No data returned") }
            let string = String(data: data, encoding: .utf8)
            XCTAssertEqual(string, uuid)
            downloadExpectation.fulfill()
        }
        
        wait(for: [downloadExpectation], timeout: 10.0)
    }
    
    func testCreateFolder() {
        guard let (account, password) = getAccount() else { return XCTFail() }
        
        let createExpectation = XCTestExpectation(description: "Create folder in WebDAV")
        let deleteExpectation = XCTestExpectation(description: "Delete folder")
        
        let path = UUID().uuidString
        
        webDAV.createFolder(atPath: path, account: account, password: password) { success in
            XCTAssert(success)
            createExpectation.fulfill()
        }
        
        wait(for: [createExpectation], timeout: 10.0)
        
        webDAV.deleteFile(atPath: path, account: account, password: password) { success in
            deleteExpectation.fulfill()
        }
        
        wait(for: [deleteExpectation], timeout: 10.0)
    }
    
    private func getAccount() -> (account: DAVAccount, password: String)? {
        guard let username = ProcessInfo.processInfo.environment["webdav_user"],
              let baseURL = ProcessInfo.processInfo.environment["webdav_url"],
              let password = ProcessInfo.processInfo.environment["webdav_password"] else {
            XCTFail("You need to set the webdav_user, webdav_url, and webdav_password in the environment.")
            return nil
        }
        
        return (SimpleAccount(username: username, baseURL: baseURL), password)
    }

    static var allTests = [
        ("testListFiles", testListFiles),
        ("testUploadData", testUploadData),
        ("testDownloadData", testDownloadData),
        ("testCreateFolder", testCreateFolder)
    ]
}
