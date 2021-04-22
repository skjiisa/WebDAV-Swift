//
//  WebDAVCacheOptions.swift
//  WebDAV-Swift
//
//  Created by Isaac Lyons on 4/6/21.
//

import Foundation

/// **Default behavior** (empty set):
/// If there is a cached result, return that instead of making a request.
/// Otherwise, make a request and cache the result.
public struct WebDAVCachingOptions: OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    /// Do not cache the results of this request, if one is made.
    public static let doNotCacheResult         = WebDAVCachingOptions(rawValue: 1 << 0)
    /// Remove the cached value for this request.
    public static let removeExistingCache      = WebDAVCachingOptions(rawValue: 1 << 1)
    /// If there is a cached result, ignore it and make a request.
    public static let doNotReturnCachedResult  = WebDAVCachingOptions(rawValue: 1 << 2)
    /// If there is a cached result, return that, then make a request, returning that result again if it is different.
    public static let requestEvenIfCached      = WebDAVCachingOptions(rawValue: 1 << 3)
    
    /// Disable all caching for this request including deleting any existing cache for it.
    /// Same as `[.doNotCacheResult, .removeExistingCache, .doNotReturnCachedResult]`.
    public static let disableCache: WebDAVCachingOptions = [.doNotCacheResult, .removeExistingCache, .doNotReturnCachedResult]
    /// Ignore the cached result if there is one, and don't cache the new result.
    /// Same as `[.doNotCacheResult, .doNotReturnCachedResult]`.
    public static let ignoreCache: WebDAVCachingOptions = [.doNotCacheResult, .doNotReturnCachedResult]
}
