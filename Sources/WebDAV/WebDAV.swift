//
//  WebDAV.swift
//  WebDAV-Swift
//
//  Created by Isaac Lyons on 10/29/20.
//

import UIKit
import SWXMLHash

public class WebDAV: NSObject, URLSessionDelegate {
    static let domain = "app.lyons.webdav-swift"
    
    //MARK: Properties
    
    /// The formatter used when rendering cache size in `getCacheSize`.
    public var byteCountFormatter = ByteCountFormatter()
    
    public var filesCache: [AccountPath: [WebDAVFile]] = [:]
    public var dataCache = Cache<AccountPath, Data>()
    public var imageCache = Cache<AccountPath, UIImage>()
    public var thumbnailCache = Cache<AccountPath, [ThumbnailProperties: UIImage]>()
    
    public override init() {
        super.init()
        loadFilesCacheFromDisk()
    }
    
    //MARK: Static
    
    public static func sortedFiles(_ files: [WebDAVFile], foldersFirst: Bool, includeSelf: Bool) -> [WebDAVFile] {
        var files = files
        if !includeSelf, !files.isEmpty {
            files.removeFirst()
        }
        if foldersFirst {
            files = files.filter { $0.isDirectory } + files.filter { !$0.isDirectory }
        }
        return files
    }
}

//MARK: Public

public extension WebDAV {
    
    //MARK: WebDAV Requests
    
    /// List the files and directories at the specified path.
    /// - Parameters:
    ///   - path: The path to list files from.
    ///   - account: The WebDAV account.
    ///   - password: The WebDAV account's password.
    ///   - foldersFirst: Whether folders should be sorted to the top of the list.
    ///   Defaults to `true`.
    ///   - includeSelf: Whether or not the folder itself at the path should be included as a file in the list.
    ///   If so, the folder's WebDAVFile will be the first in the list.
    ///   Defaults to `false`.
    ///   - completion: If account properties are invalid, this will run immediately on the same thread.
    ///   Otherwise, it runs when the nextwork call finishes on a background thread.
    ///   - files: The files at the directory specified. `nil` if there was an error.
    ///   - error: A WebDAVError if the call was unsuccessful.
    /// - Returns: The data task for the request.
    @discardableResult
    func listFiles<A: WebDAVAccount>(atPath path: String, account: A, password: String, foldersFirst: Bool = true, includeSelf: Bool = false, caching options: WebDAVCachingOptions = [], completion: @escaping (_ files: [WebDAVFile]?, _ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
        // Check the cache
        var cachedResponse: [WebDAVFile]?
        let accountPath = AccountPath(account: account, path: path)
        if !options.contains(.doNotReturnCachedResult) {
            if let files = filesCache[accountPath] {
                let sortedFiles = WebDAV.sortedFiles(files, foldersFirst: foldersFirst, includeSelf: includeSelf)
                completion(sortedFiles, nil)
                
                if !options.contains(.requestEvenIfCached) {
                    return nil
                } else {
                    // Remember the cached completion. If the fetched results
                    // are the same, don't bother completing again.
                    cachedResponse = sortedFiles
                }
            }
        }
        
        guard var request = authorizedRequest(path: path, account: account, password: password, method: .propfind) else {
            completion(nil, .invalidCredentials)
            return nil
        }
        
        let body =
"""
<?xml version="1.0"?>
<d:propfind  xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns" xmlns:nc="http://nextcloud.org/ns">
  <d:prop>
        <d:getlastmodified />
        <d:getetag />
        <d:getcontenttype />
        <oc:fileid />
        <oc:permissions />
        <oc:size />
        <nc:has-preview />
        <oc:favorite />
  </d:prop>
</d:propfind>
"""
        request.httpBody = body.data(using: .utf8)
        
        let task = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil).dataTask(with: request) { [weak self] data, response, error in
            
            // Check the response
            let response = response as? HTTPURLResponse
            
            guard 200...299 ~= response?.statusCode ?? 0,
                  let data = data,
                  let string = String(data: data, encoding: .utf8) else {
                let webDAVError = WebDAVError.getError(statusCode: response?.statusCode, error: error)
                return completion(nil, webDAVError)
            }
            
            // Create WebDAVFiles from the XML response
            
            let xml = SWXMLHash.config { config in
                config.shouldProcessNamespaces = true
            }.parse(string)
            
            let files = xml["multistatus"]["response"].all.compactMap { WebDAVFile(xml: $0, baseURL: account.baseURL) }
            
            // Caching
            
            if options.contains(.removeExistingCache) {
                // Remove cached result
                self?.filesCache.removeValue(forKey: accountPath)
                self?.saveFilesCacheToDisk()
            } else if !options.contains(.doNotCacheResult) {
                // Cache the result
                self?.filesCache[accountPath] = files
                self?.saveFilesCacheToDisk()
            }
            
            let sortedFiles = WebDAV.sortedFiles(files, foldersFirst: foldersFirst, includeSelf: includeSelf)
            // Don't send a duplicate completion if the results are the same.
            if sortedFiles != cachedResponse {
                completion(sortedFiles, nil)
            }
        }
        
        task.resume()
        return task
    }
    
