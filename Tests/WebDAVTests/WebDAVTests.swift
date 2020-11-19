import XCTest
@testable import WebDAV

final class WebDAVTests: XCTestCase {
    var webDAV = WebDAV()
    
    func testListFiles() {
        guard let (account, password) = getAccount() else { return XCTFail() }
        
        let successExpectation = XCTestExpectation(description: "List files from WebDAV")
        let failureExpectation = XCTestExpectation(description: "Input incorrect password to WebDAV")
        
        // List files
        
        webDAV.listFiles(atPath: "/", account: account, password: password) { files, error in
            XCTAssertNotNil(files)
            XCTAssertNil(error)
            successExpectation.fulfill()
        }
        
        // Try to files with incorrect password
        
        webDAV.listFiles(atPath: "/", account: account, password: UUID().uuidString) { files, error in
            XCTAssertNil(files)
            switch error {
            case .unauthorized:
                break
            case nil:
                XCTFail("There was no error.")
            default:
                XCTFail("Error was not 'unauthorized'.")
            }
            failureExpectation.fulfill()
        }
        
        wait(for: [successExpectation, failureExpectation], timeout: 10.0)
    }
    
    func testUploadData() {
        guard let (account, password) = getAccount() else { return XCTFail() }
        
        let uploadExpectation = XCTestExpectation(description: "Upload data to WebDAV")
        let deleteExpectation = XCTestExpectation(description: "Delete file")
        
        let path = UUID().uuidString + ".txt"
        let data = UUID().uuidString.data(using: .utf8)!
        
        // Upload data
        
        webDAV.upload(data: data, toPath: path, account: account, password: password) { success in
            XCTAssert(success)
            uploadExpectation.fulfill()
        }
        
        wait(for: [uploadExpectation], timeout: 10.0)
        
        // Delete file
        
        webDAV.deleteFile(atPath: path, account: account, password: password) { _ in
            deleteExpectation.fulfill()
        }
        
        wait(for: [deleteExpectation], timeout: 10.0)
    }
    
    @available(iOS 10.0, *)
    func testUploadFile() throws {
        guard let (account, password) = getAccount() else { return XCTFail() }
        
        let uploadExpectation = XCTestExpectation(description: "Upload file to WebDAV")
        let deleteExpectation = XCTestExpectation(description: "Delete file from WebDAV")
        
        let path = UUID().uuidString + ".txt"
        let data = UUID().uuidString.data(using: .utf8)!
        let tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(path)
        try data.write(to: tempFileURL)
        
        // Upload File
        
        webDAV.upload(file: tempFileURL, toPath: path, account: account, password: password) { success in
            try? FileManager.default.removeItem(at: tempFileURL)
            XCTAssert(success)
            uploadExpectation.fulfill()
        }
        
        wait(for: [uploadExpectation], timeout: 10.0)
        
        // Delete file
        
        webDAV.deleteFile(atPath: path, account: account, password: password) { _ in
            deleteExpectation.fulfill()
        }
        
        wait(for: [deleteExpectation], timeout: 10.0)
    }
    
    func testDownloadData() {
        guard let (account, password) = getAccount() else { return XCTFail() }
        
        let uploadExpectation = XCTestExpectation(description: "Upload data to WebDAV")
        let downloadExpectation = XCTestExpectation(description: "Download data")
        let deleteExpectation = XCTestExpectation(description: "Delete file")
        
        let path = UUID().uuidString + ".txt"
        let uuid = UUID().uuidString
        let data = uuid.data(using: .utf8)!
        
        // Upload a file
        
        webDAV.upload(data: data, toPath: path, account: account, password: password) { success in
            XCTAssert(success)
            uploadExpectation.fulfill()
        }
        
        wait(for: [uploadExpectation], timeout: 10.0)
        
        // Download that file
        
        webDAV.download(fileAtPath: path, account: account, password: password) { data in
            guard let data = data else { return XCTFail("No data returned") }
            let string = String(data: data, encoding: .utf8)
            XCTAssertEqual(string, uuid)
            downloadExpectation.fulfill()
        }
        
        wait(for: [downloadExpectation], timeout: 10.0)
        
        // Delete the file
        
        webDAV.deleteFile(atPath: path, account: account, password: password) { _ in
            deleteExpectation.fulfill()
        }
        
        wait(for: [deleteExpectation], timeout: 10.0)
    }
    
    func testCreateFolder() {
        guard let (account, password) = getAccount() else { return XCTFail() }
        
        let createExpectation = XCTestExpectation(description: "Create folder in WebDAV")
        let deleteExpectation = XCTestExpectation(description: "Delete folder")
        
        let path = UUID().uuidString
        
        // Create folder
        
        webDAV.createFolder(atPath: path, account: account, password: password) { success in
            XCTAssert(success)
            createExpectation.fulfill()
        }
        
        wait(for: [createExpectation], timeout: 10.0)
        
        // Delete the folder
        
        webDAV.deleteFile(atPath: path, account: account, password: password) { success in
            deleteExpectation.fulfill()
        }
        
        wait(for: [deleteExpectation], timeout: 10.0)
    }
    
    func testDeleteFile() {
        guard let (account, password) = getAccount() else { return XCTFail() }
        
        let uploadExpectation = XCTestExpectation(description: "Upload file to WebDAV")
        let listFilesBefore = XCTestExpectation(description: "List files before deleting")
        let deleteExpectation = XCTestExpectation(description: "Delete file")
        let listFilesAfter = XCTestExpectation(description: "List files after deleting")
        
        let path = UUID().uuidString + ".txt"
        let data = UUID().uuidString.data(using: .utf8)!
        
        // Upload a file
        
        webDAV.upload(data: data, toPath: path, account: account, password: password) { success in
            XCTAssert(success)
            uploadExpectation.fulfill()
        }
        
        wait(for: [uploadExpectation], timeout: 10.0)
        
        // List files to ensure it was created
        
        webDAV.listFiles(atPath: path, account: account, password: password) { files, _ in
            let newFile = files?.first(where: { ($0.path as NSString).lastPathComponent == path })
            XCTAssertNotNil(newFile)
            listFilesBefore.fulfill()
        }
        
        wait(for: [listFilesBefore], timeout: 10.0)
        
        // Delete the file
        
        webDAV.deleteFile(atPath: path, account: account, password: password) { success in
            XCTAssert(success)
            deleteExpectation.fulfill()
        }
        
        wait(for: [deleteExpectation], timeout: 10.0)
        
        // List files to ensure it was deleted
        
        webDAV.listFiles(atPath: path, account: account, password: password) { files, _ in
            let newFile = files?.first(where: { ($0.path as NSString).lastPathComponent == path })
            XCTAssertNil(newFile)
            listFilesAfter.fulfill()
        }
        
        wait(for: [listFilesAfter], timeout: 10.0)
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
        ("testCreateFolder", testCreateFolder),
        ("testDeleteFile", testDeleteFile)
    ]
}
