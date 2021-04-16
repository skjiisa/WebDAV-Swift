//
//  WebDAV+Images.swift
//  WebDAV-Swift
//
//  Created by Isaac Lyons on 4/9/21.
//

import UIKit

//MARK: ThumbnailProperties

public struct ThumbnailProperties: Hashable {
    private var width: Int?
    private var height: Int?
    
    public var contentMode: ContentMode
    
    public var size: (width: Int, height: Int)? {
        get {
            if let width = width,
               let height = height {
                return (width, height)
            }
            return nil
        }
        set {
            width = newValue?.width
            height = newValue?.height
        }
    }
    
    /// Configurable default thumbnail properties. Initial value of content fill and server default dimensions.
    public static var `default` = ThumbnailProperties(contentMode: .fill)
    /// Content fill with the server's default dimensions.
    public static let fill = ThumbnailProperties(contentMode: .fill)
    /// Content fit with the server's default dimensions.
    public static let fit = ThumbnailProperties(contentMode: .fit)
    
    /// Constants that define how the thumbnail fills the dimensions.
    public enum ContentMode: Hashable {
        case fill
        case fit
    }
    
    /// - Parameters:
    ///   - size: The size of the thumbnail. A nil value will use the server's default dimensions.
    ///   - contentMode: A flag that indicates whether the thumbnail view fits or fills the dimensions.
    public init(_ size: (width: Int, height: Int)? = nil, contentMode: ThumbnailProperties.ContentMode) {
        if let size = size {
            width = size.width
            height = size.height
        }
        self.contentMode = contentMode
    }
    
    /// - Parameters:
    ///   - size: The size of the thumbnail. Width and height will be trucated to integer pixel counts.
    ///   - contentMode: A flag that indicates whether the thumbnail view fits or fills the image of the given dimensions.
    public init(size: CGSize, contentMode: ThumbnailProperties.ContentMode) {
        width = Int(size.width)
        height = Int(size.height)
        self.contentMode = contentMode
    }
}

//MARK: Public

public extension WebDAV {
    
    //MARK: Images
    
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
    func downloadImage<A: WebDAVAccount>(path: String, account: A, password: String, caching options: WebDAVCachingOptions = [], completion: @escaping (_ image: UIImage?, _ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
        cachingDataTask(cache: imageCache, path: path, account: account, password: password, caching: options, valueFromData: { UIImage(data: $0) }, completion: completion)
    }
    
    //MARK: Thumbnails
    
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
    func downloadThumbnail<A: WebDAVAccount>(
        path: String, account: A, password: String, with properties: ThumbnailProperties = .default,
        caching options: WebDAVCachingOptions = [], completion: @escaping (_ image: UIImage?, _ error: WebDAVError?) -> Void
    ) -> URLSessionDataTask? {
        // This function looks a lot like cachingDataTask and authorizedRequest,
        // but generalizing both of those to support thumbnails would make them
        // so much more complicated that it's better to just have similar code here.
        
        // Check cache
        
        var cachedThumbnail: UIImage?
        let accountPath = AccountPath(account: account, path: path)
        if !options.contains(.doNotReturnCachedResult) {
            if let thumbnail = thumbnailCache[accountPath]?[properties] {
                completion(thumbnail, nil)
                
                if !options.contains(.requestEvenIfCached) {
                    if options.contains(.removeExistingCache) {
                        try? deleteCachedThumbnail(forItemAtPath: path, account: account, with: properties)
                    }
                    return nil
                } else {
                    cachedThumbnail = thumbnail
                }
            }
        }
        
        if options.contains(.removeExistingCache) {
            try? deleteCachedThumbnail(forItemAtPath: path, account: account, with: properties)
        }
        
        // Create Network request
        
        guard let unwrappedAccount = UnwrappedAccount(account: account), let auth = self.auth(username: unwrappedAccount.username, password: password) else {
            completion(nil, .invalidCredentials)
            return nil
        }
        
        guard let url = nextcloudPreviewURL(for: unwrappedAccount.baseURL, at: path, with: properties) else {
            completion(nil, .unsupported)
            return nil
        }
        
        var request = URLRequest(url: url)
        request.addValue("Basic \(auth)", forHTTPHeaderField: "Authorization")
        
        // Perform the network request
        
        let task = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil).dataTask(with: request) { [weak self] data, response, error in
            let error = WebDAVError.getError(response: response, error: error)
            
            if let data = data,
               let thumbnail = UIImage(data: data) {
                // Cache result
                //TODO: Cache to disk
                if !options.contains(.removeExistingCache),
                   !options.contains(.doNotCacheResult) {
                    var cachedThumbnails = self?.thumbnailCache[accountPath] ?? [:]
                    cachedThumbnails[properties] = thumbnail
                    self?.thumbnailCache[accountPath] = cachedThumbnails
                }
                
                if thumbnail != cachedThumbnail {
                    completion(thumbnail, error)
                }
            } else {
                completion(nil, error)
            }
        }
        
        task.resume()
        return task
    }
    