    /// Upload data to the specified file path.
    /// - Parameters:
    ///   - data: The data of the file to upload.
    ///   - path: The path, including file name and extension, to upload the file to.
    ///   - account: The WebDAV account.
    ///   - password: The WebDAV account's password.
    ///   - completion: If account properties are invalid, this will run immediately on the same thread.
    ///   Otherwise, it runs when the nextwork call finishes on a background thread.
    ///   - error: A WebDAVError if the call was unsuccessful. `nil` if it was.
    /// - Returns: The upload task for the request.
    @discardableResult
    func upload<A: WebDAVAccount>(data: Data, toPath path: String, account: A, password: String, completion: @escaping (_ error: WebDAVError?) -> Void) -> URLSessionUploadTask? {
        guard let request = authorizedRequest(path: path, account: account, password: password, method: .put) else {
            completion(.invalidCredentials)
            return nil
        }
        
        let task = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil).uploadTask(with: request, from: data) { _, response, error in
            completion(WebDAVError.getError(response: response, error: error))
        }
        
        task.resume()
        return task
    }
    /// Upload a file to the specified file path.
    /// - Parameters:
    ///   - file: The path to the file to upload.
    ///   - path: The path, including file name and extension, to upload the file to.
    ///   - account: The WebDAV account.
    ///   - password: The WebDAV account's password.
    ///   - completion: If account properties are invalid, this will run immediately on the same thread.
    ///   Otherwise, it runs when the nextwork call finishes on a background thread.
    ///   - error: A WebDAVError if the call was unsuccessful. `nil` if it was.
    /// - Returns: The upload task for the request.
    @discardableResult
    func upload<A: WebDAVAccount>(file: URL, toPath path: String, account: A, password: String, completion: @escaping (_ error: WebDAVError?) -> Void) -> URLSessionUploadTask? {
        guard let request = authorizedRequest(path: path, account: account, password: password, method: .put) else {
            completion(.invalidCredentials)
            return nil
        }
        
        let task = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil).uploadTask(with: request, fromFile: file) { _, response, error in
            completion(WebDAVError.getError(response: response, error: error))
        }
        
        task.resume()
        return task
    }
    
    /// Download data from the specified file path.
    /// - Parameters:
    ///   - path: The path of the file to download.
    ///   - account: The WebDAV account.
    ///   - password: The WebDAV account's password.
    ///   - completion: If account properties are invalid, this will run immediately on the same thread.
    ///   Otherwise, it runs when the nextwork call finishes on a background thread.
    ///   - data: The data of the file downloaded, if successful.
    ///   - error: A WebDAVError if the call was unsuccessful. `nil` if it was.
    /// - Returns: The data task for the request.
    @discardableResult
    func download<A: WebDAVAccount>(fileAtPath path: String, account: A, password: String, caching options: WebDAVCachingOptions = [], completion: @escaping (_ data: Data?, _ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
        cachingDataTask(cache: dataCache, path: path, account: account, password: password, caching: options, valueFromData: { $0 }, completion: completion)
    }
    
    /// Create a folder at the specified path
    /// - Parameters:
    ///   - path: The path to create a folder at.
    ///   - account: The WebDAV account.
    ///   - password: The WebDAV account's password.
    ///   - completion: If account properties are invalid, this will run immediately on the same thread.
    ///   Otherwise, it runs when the nextwork call finishes on a background thread.
    ///   - error: A WebDAVError if the call was unsuccessful. `nil` if it was.
    /// - Returns: The data task for the request.
    @discardableResult
    func createFolder<A: WebDAVAccount>(atPath path: String, account: A, password: String, completion: @escaping (_ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
        basicDataTask(path: path, account: account, password: password, method: .mkcol, completion: completion)
    }
    
    /// Delete the file or folder at the specified path.
    /// - Parameters:
    ///   - path: The path of the file or folder to delete.
    ///   - account: The WebDAV account.
    ///   - password: The WebDAV account's password.
    ///   - completion: If account properties are invalid, this will run immediately on the same thread.
    ///   Otherwise, it runs when the nextwork call finishes on a background thread.
    ///   - error: A WebDAVError if the call was unsuccessful. `nil` if it was.
    /// - Returns: The data task for the request.
    @discardableResult
    func deleteFile<A: WebDAVAccount>(atPath path: String, account: A, password: String, completion: @escaping (_ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
        basicDataTask(path: path, account: account, password: password, method: .delete, completion: completion)
    }
    
    /// Move the file to the specified destination.
    /// - Parameters:
    ///   - path: The original path of the file.
    ///   - destination: The desired destination path of the file.
    ///   - account: The WebDAV account.
    ///   - password: The WebDAV account's password.
    ///   - completion: If account properties are invalid, this will run immediately on the same thread.
    ///   Otherwise, it runs when the nextwork call finishes on a background thread.
    ///   - error: A WebDAVError if the call was unsuccessful. `nil` if it was.
    /// - Returns: The data task for the request.
    @discardableResult
    func moveFile<A: WebDAVAccount>(fromPath path: String, to destination: String, account: A, password: String, completion: @escaping (_ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
        basicDataTask(path: path, destination: destination, account: account, password: password, method: .move, completion: completion)
    }
    
    /// Copy the file to the specified destination.
    /// - Parameters:
    ///   - path: The original path of the file.
    ///   - destination: The desired destination path of the copy.
    ///   - account: The WebDAV account.
    ///   - password: The WebDAV account's password.
    ///   - completion: If account properties are invalid, this will run immediately on the same thread.
    ///   Otherwise, it runs when the nextwork call finishes on a background thread.
    ///   - error: A WebDAVError if the call was unsuccessful. `nil` if it was.
    /// - Returns: The data task for the request.
    @discardableResult
    func copyFile<A: WebDAVAccount>(fromPath path: String, to destination: String, account: A, password: String, completion: @escaping (_ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
        basicDataTask(path: path, destination: destination, account: account, password: password, method: .copy, completion: completion)
    }
    
    //MARK: Cache
    
    /// Deletes the cached data for a certain path.
    /// - Parameters:
    ///   - path: The path used to download the data.
    ///   - account: The WebDAV account used to download the data.
    /// - Throws: An error if the cached object URL couldn’t be created or the file can't be deleted.
    func deleteCachedData<A: WebDAVAccount>(forItemAtPath path: String, account: A) throws {
        let accountPath = AccountPath(account: account, path: path)
        dataCache.removeValue(forKey: accountPath)
        imageCache.removeValue(forKey: accountPath)
    }
    
    /// Get the URL used to store a resource for a certain path.
    /// Useful to find where a download image is located.
    /// - Parameters:
    ///   - path: The path used to download the data.
    ///   - account: The WebDAV account used to download the data.
    /// - Throws: An error if the URL couldn’t be created.
    /// - Returns: The URL where the resource is stored.
    func getCachedDataURL<A: WebDAVAccount>(forItemAtPath path: String, account: A) throws -> URL? {
        //TODO
        return nil
    }
    
    /// Deletes all downloaded data that has been cached.
    /// - Throws: An error if the resources couldn't be deleted.
    func deleteAllCachedData() throws {
        //TODO
    }
    
    /// Get the total disk space for the contents of the image cache.
    /// For a formatted string of the size, see `getCacheSize`.
    /// - Returns: The total allocated space of the cache in bytes.
    func getCacheByteCount() -> Int {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
              let urls = FileManager.default.enumerator(at: caches, includingPropertiesForKeys: nil)?.allObjects as? [URL] else { return 0 }
        
        return urls.lazy.reduce(0) { total, url -> Int in
            ((try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize) ?? 0) + total
        }
    }
    
    /// Get the total disk space for the contents of the image cache and display it as a localized
    /// description that is formatted with the appropriate byte modifier (KB, MB, GB and so on).
    ///
    /// This formats the size using this object's `byteCountFormatter` which can be modified.
    /// - Returns: A localized string of the total allocated space of the cache.
    func getCacheSize() -> String {
        byteCountFormatter.string(fromByteCount: Int64(getCacheByteCount()))
    }
    
    /// The URL to the directory of the depricated Networking image data cache.
    var networkingCacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("com.3lvis.networking")
    }
    
    /// The caching system has changed from WebDAV Swift v2 to v3.
    /// Run this function if upgrading from v2 to v3 to clear the old cache.
    /// - Throws: An error if the cache couldn't be deleted.
    func clearV2Cache() throws {
        guard let caches = networkingCacheURL,
              FileManager.default.fileExists(atPath: caches.path) else { return }
        try FileManager.default.removeItem(at: caches)
    }
    
    func clearFilesMemoryCache() {
        filesCache.removeAll()
    }
    
}

//MARK: Internal

extension WebDAV {
    
    //MARK: Standard Requests
    
    func cachingDataTask<A: WebDAVAccount, Value: Equatable>(cache: Cache<AccountPath, Value>, path: String, account: A, password: String, caching options: WebDAVCachingOptions, valueFromData: @escaping (_ data: Data) -> Value?, completion: @escaping (_ value: Value?, _ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
        
        // Check cache
        
        var cachedValue: Value?
        let accountPath = AccountPath(account: account, path: path)
        if !options.contains(.doNotReturnCachedResult) {
            if let value = cache[accountPath] {
                completion(value, nil)
                
                if !options.contains(.requestEvenIfCached) {
                    if options.contains(.removeExistingCache) {
                        cache.removeValue(forKey: accountPath)
                    }
                    return nil
                } else {
                    // Remember the cached completion. If the fetched results
                    // are the same, don't bother completing again.
                    cachedValue = value
                }
            }
        }
        
        if options.contains(.removeExistingCache) {
            cache.removeValue(forKey: accountPath)
        }
        
        // Create network request
        
        guard let request = authorizedRequest(path: path, account: account, password: password, method: .get) else {
            completion(nil, .invalidCredentials)
            return nil
        }
        
        // Perform network request
        
        let task = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil).dataTask(with: request) { data, response, error in
            let error = WebDAVError.getError(response: response, error: error)
            
            if let data = data,
               let value = valueFromData(data) {
                // Cache result
                //TODO: Cache to disk
                if !options.contains(.removeExistingCache),
                   !options.contains(.doNotCacheResult) {
                    cache.set(value, forKey: accountPath)
                }
                
                // Don't send a duplicate completion if the results are the same.
                if value != cachedValue {
                    completion(value, error)
                }
            } else {
                completion(nil, error)
            }
        }
        
        task.resume()
        return task
    }
    
    /// Creates a basic authentication credential.
    /// - Parameters:
    ///   - username: The username
    ///   - password: The password
    /// - Returns: A base-64 encoded credential if the provided credentials are valid (can be encoded as UTF-8).
    func auth(username: String, password: String) -> String? {
        let authString = username + ":" + password
        let authData = authString.data(using: .utf8)
        return authData?.base64EncodedString()
    }
    
    /// Creates an authorized URL request at the path and with the HTTP method specified.
    /// - Parameters:
    ///   - path: The path of the request
    ///   - account: The WebDAV account
    ///   - password: The WebDAV password
    ///   - method: The HTTP Method for the request.
    /// - Returns: The URL request if the credentials are valid (can be encoded as UTF-8).
    func authorizedRequest<A: WebDAVAccount>(path: String, account: A, password: String, method: HTTPMethod) -> URLRequest? {
        guard let unwrappedAccount = UnwrappedAccount(account: account),
              let auth = self.auth(username: unwrappedAccount.username, password: password) else { return nil }
        
        let url = unwrappedAccount.baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.addValue("Basic \(auth)", forHTTPHeaderField: "Authorization")
        
        return request
    }
    
    func basicDataTask<A: WebDAVAccount>(path: String, destination: String? = nil, account: A, password: String, method: HTTPMethod, completion: @escaping (_ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
        guard var request = authorizedRequest(path: path, account: account, password: password, method: method),
              let unwrappedAccount = UnwrappedAccount(account: account) else {
            completion(.invalidCredentials)
            return nil
        }
        
        if let destination = destination {
            let destionationURL = unwrappedAccount.baseURL.appendingPathComponent(destination)
            request.addValue(destionationURL.absoluteString, forHTTPHeaderField: "Destination")
        }
        
        let task = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil).dataTask(with: request) { data, response, error in
            completion(WebDAVError.getError(response: response, error: error))
        }
        
        task.resume()
        return task
    }
    
    //MARK: Pathing
    
    func nextcloudBaseURL(for baseURL: URL) -> URL? {
        guard baseURL.absoluteString.lowercased().contains("remote.php/dav/files/"),
              let index = baseURL.pathComponents.map({ $0.lowercased() }).firstIndex(of: "remote.php") else { return nil }
        
        // Remove Nextcloud files path components
        var previewURL = baseURL
        for _ in 0 ..< baseURL.pathComponents.count - index {
            previewURL.deleteLastPathComponent()
        }
        
        // Add Nextcloud thumbnail components
        return previewURL
    }
    
}
