//
//  WebDAV.swift
//  WebDAV-Swift
//
//  Created by Isaac Lyons on 10/29/20.
//

import UIKit
import SWXMLHash
import Networking

public class WebDAV: NSObject, URLSessionDelegate {
    
    //MARK: Properties
    
    var networkings: [UnwrappedAccount: Networking] = [:]
    
    //MARK: WebDAV Requests
    
    /// List the files and directories at the specified path.
    /// - Parameters:
    ///   - path: The path to list files from.
    ///   - account: The WebDAV account.
    ///   - password: The WebDAV account's password.
    ///   - completion: If account properties are invalid, this will run immediately on the same thread.
    ///   Otherwise, it runs when the nextwork call finishes on a background thread.
    ///   - files: The files at the directory specified. `nil` if there was an error.
    ///   - error: A WebDAVError if the call was unsuccessful.
    /// - Returns: The data task for the request.
    @discardableResult
    public func listFiles<A: WebDAVAccount>(atPath path: String, account: A, password: String, completion: @escaping (_ files: [WebDAVFile]?, _ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
        guard var request = authorizedRequest(path: path, account: account, password: password, method: .propfind) else {
            completion(nil, .invalidCredentials)
            return nil
        }
        
        let body =
"""
<?xml version="1.0"?>
<d:propfind  xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns" xmlns:nc="http://nextcloud.org/ns">
  <d:prop>
        <d:getlastmodified />
        <d:getetag />
        <d:getcontenttype />
        <oc:fileid />
        <oc:permissions />
        <oc:size />
        <nc:has-preview />
        <oc:favorite />
  </d:prop>
</d:propfind>
"""
        request.httpBody = body.data(using: .utf8)
        
        let task = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil).dataTask(with: request) { data, response, error in
            
            let response = response as? HTTPURLResponse
            
            guard 200...299 ~= response?.statusCode ?? 0,
                  let data = data,
                  let string = String(data: data, encoding: .utf8) else {
                let webDAVError = WebDAVError.getError(statusCode: response?.statusCode, error: error)
                return completion(nil, webDAVError)
            }
            
            let xml = SWXMLHash.config { config in
                config.shouldProcessNamespaces = true
            }.parse(string)
            let files = xml["multistatus"]["response"].all.compactMap { WebDAVFile(xml: $0) }
            return completion(files, nil)
        }
        
        task.resume()
        return task
    }
    
    /// Upload data to the specified file path.
    /// - Parameters:
    ///   - data: The data of the file to upload.
    ///   - path: The path, including file name and extension, to upload the file to.
    ///   - account: The WebDAV account.
    ///   - password: The WebDAV account's password.
    ///   - completion: If account properties are invalid, this will run immediately on the same thread.
    ///   Otherwise, it runs when the nextwork call finishes on a background thread.
    ///   - error: A WebDAVError if the call was unsuccessful. `nil` if it was.
    /// - Returns: The upload task for the request.
    @discardableResult
    public func upload<A: WebDAVAccount>(data: Data, toPath path: String, account: A, password: String, completion: @escaping (_ error: WebDAVError?) -> Void) -> URLSessionUploadTask? {
        guard let request = authorizedRequest(path: path, account: account, password: password, method: .put) else {
            completion(.invalidCredentials)
            return nil
        }
        
        let task = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil).uploadTask(with: request, from: data) { _, response, error in
            completion(WebDAVError.getError(response: response, error: error))
        }
        
