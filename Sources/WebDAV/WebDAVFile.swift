//
//  WebDAVFile.swift
//  
//
//  Created by Isaac Lyons on 11/16/20.
//

import Foundation
import SWXMLHash

public class WebDAVFile: NSObject, Identifiable {
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
    
    convenience init?(xml: XMLIndexer) {
        let properties = xml["propstat"][0]["prop"]
        guard let path = xml["href"].element?.text,
              let dateString = properties["getlastmodified"].element?.text,
              let date = WebDAVFile.rfc1123Formatter.date(from: dateString),
              let id = properties["fileid"].element?.text,
              let sizeString = properties["size"].element?.text,
              let size = Int(sizeString),
              let etag = properties["getetag"].element?.text else { return nil }
        let isDirectory = properties["getcontenttype"].element?.text == nil
        
        self.init(path: path, id: id, isDirectory: isDirectory, lastModified: date, size: size, etag: etag)
    }
    
    static let rfc1123Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        return formatter
    }()
    
    public override var description: String {
        path
            + (isDirectory ? "\tDirecotry" : "\tFile")
            + "\tLast modified \(WebDAVFile.rfc1123Formatter.string(from: lastModified))"
            + "\tID: " + id
            + "\tSize: \(size)"
    }
}
