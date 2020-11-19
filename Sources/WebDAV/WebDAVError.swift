//
//  WebDAVError.swift
//  
//
//  Created by Isaac Lyons on 11/19/20.
//

import Foundation

public enum WebDAVError: Error {
    /// The DAVAccount was unable to be encoded to base 64.
    /// No network request was called.
    case invalidCredentials
    /// The credentials were incorrect.
    case unauthorized
    /// The server was unable to store the data provided.
    case insufficientStorage
    /// Another unspecified Error occurred.
    case nsError(Error)
}
