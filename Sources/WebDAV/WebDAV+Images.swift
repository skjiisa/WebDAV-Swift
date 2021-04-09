//
//  WebDAV+Images.swift
//  WebDAV-Swift
//
//  Created by Isaac Lyons on 4/9/21.
//

import UIKit

//MARK: ThumbnailProperties

public struct ThumbnailProperties: Hashable {
    public var width: Int?
    public var height: Int?
    public var contentMode: ContentMode
    
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
        //TODO
        return nil
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
    
    func nextcloudPreviewPath(at path: String, with dimensions: CGSize?, aspectFill: Bool = true) -> String? {
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
    
}
