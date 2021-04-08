//
//  WebDAV.swift
//  WebDAV-Swift
//
//  Created by Isaac Lyons on 10/29/20.
//

import UIKit
import SWXMLHash
import Networking

public class WebDAV: NSObject, URLSessionDelegate {
    static let domain = "app.lyons.webdav-swift"
    
    //MARK: Properties
    
    /// The formatter used when rendering cache size in `getCacheSize`.
    public var byteCountFormatter = ByteCountFormatter()
    
    var networkings: [UnwrappedAccount: Networking] = [:]
    var thumbnailNetworkings: [UnwrappedAccount: Networking] = [:]
    public var filesCache: [AccountPath: [WebDAVFile]] = [:]
    
    public override init() {
        super.init()
        loadFilesCacheFromDisk()
    }
    
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
    public func listFiles<A: WebDAVAccount>(atPath path: String, account: A, password: String, foldersFirst: Bool = true, includeSelf: Bool = false, caching options: WebDAVCacheOptions = [], completion: @escaping (_ files: [WebDAVFile]?, _ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
        // Check the cache
        let accountPath = AccountPath(account: account, path: path)
        if !options.contains(.doNotReturnCachedResult) {
            if let files = filesCache[accountPath] {
                completion(WebDAV.sortedFiles(files, foldersFirst: foldersFirst, includeSelf: includeSelf), nil)
                
                if !options.contains(.requestEvenIfCached) {
                    return nil
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
            
            return completion(WebDAV.sortedFiles(files, foldersFirst: foldersFirst, includeSelf: includeSelf), nil)
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
    public func upload<A: WebDAVAccount>(data: Data, toPath path: String, account: A, password: String, completion: @escaping (_ error: WebDAVError?) -> Void) -> URLSessionUploadTask? {
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
    public func upload<A: WebDAVAccount>(file: URL, toPath path: String, account: A, password: String, completion: @escaping (_ error: WebDAVError?) -> Void) -> URLSessionUploadTask? {
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
    public func download<A: WebDAVAccount>(fileAtPath path: String, account: A, password: String, completion: @escaping (_ data: Data?, _ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
        guard let request = authorizedRequest(path: path, account: account, password: password, method: .get) else {
            completion(nil, .invalidCredentials)
            return nil
        }
        
        let task = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil).dataTask(with: request) { data, response, error in
            completion(data, WebDAVError.getError(response: response, error: error))
        }
        
        task.resume()
        return task
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
    public func createFolder<A: WebDAVAccount>(atPath path: String, account: A, password: String, completion: @escaping (_ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
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
    public func deleteFile<A: WebDAVAccount>(atPath path: String, account: A, password: String, completion: @escaping (_ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
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
    public func moveFile<A: WebDAVAccount>(fromPath path: String, to destination: String, account: A, password: String, completion: @escaping (_ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
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
    public func copyFile<A: WebDAVAccount>(fromPath path: String, to destination: String, account: A, password: String, completion: @escaping (_ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
        basicDataTask(path: path, destination: destination, account: account, password: password, method: .copy, completion: completion)
    }
    
    //MARK: Networking Requests
    // Somewhat confusing header title, but this refers to requests made using the Networking library
    
    /// Download and cache an image from the specified file path.
    /// - Parameters:
    ///   - path: The path of the image to download.
    ///   - account: The WebDAV account.
    ///   - password: The WebDAV account's password.
    ///   - completion: If account properties are invalid, this will run immediately on the same thread.
    ///   Otherwise, it runs when the nextwork call finishes on a background thread.
    ///   - image: The image downloaded, if successful.
    ///   The cached image if it has balready been downloaded.
    ///   - cachedImageURL: The URL of the cached image.
    ///   - error: A WebDAVError if the call was unsuccessful. `nil` if it was.
    /// - Returns: The request identifier.
    @discardableResult
    public func downloadImage<A: WebDAVAccount>(path: String, account: A, password: String, completion: @escaping (_ image: UIImage?, _ cachedImageURL: URL?, _ error: WebDAVError?) -> Void) -> String? {
        guard let networking = self.networking(for: account, password: password),
              let path = networkingPath(path) else {
            completion(nil, nil, .invalidCredentials)
            return nil
        }
        
        let id = networking.downloadImage(path) { imageResult in
            switch imageResult {
            case .success(let imageResponse):
                let path = try? networking.destinationURL(for: path)
                completion(imageResponse.image, path, nil)
            case .failure(let response):
                completion(nil, nil, WebDAVError.getError(statusCode: response.statusCode, error: response.error))
            }
        }
        
        return id
    }
    
    /// Download and cache an image's thumbnail from the specified file path.
    ///
    /// Only works with Nextcould or other instances that use Nextcloud's same thumbnail URL structure.
    /// - Parameters:
    ///   - path: The path of the image to download the thumbnail of.
    ///   - account: The WebDAV account.
    ///   - password: The WebDAV account's password.
    ///   - dimensions: The dimensions of the thumbnail. A value of `nil` will use the server's default.
    ///   - aspectFill: Whether the thumbnail should fill the dimensions or fit within it.
    ///   - completion: If account properties are invalid, this will run immediately on the same thread.
    ///   Otherwise, it runs when the nextwork call finishes on a background thread.
    ///   - image: The thumbnail downloaded, if successful.
    ///   The cached thumbnail if it has balready been downloaded.
    ///   - cachedImageURL: The URL of the cached thumbnail.
    ///   - error: A WebDAVError if the call was unsuccessful. `nil` if it was.
    /// - Returns: The request identifier.
    @discardableResult
    public func downloadThumbnail<A: WebDAVAccount>(
        path: String, account: A, password: String, with dimensions: CGSize?, aspectFill: Bool = true,
        completion: @escaping (_ image: UIImage?, _ cachedImageURL: URL?, _ error: WebDAVError?) -> Void
    ) -> String? {
        guard let networking = thumbnailNetworking(for: account, password: password),
              let path = nextcloudPreviewPath(at: path, with: dimensions, aspectFill: aspectFill) else {
            completion(nil, nil, .invalidCredentials)
            return nil
        }
        
        let id = networking.downloadImage(path) { imageResult in
            switch imageResult {
            case .success(let imageResponse):
                let path = try? networking.destinationURL(for: path)
                completion(imageResponse.image, path, nil)
            case .failure(let response):
                completion(nil, nil, WebDAVError.getError(statusCode: response.statusCode, error: response.error))
            }
        }
        
        return id
    }
    
    /// Deletes the cached data for a certain path.
    /// - Parameters:
    ///   - path: The path used to download the data.
    ///   - account: The WebDAV account used to download the data.
    /// - Throws: An error if the cached object URL couldn’t be created or the file can't be deleted.
    public func deleteCachedData<A: WebDAVAccount>(forItemAtPath path: String, account: A) throws {
        // It's OK to leave the password blank here, because it gets set before every call
        guard let networking = self.networking(for: account, password: ""),
              let path = networkingPath(path) else { return }
        
        let destinationURL = try networking.destinationURL(for: path)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(atPath: destinationURL.path)
        }
    }
    
    /// Get the URL used to store a resource for a certain path.
    /// Useful to find where a download image is located.
    /// - Parameters:
    ///   - path: The path used to download the data.
    ///   - account: The WebDAV account used to download the data.
    /// - Throws: An error if the URL couldn’t be created.
    /// - Returns: The URL where the resource is stored.
    public func getCachedDataURL<A: WebDAVAccount>(forItemAtPath path: String, account: A) throws -> URL? {
        guard let path = networkingPath(path) else { return nil }
        return try self.networking(for: account, password: "")?.destinationURL(for: path)
    }
    
    /// Get the image cached for a certain path.
    /// - Parameters:
    ///   - path: The path used to download the image.
    ///   - account: The WebDAV account used to download the image.
    /// - Returns: The image, if it is in the cache.
    public func getCachedImage<A: WebDAVAccount>(forItemAtPath path: String, account: A) -> UIImage? {
        guard let path = networkingPath(path) else { return nil }
        return self.networking(for: account, password: "")?.imageFromCache(path)
    }
    
    /// Delete a specific cached thumbnail for a certain path and properties.
    /// - Parameters:
    ///   - path: The path of the image to delete the thumbnail of.
    ///   - account: The WebDAV account used to download the data.
    ///   - dimensions: The dimensions of the thumbnail to delete.
    ///   - aspectFill: Whether the thumbnail was fetched with aspectFill.
    /// - Throws: An error if the cached data URL couldn’t be created or the file couldn't be deleted.
    public func deleteCachedThumbnail<A: WebDAVAccount>(forItemAtPath path: String, account: A, with dimensions: CGSize?, aspectFill: Bool) throws {
        guard let networking = thumbnailNetworking(for: account, password: ""),
              let path = nextcloudPreviewPath(at: path, with: dimensions, aspectFill: aspectFill) else { return }
        
        let destinationURL = try networking.destinationURL(for: path)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(atPath: destinationURL.path)
        }
    }
    
    /// Delete all cached thumbnails for a certain path.
    /// - Parameters:
    ///   - path: The path of the image to delete the thumbnails of.
    ///   - account: The WebDAV account used to download the thumbnails.
    /// - Throws: An error if the cached thumbnail URLs couldn’t be created or the files couldn't be deleted.
    public func deleteAllCachedThumbnails<A: WebDAVAccount>(forItemAtPath path: String, account: A) throws {
        try getAllCachedThumbnailURLs(forItemAtPath: path, account: account).forEach { url in
            try FileManager.default.remove(at: url)
        }
    }
    
    /// Get the URLs for the cached thumbnails for a certain path.
    /// - Parameters:
    ///   - path: The path used to download the thumbnails.
    ///   - account: The WebDAV account used to download the thumbnails.
    /// - Throws: An error if the cached thumbail URLs couldn't be created or the caches folder couldn't be accessed.
    /// - Returns: An array of the URLs of cached thumbnails for the given path.
    public func getAllCachedThumbnailURLs<A: WebDAVAccount>(forItemAtPath path: String, account: A) throws -> [URL] {
        // Getting the path with no dimensions and aspect fit will give the shortest form of the path with no extras added.
        guard let networking = thumbnailNetworking(for: account, password: ""),
              let path = nextcloudPreviewPath(at: path, with: nil, aspectFill: false),
              let networkingCacheURL = networkingCacheURL else { return [] }
        
        let destinationURL = try networking.destinationURL(for: path)
        let name = destinationURL.deletingPathExtension().lastPathComponent
        
        return try FileManager.default.contentsOfDirectory(at: networkingCacheURL, includingPropertiesForKeys: [], options: []).filter { url -> Bool in
            // Any cached thumbnail is going to start with this name.
            // It might also have dimensions and/or the aspect fill property after.
            url.lastPathComponent.starts(with: name)
        }
    }
    
    public func getAllCachedThumbnails<A: WebDAVAccount>(forItemAtPath path: String, account: A) throws -> [UIImage] {
        // We can't use imageFromCache(path) to get the images from a memory cache
        // because we can't generate the path for every possible thumbnail. Instead
        // we'll get the URLs from getAllCachedThumbnailURLs and get the data from those.
        try getAllCachedThumbnailURLs(forItemAtPath: path, account: account).compactMap { url -> UIImage? in
            UIImage(data: try Data(contentsOf: url))
        }
    }
    
    /// Get the URL for the cached thumbnail for a certain path and properties.
    /// Useful to find where a download thumbnail is located.
    /// - Parameters:
    ///   - path: The path used to download the thumbnail.
    ///   - account: The WebDAV account used to download the thumbnail.
    ///   - dimensions: The dimensions of the thumbnail to get.
    ///   - aspectFill: Whether the thumbnail was fetched with aspectFill.
    /// - Throws: An error if the cached data URL couldn’t be created.
    /// - Returns: The URL where the thumbnail has been stored.
    public func getCachedThumbnailURL<A: WebDAVAccount>(forItemAtPath path: String, account: A, with dimensions: CGSize?, aspectFill: Bool) throws -> URL? {
        guard let path = nextcloudPreviewPath(at: path, with: dimensions, aspectFill: aspectFill) else { return nil }
        return try thumbnailNetworking(for: account, password: "")?.destinationURL(for: path)
    }
    
    /// Get the thumbnail cached for a certain path and properties.
    /// - Parameters:
    ///   - path: The path used to download the thumbnail.
    ///   - account: The WebDAV account used to download the thumbnail.
    ///   - dimensions: The dimensions of the thumbnail to get.
    ///   - aspectFill: Whether the thumbnail was fetched with aspectFill.
    /// - Returns: The thumbnail, if it is in the cache.
    public func getCachedThumbnail<A: WebDAVAccount>(forItemAtPath path: String, account: A, with dimensions: CGSize?, aspectFill: Bool) -> UIImage? {
        guard let path = nextcloudPreviewPath(at: path, with: dimensions, aspectFill: aspectFill) else { return nil }
        return self.thumbnailNetworking(for: account, password: "")?.imageFromCache(path)
    }
    
    /// Deletes all downloaded data that has been cached.
    /// - Throws: An error if the resources couldn't be deleted.
    public func deleteAllCachedData() throws {
        guard let caches = networkingCacheURL else { return }
        try FileManager.default.remove(at: caches)
    }
    
    /// Cancel a request.
    /// - Parameters:
    ///   - id: The identifier of the request.
    ///   - account: The WebDAV account the request was made on.
    public func cancelRequest<A: WebDAVAccount>(id: String, account: A) {
        guard let unwrappedAccount = UnwrappedAccount(account: account) else { return }
        networkings[unwrappedAccount]?.cancel(id)
        thumbnailNetworkings[unwrappedAccount]?.cancel(id)
    }
    
    /// Get the total disk space for the contents of the image cache.
    /// For a formatted string of the size, see `getCacheSize`.
    /// - Returns: The total allocated space of the cache in bytes.
    public func getCacheByteCount() -> Int {
        guard let caches = networkingCacheURL,
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
    public func getCacheSize() -> String {
        byteCountFormatter.string(fromByteCount: Int64(getCacheByteCount()))
    }
    
    /// The URL to the directory that contains the cached image data.
    public var networkingCacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("com.3lvis.networking")
    }
    
    //MARK: Cache
    
    public func clearFilesMemoryCache() {
        filesCache.removeAll()
    }
    
    //MARK: Internal
    
    /// Creates a basic authentication credential.
    /// - Parameters:
    ///   - username: The username
    ///   - password: The password
    /// - Returns: A base-64 encoded credential if the provided credentials are valid (can be encoded as UTF-8).
    internal func auth(username: String, password: String) -> String? {
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
    internal func authorizedRequest<A: WebDAVAccount>(path: String, account: A, password: String, method: HTTPMethod) -> URLRequest? {
        guard let unwrappedAccount = UnwrappedAccount(account: account),
              let auth = self.auth(username: unwrappedAccount.username, password: password) else { return nil }
        
        let url = unwrappedAccount.baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.addValue("Basic \(auth)", forHTTPHeaderField: "Authorization")
        
        return request
    }
    
    internal func basicDataTask<A: WebDAVAccount>(path: String, destination: String? = nil, account: A, password: String, method: HTTPMethod, completion: @escaping (_ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
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
    
    internal func networking<A: WebDAVAccount>(for account: A, password: String) -> Networking? {
        guard let unwrappedAccount = UnwrappedAccount(account: account) else { return nil }
        let networking = networkings[unwrappedAccount] ?? {
            let networking = Networking(baseURL: unwrappedAccount.baseURL.absoluteString)
            networkings[unwrappedAccount] = networking
            return networking
        }()
        networking.setAuthorizationHeader(username: unwrappedAccount.username, password: password)
        return networking
    }
    
    internal func nextcloudBaseURL(for baseURL: URL) -> URL? {
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
    
    internal func nextcloudPreviewBaseURL(for baseURL: URL) -> URL? {
        return nextcloudBaseURL(for: baseURL)?
            .appendingPathComponent("index.php")
            .appendingPathComponent("core")
            .appendingPathComponent("preview.png")
    }
    
    internal func thumbnailNetworking<A: WebDAVAccount>(for account: A, password: String) -> Networking? {
        guard let unwrappedAccount = UnwrappedAccount(account: account),
              let previewURL = nextcloudPreviewBaseURL(for: unwrappedAccount.baseURL) else { return nil }
        
        let networking = thumbnailNetworkings[unwrappedAccount] ?? {
            let networking = Networking(baseURL: previewURL.absoluteString)
            thumbnailNetworkings[unwrappedAccount] = networking
            return networking
        }()
        
        networking.setAuthorizationHeader(username: unwrappedAccount.username, password: password)
        return networking
    }
    
    internal func networkingPath(_ path: String) -> String? {
        let slashPath = path.first == "/" ? path : "/" + path
        return slashPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
    }
    
    internal func nextcloudPreviewPath(at path: String, with dimensions: CGSize?, aspectFill: Bool = true) -> String? {
        guard var encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        
        if encodedPath.hasPrefix("/") {
            encodedPath.removeFirst()
        }
        
        var thumbnailPath = "?file=\(encodedPath)&mode=cover"
        
        if let dimensions = dimensions {
            thumbnailPath += "&x=\(dimensions.width)&y=\(dimensions.height)"
        }
        
        if aspectFill {
            thumbnailPath += "&a=1"
        }
        
        return thumbnailPath
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
