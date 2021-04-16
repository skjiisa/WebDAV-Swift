//
//  WebDAVError.swift
//  WebDAV-Swift
//
//  Created by Isaac Lyons on 11/19/20.
//

import Foundation

public enum WebDAVError: Error {
    /// The credentials or path were unable to be encoded.
    /// No network request was called.
    case invalidCredentials
    /// The credentials were incorrect.
    case unauthorized
    /// The server was unable to store the data provided.
    case insufficientStorage
    /// The server does not support this feature.
    case unsupported
    /// Another unspecified Error occurred.
    case nsError(Error)
    
    static func getError(statusCode: Int?, error: Error?) -> WebDAVError? {
        if let statusCode = statusCode {
            switch statusCode {
            case 200...299: // Success
                return nil
            case 401...403:
                return .unauthorized
            case 507:
                return .insufficientStorage
            default:
                break
            }
        }
        
        if let error = error {
            return .nsError(error)
        }
        return nil
    }
    
    static func getError(response: URLResponse?, error: Error?) -> WebDAVError? {
        getError(statusCode: (response as? HTTPURLResponse)?.statusCode, error: error)
    }
}