    //MARK: Image Cache
    
    func getCachedImage<A: WebDAVAccount>(forItemAtPath path: String, account: A) -> UIImage? {
        getCachedValue(cache: imageCache, forItemAtPath: path, account: account, valueFromData: { UIImage(data: $0) })
    }
    
    //MARK: Thumbnail Cache
    
    func getAllCachedThumbnails<A: WebDAVAccount>(forItemAtPath path: String, account: A) -> [ThumbnailProperties: UIImage]? {
        getCachedValue(from: thumbnailCache, forItemAtPath: path, account: account)
    }
    
    func getCachedThumbnail<A: WebDAVAccount>(forItemAtPath path: String, account: A, with properties: ThumbnailProperties) -> UIImage? {
        getAllCachedThumbnails(forItemAtPath: path, account: account)?[properties]
    }
    
    func deleteCachedThumbnail<A: WebDAVAccount>(forItemAtPath path: String, account: A, with properties: ThumbnailProperties) throws {
        let accountPath = AccountPath(account: account, path: path)
        if var cachedThumbnails = thumbnailCache[accountPath] {
            cachedThumbnails.removeValue(forKey: properties)
            if cachedThumbnails.isEmpty {
                thumbnailCache.removeValue(forKey: accountPath)
            } else {
                thumbnailCache[accountPath] = cachedThumbnails
            }
        }
    }
    
    func deleteAllCachedThumbnails<A: WebDAVAccount>(forItemAtPath path: String, account: A) throws {
        let accountPath = AccountPath(account: account, path: path)
        thumbnailCache.removeValue(forKey: accountPath)
    }
    
}

//MARK: Internal

extension WebDAV {
    
    //MARK: Pathing
    
    func nextcloudPreviewBaseURL(for baseURL: URL) -> URL? {
        return nextcloudBaseURL(for: baseURL)?
            .appendingPathComponent("index.php")
            .appendingPathComponent("core")
            .appendingPathComponent("preview.png")
    }
    
    func nextcloudPreviewQuery(at path: String, properties: ThumbnailProperties) -> [URLQueryItem]? {
        var path = path
        
        if path.hasPrefix("/") {
            path.removeFirst()
        }
        
        var query = [
            URLQueryItem(name: "file", value: path),
            URLQueryItem(name: "mode", value: "cover")
        ]
        
        if let size = properties.size {
            query.append(URLQueryItem(name: "x", value: "\(size.width)"))
            query.append(URLQueryItem(name: "y", value: "\(size.height)"))
        }
        
        if properties.contentMode == .fill {
            query.append(URLQueryItem(name: "a", value: "1"))
        }
        
        return query
    }
    
    func nextcloudPreviewURL(for baseURL: URL, at path: String, with properties: ThumbnailProperties) -> URL? {
        guard let thumbnailURL = nextcloudPreviewBaseURL(for: baseURL) else { return nil }
        var components = URLComponents(string: thumbnailURL.absoluteString)
        components?.queryItems = nextcloudPreviewQuery(at: path, properties: properties)
        return components?.url
    }
    
}
