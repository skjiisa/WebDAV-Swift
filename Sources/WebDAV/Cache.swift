//
//  Cache.swift
//  WebDAV-Swift
//
//  Created by Isaac Lyons on 4/8/21.
//

import Foundation

public final class Cache<Key: Hashable, Value> {
    
    //MARK: Private
    
    private let cache = NSCache<KeyWrapper, ContentWrapper>()
    
    private final class KeyWrapper: NSObject {
        let key: Key
        
        init(_ key: Key) {
            self.key = key
        }
        
        override var hash: Int {
            key.hashValue
        }
        
        override func isEqual(_ object: Any?) -> Bool {
            guard let value = object as? KeyWrapper else { return false }
            return value.key == key
        }
    }
    
    private final class ContentWrapper {
        let value: Value
        
        init(_ value: Value) {
            self.value = value
        }
    }
    
    //MARK: Public
    
    internal func value(forKey key: Key) -> Value? {
        guard let entry = cache.object(forKey: KeyWrapper(key)) else { return nil }
        return entry.value
    }
    
    internal func set(_ value: Value, forKey key: Key) {
        let entry = ContentWrapper(value)
        cache.setObject(entry, forKey: KeyWrapper(key))
    }
    
    internal func removeValue(forKey key: Key) {
        cache.removeObject(forKey: KeyWrapper(key))
    }
    
    internal func removeAllValues() {
        cache.removeAllObjects()
    }
    
    internal subscript(key: Key) -> Value? {
        get { value(forKey: key) }
        set {
            guard let value = newValue else {
                return removeValue(forKey: key)
            }
            set(value, forKey: key)
        }
    }
}
