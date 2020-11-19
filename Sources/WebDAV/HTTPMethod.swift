//
//  HTTPMethod.swift
//  WebDAV-Swift
//
//  Created by Isaac Lyons on 10/29/20.
//

internal enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case propfind = "PROPFIND"
    case mkcol = "MKCOL"
}
