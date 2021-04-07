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
public struct WebDAVCacheOptions: OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    /// Do not cache the results of this request, if one is made.
    public static let doNotCacheResult         = WebDAVCacheOptions(rawValue: 1 << 0)
    /// Remove the cached value for this request.
    public static let removeExistingCache      = WebDAVCacheOptions(rawValue: 1 << 1)
    /// If there is a cached result, ignore it and make a request.
    public static let doNotReturnCachedResult  = WebDAVCacheOptions(rawValue: 1 << 2)
    /// If there is a cached result, return that, then make a request, returing that result again if it is different.
    public static let requestEvenIfCached      = WebDAVCacheOptions(rawValue: 1 << 3)
    
    /// Disable all caching for this request including deleting any existing cache for it.
    /// Same as `[.doNotCacheResult, .removeExistingCache, .doNotReturnCachedResult]`.
    public static let disableCache: WebDAVCacheOptions = [.doNotCacheResult, .removeExistingCache, .doNotReturnCachedResult]
    /// Ignore the cached result if there is one, and don't cache the new result.
    /// Same as `[.doNotCacheResult, .doNotReturnCachedResult]`.
    public static let ignoreCache: WebDAVCacheOptions = [.doNotCacheResult, .doNotReturnCachedResult]
}
