import XCTest
@testable import WebDAV

final class WebDAVTests: XCTestCase {
    var webDAV = WebDAV()
    
    //MARK: WebDAV
    
    func testListFiles() {
        guard let (account, password) = getAccount() else { return XCTFail() }
        
        let successExpectation = XCTestExpectation(description: "List files from WebDAV")
        let failureExpectation = XCTestExpectation(description: "Input incorrect password to WebDAV")
        
        // List files
        
        webDAV.listFiles(atPath: "/", account: account, password: password, foldersFirst: false, caching: .ignoreCache) { files, error in
            XCTAssertNotNil(files)
            XCTAssertNil(error)
            successExpectation.fulfill()
        }
        
        // Try to files with incorrect password
        
        webDAV.listFiles(atPath: "/", account: account, password: UUID().uuidString, caching: .ignoreCache) { files, error in
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
        
        webDAV.listFiles(atPath: "/", account: account, password: password, foldersFirst: true, caching: .ignoreCache) { files, error in
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
        let (_, fileName, _) = uploadData(account: account, password: password)
        checkFor(fileNamed: fileName, account: account, password: password)
        deleteFile(path: fileName, account: account, password: password)
    }
    
    @available(iOS 10.0, *)
    func testUploadFile() throws {
        guard let (account, password) = getAccount() else { return XCTFail() }
        
        let uploadExpectation = XCTestExpectation(description: "Upload file")
        let checkExpectation = XCTestExpectation(description: "Check file")
        
        let name = UUID().uuidString
        let path = name + ".txt"
        let data = UUID().uuidString.data(using: .utf8)!
        let tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(path)
        try data.write(to: tempFileURL)
        
        webDAV.upload(file: tempFileURL, toPath: path, account: account, password: password) { error in
            try? FileManager.default.removeItem(at: tempFileURL)
            XCTAssertNil(error)
            uploadExpectation.fulfill()
        }
        
        wait(for: [uploadExpectation], timeout: 10.0)
        
        webDAV.listFiles(atPath: "/", account: account, password: password, caching: .ignoreCache) { files, error in
            guard let file = files?.first(where: { $0.path == path }) else {
                return XCTFail("Expected file not found \(error?.localizedDescription ?? "")")
            }
            XCTAssertEqual(file.name, name)
            XCTAssertEqual(file.extension, "txt")
            
            checkExpectation.fulfill()
        }
        
        wait(for: [checkExpectation], timeout: 10.0)
        
        deleteFile(path: path, account: account, password: password)
    }
    
    func testDownloadData() {
        guard let (account, password) = getAccount() else { return XCTFail() }
        
        let uploadedFile = uploadData(account: account, password: password)
        
        let downloadExpectation = XCTestExpectation(description: "Download data")

        webDAV.download(fileAtPath: uploadedFile.fileName, account: account, password: password) { data, error in
            guard let data = data else { return XCTFail("No data returned") }
            XCTAssertNil(error)
            let content = String(data: data, encoding: .utf8)
            XCTAssertEqual(content, uploadedFile.content)
            downloadExpectation.fulfill()
        }
        
        wait(for: [downloadExpectation], timeout: 10.0)
        
        deleteFile(path: uploadedFile.fileName, account: account, password: password)
    }
    
    func testCreateFolder() {
        guard let (account, password) = getAccount() else { return XCTFail() }
        let folder = createFolder(account: account, password: password)
        deleteFile(path: folder, account: account, password: password)
    }
    
    func testDeleteFile() {
        guard let (account, password) = getAccount() else { return XCTFail() }
        let (_, fileName, _) = uploadData(account: account, password: password)
        checkFor(fileNamed: fileName, account: account, password: password)
        deleteFile(path: fileName, account: account, password: password, checkSuccess: true)
        checkFor(fileNamed: fileName, account: account, password: password, checkNotExist: true)
    }
    
    func testMoveFile() {
        guard let (account, password) = getAccount() else { return XCTFail() }
        
        let expectation = XCTestExpectation(description: "Move uploaded file")
        
        let folder = createFolder(account: account, password: password)
        let (_, fileName, _) = uploadData(account: account, password: password)
        
        let destinationPath = folder + "/" + fileName
        
        // Move file
        
        webDAV.moveFile(fromPath: fileName, to: destinationPath, account: account, password: password) { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Check that the file exist in the new location but not the original
        
        checkFor(fileNamed: fileName, in: folder, account: account, password: password)
        checkFor(fileNamed: fileName, account: account, password: password, checkNotExist: true)
        deleteFile(path: folder, account: account, password: password)
    }
    
    func testCopyFile() {
        guard let (account, password) = getAccount() else { return XCTFail() }
        
        let expectation = XCTestExpectation(description: "Copy uploaded file")
        
        let folder = createFolder(account: account, password: password)
        let (_, fileName, _) = uploadData(account: account, password: password)
        
        let destinationPath = folder + "/" + fileName
        
        // Move file
        
        webDAV.copyFile(fromPath: fileName, to: destinationPath, account: account, password: password) { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Check that the file exists in both locations
        
        checkFor(fileNamed: fileName, in: folder, account: account, password: password)
        checkFor(fileNamed: fileName, account: account, password: password)
        deleteFile(path: fileName, account: account, password: password)
        deleteFile(path: folder, account: account, password: password)
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
        
        webDAV.listFiles(atPath: "/", account: account, password: password, caching: .ignoreCache) { files, error in
            XCTAssertNotNil(files)
            XCTAssertNil(error)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    //MARK: Files Cache
    
    func testFilesSaveToMemoryCache() {
        guard let (account, password) = getAccount() else { return XCTFail() }
        
        let expectation = XCTestExpectation(description: "List files from WebDAV")
        
        // List files
        
        webDAV.listFiles(atPath: "/", account: account, password: password, foldersFirst: true, includeSelf: false, caching: []) { [weak self] files, error in
            XCTAssertNotNil(files)
            XCTAssertNil(error)
            
            guard let cachedFiles = self?.webDAV.filesCache[AccountPath(account: account, path: "/")] else { return XCTFail("Files did not save to cache.") }
            XCTAssertEqual(WebDAV.sortedFiles(cachedFiles, foldersFirst: true, includeSelf: false), files)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFilesReadFromMemoryCache() {
        guard let (account, password) = getAccount() else { return XCTFail() }
        
        let dummyExpectation = XCTestExpectation(description: "List dummy files from cache")
        let realExpectation = XCTestExpectation(description: "List files from WebDAV")
        
        // Force fake files into the memory cache
        let dummyFiles = [
            WebDAVFile(path: "test0.txt", id: "0", isDirectory: false, lastModified: Date(), size: 0, etag: "0"),
            WebDAVFile(path: "test1.txt", id: "1", isDirectory: false, lastModified: Date(), size: 0, etag: "1")
        ]
        
        webDAV.filesCache[AccountPath(account: account, path: "/")] = dummyFiles
        
        // List cached dummy files
        
        // includeSelf because the first item is expected to be self
        webDAV.listFiles(atPath: "/", account: account, password: password, foldersFirst: true, includeSelf: true, caching: []) { files, error in
            XCTAssertNotNil(files)
            XCTAssertNil(error)
            
            XCTAssertEqual(dummyFiles, files)
            
            dummyExpectation.fulfill()
        }
        
        // List real files
        
        webDAV.listFiles(atPath: "/", account: account, password: password, foldersFirst: false, caching: .ignoreCache) { files, error in
            XCTAssertNotNil(files)
            XCTAssertNil(error)
            
            XCTAssertNotEqual(dummyFiles, files)
            
            realExpectation.fulfill()
        }
        
        wait(for: [dummyExpectation, realExpectation], timeout: 10.0)
    }
    
    func testDiskCache() {
        guard let (account, password) = getAccount() else { return XCTFail() }
        
        let expectation = XCTestExpectation(description: "List files from WebDAV")
        
        // Clear existing caches
        webDAV.clearFilesCache()
        
        var expectedFiles: [WebDAVFile] = []
        
        // Fetch files
        webDAV.listFiles(atPath: "/", account: account, password: password, foldersFirst: true, includeSelf: false, caching: []) { files, error in
            XCTAssertNil(error)
            guard let files = files,
                  !files.isEmpty else { return XCTFail("No files returned") }
            expectedFiles = files
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Clear memory cache
        webDAV.clearFilesMemoryCache()
        XCTAssert(webDAV.filesCache.isEmpty)
        
        // Load disk cache
        webDAV.loadFilesCacheFromDisk()
        
        // Check that memory cache loaded correctly
        let cachedFiles = webDAV.filesCache[AccountPath(account: account, path: "/")]!
        XCTAssertEqual(expectedFiles, WebDAV.sortedFiles(cachedFiles, foldersFirst: true, includeSelf: false))
    }
    
    func testFilesCacheDoubleRequest() {
        guard let (account, password) = getAccount() else { return XCTFail() }
        
        let expectation = XCTestExpectation(description: "List files from WebDAV")
        expectation.expectedFulfillmentCount = 2
        
        // Force fake files into the memory cache
        let dummyFiles = [
            WebDAVFile(path: "test0.txt", id: "0", isDirectory: false, lastModified: Date(), size: 0, etag: "0"),
            WebDAVFile(path: "test1.txt", id: "1", isDirectory: false, lastModified: Date(), size: 0, etag: "1")
        ]
        
        webDAV.filesCache[AccountPath(account: account, path: "/")] = dummyFiles
        
        // The first response should always run on the main thread before the networked response
        var firstResponse = true
        
        // includeSelf because the first item is expected to be self
        webDAV.listFiles(atPath: "/", account: account, password: password, foldersFirst: true, includeSelf: true, caching: .requestEvenIfCached) { files, error in
            XCTAssertNotNil(files)
            XCTAssertNil(error)
            
            if firstResponse {
                XCTAssertEqual(dummyFiles, files)
                firstResponse = false
            } else {
                XCTAssertNotEqual(dummyFiles, files)
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    //MARK: Image Cache
    
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
//        let cachedImageURL = try webDAV.getCachedDataURL(forItemAtPath: imagePath, account: account)!
//        XCTAssert(FileManager.default.fileExists(atPath: cachedImageURL.path))
        XCTAssertNotNil(webDAV.getCachedImage(forItemAtPath: imagePath, account: account))
        try webDAV.deleteCachedData(forItemAtPath: imagePath, account: account)
//        XCTAssertFalse(FileManager.default.fileExists(atPath: cachedImageURL.path))
    }
    /*
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
     */
    
    //MARK: Thumbnails
    
    func testDownloadThumbnail() {
        guard let (account, password) = getAccount() else { return XCTFail() }
        guard let imagePath = ProcessInfo.processInfo.environment["image_path"] else {
            return XCTFail("You need to set the image_path in the environment.")
        }
        
        downloadThumbnail(imagePath: imagePath, account: account, password: password)
        
        XCTAssertNoThrow(try webDAV.deleteCachedThumbnail(forItemAtPath: imagePath, account: account, with: .fill))
    }
    
    /*
    func testSpecificThumbnailCache() throws {
        guard let (account, password) = getAccount() else { return XCTFail() }
        guard let imagePath = ProcessInfo.processInfo.environment["image_path"] else {
            return XCTFail("You need to set the image_path in the environment.")
        }
        
        downloadThumbnail(imagePath: imagePath, account: account, password: password)
        
        let cachedThumbnailURL = try webDAV.getCachedThumbnailURL(forItemAtPath: imagePath, account: account, with: nil, aspectFill: false)!
        XCTAssertTrue(FileManager.default.fileExists(atPath: cachedThumbnailURL.path))
        XCTAssertNotNil(webDAV.getCachedThumbnail(forItemAtPath: imagePath, account: account, with: nil, aspectFill: false))
        try webDAV.deleteCachedThumbnail(forItemAtPath: imagePath, account: account, with: nil, aspectFill: false)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cachedThumbnailURL.path))
    }
    
    func testGeneralThumbnailCache() throws {
        guard let (account, password) = getAccount() else { return XCTFail() }
        guard let imagePath = ProcessInfo.processInfo.environment["image_path"] else {
            return XCTFail("You need to set the image_path in the environment.")
        }
        
        downloadThumbnail(imagePath: imagePath, account: account, password: password, with: nil, aspectFill: true)
        downloadThumbnail(imagePath: imagePath, account: account, password: password, with: nil, aspectFill: false)
        
        let cachedThumbnailFillURL = try webDAV.getCachedThumbnailURL(forItemAtPath: imagePath, account: account, with: nil, aspectFill: true)!
        let cachedThumbnailFitURL  = try webDAV.getCachedThumbnailURL(forItemAtPath: imagePath, account: account, with: nil, aspectFill: false)!
        
        XCTAssert(FileManager.default.fileExists(atPath: cachedThumbnailFillURL.path))
        XCTAssert(FileManager.default.fileExists(atPath: cachedThumbnailFitURL.path))
        XCTAssertEqual(try webDAV.getAllCachedThumbnails(forItemAtPath: imagePath, account: account).count, 2)
        
        // Delete all cached thumbnails and check that they're both gone
        try webDAV.deleteAllCachedThumbnails(forItemAtPath: imagePath, account: account)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cachedThumbnailFillURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: cachedThumbnailFitURL.path))
    }
 */
    
    //MARK: OCS
    
    func testColorHex() {
        guard let (account, password) = getAccount() else { return XCTFail() }
                
        let expectation = XCTestExpectation(description: "Get color")
        
        webDAV.getNextcloudColorHex(account: account, password: password) { color, error in
            guard let color = color?.dropFirst() else { return XCTFail("No data returned") }
            XCTAssert(color.allSatisfy { $0.isHexDigit })
            XCTAssertNil(error)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testTheme() {
        guard let (account, password) = getAccount() else { return XCTFail() }
        
        let expectation = XCTestExpectation(description: "Get theme")
        
        webDAV.getNextcloudTheme(account: account, password: password) { theme, error in
            guard let theme = theme else { return XCTFail("No data returned") }
            XCTAssertNotNil(theme.url)
            XCTAssertNil(error)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    //MARK: Private
    
    private func getAccount() -> (account: SimpleAccount, password: String)? {
        guard let username = ProcessInfo.processInfo.environment["webdav_user"],
              let baseURL = ProcessInfo.processInfo.environment["webdav_url"],
              let password = ProcessInfo.processInfo.environment["webdav_password"] else {
            XCTFail("You need to set the webdav_user, webdav_url, and webdav_password in the environment.")
            return nil
        }
        
        return (SimpleAccount(username: username, baseURL: baseURL), password)
    }
    
    //MARK: Generic Requests
    
    private func checkFor(fileNamed fileName: String, in folder: String = "/", account: SimpleAccount, password: String, checkNotExist: Bool = false) {
        let expectation = XCTestExpectation(description: "List files before deleting")
        
        webDAV.listFiles(atPath: folder, account: account, password: password, caching: .ignoreCache) { files, error in
            let foundFile = files?.first(where: { $0.fileName == fileName })
            if checkNotExist {
                XCTAssertNil(foundFile, "Expected file not found \(error?.localizedDescription ?? "")")
            } else {
                XCTAssertNotNil(foundFile, "Expected file not found \(error?.localizedDescription ?? "")")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    private func uploadData(account: SimpleAccount, password: String) -> (name: String, fileName: String, content: String) {
        let expectation = XCTestExpectation(description: "Upload data")
        
        let name = UUID().uuidString
        let fileName = name + ".txt"
        let content = UUID().uuidString
        let data = content.data(using: .utf8)!
        
        webDAV.upload(data: data, toPath: fileName, account: account, password: password) { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        return (name, fileName, content)
    }
    
    private func deleteFile(path file: String, account: SimpleAccount, password: String, checkSuccess: Bool = false) {
        let deleteExpectation = XCTestExpectation(description: "Delete file")
        
        webDAV.deleteFile(atPath: file, account: account, password: password) { error in
            if checkSuccess {
                XCTAssertNil(error)
            }
            deleteExpectation.fulfill()
        }
        
        wait(for: [deleteExpectation], timeout: 10.0)
    }
    
    private func createFolder(account: SimpleAccount, password: String) -> String {
        let expectation = XCTestExpectation(description: "Create folder")
        let folder = UUID().uuidString
        
        webDAV.createFolder(atPath: folder, account: account, password: password) { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        return folder
    }
    
    private func downloadImage(imagePath: String, account: SimpleAccount, password: String) {
        let expectation = XCTestExpectation(description: "Download image from WebDAV")
        
        try? webDAV.deleteCachedData(forItemAtPath: imagePath, account: account)
        
        webDAV.downloadImage(path: imagePath, account: account, password: password) { image, error in
            XCTAssertNil(error)
            XCTAssertNotNil(image)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    private func downloadThumbnail(imagePath: String, account: SimpleAccount, password: String, with dimensions: CGSize? = nil, aspectFill: Bool = false) {
        let expectation = XCTestExpectation(description: "Download thumbnail from WebDAV")
        
        try? webDAV.deleteCachedThumbnail(forItemAtPath: imagePath, account: account, with: .fill)
        
        webDAV.downloadThumbnail(path: imagePath, account: account, password: password, with: .fill) { image, error in
            XCTAssertNil(error)
            XCTAssertNotNil(image)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    //MARK: Static

    static var allTests = [
        // WebDAV
        ("testListFiles", testListFiles),
        ("testListFilesFoldersFirst", testListFilesFoldersFirst),
        ("testUploadData", testUploadData),
        //("testUploadFile", testUploadFile),   // Requires iOS 10
        ("testDownloadData", testDownloadData),
        ("testCreateFolder", testCreateFolder),
        ("testDeleteFile", testDeleteFile),
        ("testMoveFile", testMoveFile),
        ("testURLScheme", testURLScheme),
        ("testCopyFile", testCopyFile),
        // Files Cache
        ("testFilesSaveToMemoryCache", testFilesSaveToMemoryCache),
        ("testFilesReadFromMemoryCache", testFilesReadFromMemoryCache),
        ("testDiskCache", testDiskCache),
        ("testFilesCacheDoubleRequest", testFilesCacheDoubleRequest),
        // Image Cache
        ("testDownloadImage", testDownloadImage),
        /*
        ("testImageCache", testImageCache),
        ("testDeleteAllCachedData", testDeleteAllCachedData),
        // Thumbnails
        ("testDownloadThumbnail", testDownloadThumbnail),
        ("testSpecificThumbnailCache", testSpecificThumbnailCache),
        ("testGeneralThumbnailCache", testGeneralThumbnailCache),
 */
        // OCS
        ("testTheme", testTheme),
        ("testColorHex", testColorHex)
    ]
}