        task.resume()
        return task
    }
    /// Upload a file to the specified file path.
    /// - Parameters:
    ///   - file: The path to the file to upload.
    ///   - path: The path, including file name and extension, to upload the file to.
    ///   - account: The WebDAV account.
    ///   - password: The WebDAV account's password.
    ///   - completion: If account properties are invalid, this will run immediately on the same thread.
    ///   Otherwise, it runs when the nextwork call finishes on a background thread.
    ///   - error: A WebDAVError if the call was unsuccessful. `nil` if it was.
    /// - Returns: The upload task for the request.
    @discardableResult
    public func upload<A: WebDAVAccount>(file: URL, toPath path: String, account: A, password: String, completion: @escaping (_ error: WebDAVError?) -> Void) -> URLSessionUploadTask? {
        guard let request = authorizedRequest(path: path, account: account, password: password, method: .put) else {
            completion(.invalidCredentials)
            return nil
        }
        
        let task = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil).uploadTask(with: request, fromFile: file) { _, response, error in
            completion(WebDAVError.getError(response: response, error: error))
        }
        
        task.resume()
        return task
    }
    
    /// Download data from the specified file path.
    /// - Parameters:
    ///   - path: The path of the file to download.
    ///   - account: The WebDAV account.
    ///   - password: The WebDAV account's password.
    ///   - completion: If account properties are invalid, this will run immediately on the same thread.
    ///   Otherwise, it runs when the nextwork call finishes on a background thread.
    ///   - data: The data of the file downloaded, if successful.
    ///   - error: A WebDAVError if the call was unsuccessful. `nil` if it was.
    /// - Returns: The data task for the request.
    @discardableResult
    public func download<A: WebDAVAccount>(fileAtPath path: String, account: A, password: String, completion: @escaping (_ data: Data?, _ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
        guard let request = authorizedRequest(path: path, account: account, password: password, method: .get) else {
            completion(nil, .invalidCredentials)
            return nil
        }
        
        let task = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil).dataTask(with: request) { data, response, error in
            completion(data, WebDAVError.getError(response: response, error: error))
        }
        
        task.resume()
        return task
    }
    
    /// Create a folder at the specified path
    /// - Parameters:
    ///   - path: The path to create a folder at.
    ///   - account: The WebDAV account.
    ///   - password: The WebDAV account's password.
    ///   - completion: If account properties are invalid, this will run immediately on the same thread.
    ///   Otherwise, it runs when the nextwork call finishes on a background thread.
    ///   - error: A WebDAVError if the call was unsuccessful. `nil` if it was.
    /// - Returns: The data task for the request.
    @discardableResult
    public func createFolder<A: WebDAVAccount>(atPath path: String, account: A, password: String, completion: @escaping (_ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
        guard let request = authorizedRequest(path: path, account: account, password: password, method: .mkcol) else {
            completion(.invalidCredentials)
            return nil
        }
        
        let task = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil).dataTask(with: request) { data, response, error in
            completion(WebDAVError.getError(response: response, error: error))
        }
        
        task.resume()
        return task
    }
    
    /// Delete the file or folder at the specified path.
    /// - Parameters:
    ///   - path: The path of the file or folder to delete.
    ///   - account: The WebDAV account.
    ///   - password: The WebDAV account's password.
    ///   - completion: If account properties are invalid, this will run immediately on the same thread.
    ///   Otherwise, it runs when the nextwork call finishes on a background thread.
    ///   - error: A WebDAVError if the call was unsuccessful. `nil` if it was.
    /// - Returns: The data task for the request.
    @discardableResult
    public func deleteFile<A: WebDAVAccount>(atPath path: String, account: A, password: String, completion: @escaping (_ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
        guard let request = authorizedRequest(path: path, account: account, password: password, method: .delete) else {
            completion(.invalidCredentials)
            return nil
        }
        
        let task = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil).dataTask(with: request) { data, response, error in
            completion(WebDAVError.getError(response: response, error: error))
        }
        
        task.resume()
        return task
    }
    
    //MARK: Networking Requests
    // Somewhat confusing header title, but this refers to requests made using the Networking library
    
    /// Download and cache and image from the specified file path.
    /// - Parameters:
    ///   - path: The path of the image to download.
    ///   - account: The WebDAV account.
    ///   - password: The WebDAV account's password.
    ///   - completion: If account properties are invalid, this will run immediately on the same thread.
    ///   Otherwise, it runs when the nextwork call finishes on a background thread.
    ///   - image: The image downloaded, if successful.
    ///   The cached image if it has balready been downloaded.
    ///   - error: A WebDAVError if the call was unsuccessful. `nil` if it was.
    /// - Returns: The request identifier.
    @discardableResult
    public func downloadImage<A: WebDAVAccount>(path: String, account: A, password: String, completion: @escaping (_ image: UIImage?, _ error: WebDAVError?) -> Void) -> String? {
        guard let networking = self.networking(for: account, password: password) else {
            completion(nil, .invalidCredentials)
            return nil
        }
        
        let id = networking.downloadImage(path) { imageResult in
            switch imageResult {
            case .success(let imageResponse):
                completion(imageResponse.image, nil)
            case .failure(let response):
                completion(nil, WebDAVError.getError(statusCode: response.statusCode, error: response.error))
            }
        }
        
        return id
    }
    
    public func deleteCachedData<A: WebDAVAccount>(forItemAtPath path: String, account: A) throws {
        // It's OK to leave the password blank here, because it gets set before every call
        guard let networking = self.networking(for: account, password: "") else { return }
        let destinationURL = try networking.destinationURL(for: path)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(atPath: destinationURL.path)
        }
    }
    
    /// Cancel a request
    /// - Parameters:
    ///   - id: The identifier of the request.
    ///   - account: The WebDAV account the request was made on.
    public func cancelRequest<A: WebDAVAccount>(id: String, account: A) {
        guard let unwrappedAccount = UnwrappedAccount(account: account) else { return }
        networkings[unwrappedAccount]?.cancel(id)
    }
    
    //MARK: Private
    
    /// Creates a basic authentication credential.
    /// - Parameters:
    ///   - username: The username
    ///   - password: The password
    /// - Returns: A base-64 encoded credential if the provided credentials are valid (can be encoded as UTF-8).
    private func auth(username: String, password: String) -> String? {
        let authString = username + ":" + password
        let authData = authString.data(using: .utf8)
        return authData?.base64EncodedString()
    }
    
    /// Creates an authorized URL request at the path and with the HTTP method specified.
    /// - Parameters:
    ///   - path: The path of the request
    ///   - account: The WebDAV account
    ///   - password: The WebDAV password
    ///   - method: The HTTP Method for the request.
    /// - Returns: The URL request if the credentials are valid (can be encoded as UTF-8).
    private func authorizedRequest<A: WebDAVAccount>(path: String, account: A, password: String, method: HTTPMethod) -> URLRequest? {
        guard let unwrappedAccount = UnwrappedAccount(account: account),
              let auth = self.auth(username: unwrappedAccount.username, password: password) else { return nil }
        
        let url = unwrappedAccount.baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.addValue("Basic \(auth)", forHTTPHeaderField: "Authorization")
        
        return request
    }
    
    private func networking<A: WebDAVAccount>(for account: A, password: String) -> Networking? {
        guard let unwrappedAccount = UnwrappedAccount(account: account) else { return nil }
        let networking = networkings[unwrappedAccount] ?? {
            let networking = Networking(baseURL: unwrappedAccount.baseURL.absoluteString)
            networkings[unwrappedAccount] = networking
            return networking
        }()
        networking.setAuthorizationHeader(username: unwrappedAccount.username, password: password)
        return networking
    }
    
}
