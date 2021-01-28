//
//  WebDAVFile.swift
//  WebDAV-Swift
//
//  Created by Isaac Lyons on 11/16/20.
//

import Foundation
import SWXMLHash

public class WebDAVFile: NSObject, Identifiable {
    
    //MARK: Properties
    
    public var path: String
    public var id: String
    public var isDirectory: Bool
    public var lastModified: Date
    public var size: Int
    
    var etag: String
    
    init(path: String, id: String, isDirectory: Bool, lastModified: Date, size: Int, etag: String) {
        self.path = path
        self.id = id
        self.isDirectory = isDirectory
        self.lastModified = lastModified
        self.size = size
        self.etag = etag
    }
    
    convenience init?(xml: XMLIndexer, baseURL: String?) {
        let properties = xml["propstat"][0]["prop"]
        guard var path = xml["href"].element?.text,
              let dateString = properties["getlastmodified"].element?.text,
              let date = WebDAVFile.rfc1123Formatter.date(from: dateString),
              let id = properties["fileid"].element?.text,
              let sizeString = properties["size"].element?.text,
              let size = Int(sizeString),
              let etag = properties["getetag"].element?.text else { return nil }
        let isDirectory = properties["getcontenttype"].element?.text == nil
        
        if let baseURL = baseURL {
            path = WebDAVFile.removing(endOf: baseURL, from: path)
        }
        
        self.init(path: path, id: id, isDirectory: isDirectory, lastModified: date, size: size, etag: etag)
    }
    
    //MARK: Static
    
    static let rfc1123Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        return formatter
    }()
    
    private static func removing(endOf string1: String, from string2: String) -> String {
        guard let first = string2.first else { return string2 }
        
        for (i, c) in string1.enumerated() {
            guard c == first else { continue }
            let end = string1.dropFirst(i)
            if string2.hasPrefix(end) {
                return String(string2.dropFirst(end.count))
            }
        }
        
        return string2
    }
    
    //MARK: Public
    
    public override var description: String {
        path
            + (isDirectory ? "\tDirecotry" : "\tFile")
            + "\tLast modified \(WebDAVFile.rfc1123Formatter.string(from: lastModified))"
            + "\tID: " + id
            + "\tSize: \(size)"
    }
    
    public var name: String {
        let encodedName = URL(fileURLWithPath: path).lastPathComponent
        return encodedName.removingPercentEncoding ?? encodedName
    }
    
}
