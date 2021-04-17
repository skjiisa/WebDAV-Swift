//
//  WebDAV+DiskCache.swift
//  WebDAV-Swift
//
//  Created by Isaac Lyons on 4/7/21.
//

import Foundation

//MARK: Public

public extension WebDAV {
    
    func cachedDataURL<A: WebDAVAccount>(forItemAtPath path: String, account: A) -> URL? {
        guard let encodedDescription = UnwrappedAccount(account: account)?.encodedDescription,
              let caches = cacheFolder else { return nil }
        return caches
            .appendingPathComponent(encodedDescription)
            .appendingPathComponent(path.trimmingCharacters(in: AccountPath.slash))
    }
    
    func cachedDataURLIfExists<A: WebDAVAccount>(forItemAtPath path: String, account: A) -> URL? {
        guard let url = cachedDataURL(forItemAtPath: path, account: account) else { return nil }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    
    func deleteCachedDataFromDisk<A: WebDAVAccount>(forItemAtPath path: String, account: A) throws {
        guard let url = cachedDataURLIfExists(forItemAtPath: path, account: account) else { return }
        try FileManager.default.removeItem(at: url)
    }
    
    func deleteAllDiskCachedData() throws {
        guard let url = cacheFolder else { return }
        let fm = FileManager.default
        let filesCachePath = filesCacheURL?.path
        for item in try fm.contentsOfDirectory(atPath: url.path) where item != filesCachePath {
            try fm.removeItem(atPath: url.appendingPathComponent(item).path)
        }
    }
    
}

//MARK: Internal

extension WebDAV {
    
    var cacheFolder: URL? {
        let fm = FileManager.default
        guard let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let directory = caches.appendingPathComponent(WebDAV.domain, isDirectory: true)

        if !fm.fileExists(atPath: directory.path) {
            do {
                try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                NSLog("\(error)")
                return nil
            }
        }
        return directory
    }
    
    //MARK: Data Cache
    
    func loadCachedValueFromDisk<A: WebDAVAccount, Value: Equatable>(cache: Cache<AccountPath, Value>, forItemAtPath path: String, account: A, valueFromData: @escaping (_ data: Data) -> Value?) -> Value? {
        guard let url = cachedDataURL(forItemAtPath: path, account: account),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let value = valueFromData(data) else { return nil }
        cache[AccountPath(account: account, path: path)] = value
        return value
    }
    
    func saveDataToDiskCache<A: WebDAVAccount>(_ data: Data, forItemAtPath path: String, account: A) throws {
        guard let url = cachedDataURL(forItemAtPath: path, account: account) else { return }
        let directory = url.deletingLastPathComponent()
        
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try data.write(to: url)
    }
    
    //MARK: Files Cache
    
    var filesCacheURL: URL? {
        cacheFolder?.appendingPathComponent("files.plist")
    }
    
    func saveFilesCacheToDisk() {
        guard let fileURL = filesCacheURL else { return }
        do {
            let data = try PropertyListEncoder().encode(filesCache)
            try data.write(to: fileURL)
        } catch {
            NSLog("Error saving files cache: \(error)")
        }
    }
    
    func loadFilesCacheFromDisk() {
        guard let fileURL = filesCacheURL,
              FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let files = try PropertyListDecoder().decode([AccountPath: [WebDAVFile]].self, from: data)
            filesCache.merge(files) { current, _ in current}
        } catch {
            NSLog("Error loading files cache: \(error)")
        }
    }
    
    public func clearFilesDiskCache() {
        guard let fileURL = filesCacheURL,
              FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            NSLog("Error removing files disk cache: \(error)")
        }
    }
    
    public func clearFilesCache() {
        clearFilesMemoryCache()
        clearFilesDiskCache()
    }
    
}
