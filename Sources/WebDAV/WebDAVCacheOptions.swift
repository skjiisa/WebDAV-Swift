//
//  WebDAVCacheOptions.swift
//  WebDAV-Swift
//
//  Created by Isaac Lyons on 4/6/21.
//

import Foundation

/// **Default behavior**:
/// If there is a cached result, return that instead of making a request.
/// Otherwise, make a request and cache the result.
struct WebDAVCacheOptions: OptionSet {
    let rawValue: Int
    
    /// Do not cache the results of this request, if one is made.
    static let doNotCacheResult         = WebDAVCacheOptions(rawValue: 1 << 0)
    /// Remove the cached value for this request.
    static let removeExistingCache      = WebDAVCacheOptions(rawValue: 1 << 1)
    /// If there is a cached result, ignore it and make a request.
    static let doNotReturnCachedResult  = WebDAVCacheOptions(rawValue: 1 << 2)
    /// If there is a cached result, return that, then make a request, returing that result again if it is different.
    static let requestEvenIfCached      = WebDAVCacheOptions(rawValue: 1 << 3)
    
    /// Disable all caching for this request including deleting any existing cache for it.
    /// Same as `[.doNotCacheResult, .removeExistingCache, .doNotReturnCachedResult]`.
    static let disableCache: WebDAVCacheOptions = [.doNotCacheResult, .removeExistingCache, .doNotReturnCachedResult]
    /// Ignore the cached result if there is one, and don't cache the new result.
    /// Same as `[.doNotCacheResult, .doNotReturnCachedResult]`.
    static let ignoreCache: WebDAVCacheOptions = [.doNotCacheResult, .doNotReturnCachedResult]
}
