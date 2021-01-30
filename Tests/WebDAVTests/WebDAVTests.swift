import XCTest
@testable import WebDAV
import Networking

final class WebDAVTests: XCTestCase {
    var webDAV = WebDAV()
    
    //MARK: WebDAV
    
    func testListFiles() {
        guard let (account, password) = getAccount() else { return XCTFail() }
        
        let successExpectation = XCTestExpectation(description: "List files from WebDAV")
        let failureExpectation = XCTestExpectation(description: "Input incorrect password to WebDAV")
        
        // List files
        
        webDAV.listFiles(atPath: "/", account: account, password: password, foldersFirst: false) { files, error in
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
    
    func testListFilesFoldersFirst() {
        guard let (account, password) = getAccount() else { return XCTFail() }
        
        let expectation = XCTestExpectation(description: "List files from WebDAV")
        
        // List files
        
        webDAV.listFiles(atPath: "/", account: account, password: password, foldersFirst: true) { files, error in
            XCTAssertNotNil(files)
            XCTAssertNil(error)
            
            var folders = true
            for file in files ?? [] {
                if file.isDirectory {
                    if !folders {
                        XCTFail("Folder found below a file.")
                    }
                } else {
                    folders = false
                }
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testUploadData() {
        guard let (account, password) = getAccount() else { return XCTFail() }
        
        let uploadExpectation = XCTestExpectation(description: "Upload data to WebDAV")
        let checkExpectation = XCTestExpectation(description: "Check uploaded file")
        let deleteExpectation = XCTestExpectation(description: "Delete file")
        
        let name = UUID().uuidString
        let path = name + ".txt"
        let data = UUID().uuidString.data(using: .utf8)!
        
        // Upload data
        
        webDAV.upload(data: data, toPath: path, account: account, password: password) { error in
            XCTAssertNil(error)
            uploadExpectation.fulfill()
        }
        
        wait(for: [uploadExpectation], timeout: 10.0)
        
        // Check that the file exists as expected
        
        webDAV.listFiles(atPath: "/", account: account, password: password) { files, error in
            guard let file = files?.first(where: { $0.path == path }) else {
                return XCTFail("Created file not found.")
            }
            XCTAssertEqual(file.name, name)
            XCTAssertEqual(file.extension, "txt")
            XCTAssertEqual(file.fileName, path)
            checkExpectation.fulfill()
        }
        
        wait(for: [checkExpectation], timeout: 10.0)
        
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
        
        webDAV.upload(file: tempFileURL, toPath: path, account: account, password: password) { error in
            try? FileManager.default.removeItem(at: tempFileURL)
            XCTAssertNil(error)
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
        
        webDAV.upload(data: data, toPath: path, account: account, password: password) { error in
            XCTAssertNil(error)
            uploadExpectation.fulfill()
        }
        
        wait(for: [uploadExpectation], timeout: 10.0)
        
        // Download that file
        
        webDAV.download(fileAtPath: path, account: account, password: password) { data, error in
            guard let data = data else { return XCTFail("No data returned") }
            XCTAssertNil(error)
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
        
        webDAV.createFolder(atPath: path, account: account, password: password) { error in
            XCTAssertNil(error)
            createExpectation.fulfill()
        }
        
        wait(for: [createExpectation], timeout: 10.0)
        
        // Delete the folder
        
        webDAV.deleteFile(atPath: path, account: account, password: password) { _ in
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
        
        webDAV.upload(data: data, toPath: path, account: account, password: password) { error in
            XCTAssertNil(error)
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
        
        webDAV.deleteFile(atPath: path, account: account, password: password) { error in
            XCTAssertNil(error)
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
    
    func testURLScheme() {
        guard let (accountConstant, password) = getAccount(),
              let baseURL = accountConstant.baseURL else { return XCTFail() }
        
        var account = accountConstant
        
        if baseURL.hasPrefix("https://") {
            account.baseURL = String(baseURL.dropFirst(8))
        } else {
            account.baseURL = "https://" + baseURL
        }
        
        let expectation = XCTestExpectation(description: "List files from WebDAV")
        
        // List files
        
        webDAV.listFiles(atPath: "/", account: account, password: password) { files, error in
            XCTAssertNotNil(files)
            XCTAssertNil(error)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    //MARK: Networking
    
    private func downloadImage(imagePath: String, account: SimpleAccount, password: String) {
        let expectation = XCTestExpectation(description: "Download image from WebDAV")
        
        try? webDAV.deleteCachedData(forItemAtPath: imagePath, account: account)
        
        webDAV.downloadImage(path: imagePath, account: account, password: password) { image, cachedImageURL, error in
            XCTAssertNil(error)
            XCTAssertNotNil(image)
            
            XCTAssert(FileManager.default.fileExists(atPath: cachedImageURL!.path))
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testDownloadImage() {
        guard let (account, password) = getAccount() else { return XCTFail() }
        guard let imagePath = ProcessInfo.processInfo.environment["image_path"] else {
            return XCTFail("You need to set the image_path in the environment.")
        }
        
        downloadImage(imagePath: imagePath, account: account, password: password)
        
        XCTAssertNoThrow(try webDAV.deleteCachedData(forItemAtPath: imagePath, account: account))
    }
    
    func testImageCache() throws {
        guard let (account, password) = getAccount() else { return XCTFail() }
        guard let imagePath = ProcessInfo.processInfo.environment["image_path"] else {
            return XCTFail("You need to set the image_path in the environment.")
        }
        
        downloadImage(imagePath: imagePath, account: account, password: password)
        
        let cachedImageURL = try webDAV.getCachedDataURL(forItemAtPath: imagePath, account: account)!
        try webDAV.deleteCachedData(forItemAtPath: imagePath, account: account)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cachedImageURL.path))
    }
    
    func testDeleteAllCachedData() throws {
        guard let (account, password) = getAccount() else { return XCTFail() }
        guard let imagePath = ProcessInfo.processInfo.environment["image_path"] else {
            return XCTFail("You need to set the image_path in the environment.")
        }
        
        downloadImage(imagePath: imagePath, account: account, password: password)
        
        let cachedImageURL = try webDAV.getCachedDataURL(forItemAtPath: imagePath, account: account)!
        XCTAssertNoThrow(try webDAV.deleteAllCachedData())
        XCTAssertFalse(FileManager.default.fileExists(atPath: cachedImageURL.path))
    }
    
    private func getAccount() -> (account: SimpleAccount, password: String)? {
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
