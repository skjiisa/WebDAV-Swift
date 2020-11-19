//
//  WebDAV.swift
//  WebDAV-Swift
//
//  Created by Isaac Lyons on 10/29/20.
//

import Foundation
import SWXMLHash

public class WebDAV: NSObject, URLSessionDelegate {
    
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
    public func listFiles(atPath path: String, account: DAVAccount, password: String, completion: @escaping (_ files: [WebDAVFile]?, _ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
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
        
        let task = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil).dataTask(with: request) { [weak self] data, response, error in
            
            let response = response as? HTTPURLResponse
            
            guard 200...299 ~= response?.statusCode ?? 0,
                  let data = data,
                  let string = String(data: data, encoding: .utf8) else {
                let webDAVError = self?.getError(statusCode: response?.statusCode, error: error)
                return completion(nil, webDAVError)
            }
            
            let xml = SWXMLHash.config { config in
                config.shouldProcessNamespaces = true
            }.parse(string)
            let files = xml["multistatus"]["response"].all.compactMap { WebDAVFile(xml: $0) }
            print(files)
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
    public func upload(data: Data, toPath path: String, account: DAVAccount, password: String, completion: @escaping (_ error: WebDAVError?) -> Void) -> URLSessionUploadTask? {
        guard let request = authorizedRequest(path: path, account: account, password: password, method: .put) else {
            completion(.invalidCredentials)
            return nil
        }
        
        let task = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil).uploadTask(with: request, from: data) { [weak self] _, response, error in
            completion(self?.getError(statusCode: (response as? HTTPURLResponse)?.statusCode, error: error))
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
    ///   - completion: The block run upon completion.
    ///   If account properties are invalid, this will run almost immediately after.
    ///   Otherwise, it runs when the nextwork call finishes.
    ///   - success: Boolean indicating whether the upload was successful or not.
    /// - Returns: The upload task for the request.
    @discardableResult
    public func upload(file: URL, toPath path: String, account: DAVAccount, password: String, completion: @escaping (_ success: Bool) -> Void) -> URLSessionUploadTask? {
        guard let request = authorizedRequest(path: path, account: account, password: password, method: .put) else {
            completion(false)
            return nil
        }
        
        let task = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil).uploadTask(with: request, fromFile: file) { _, response, error in
            guard error == nil else { return completion(false) }
            completion(true)
        }
        
        task.resume()
        return task
    }
    
    /// Download data from the specified file path.
    /// - Parameters:
    ///   - path: The path of the file to download.
    ///   - account: The WebDAV account.
    ///   - password: The WebDAV account's password.
    ///   - completion: Returns the data if the download was successful.
    ///   - data: The data of the file downloaded, if successful.
    /// - Returns: The data task for the request.
    @discardableResult
    public func download(fileAtPath path: String, account: DAVAccount, password: String, completion: @escaping (_ data: Data?) -> Void) -> URLSessionDataTask? {
        guard let request = authorizedRequest(path: path, account: account, password: password, method: .get) else {
            completion(nil)
            return nil
        }
        
        let task = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil).dataTask(with: request) { data, response, error in
            completion(data)
        }
        
        task.resume()
        return task
    }
    
    /// Create a folder at the specified path
    /// - Parameters:
    ///   - path: The path to create a folder at.
    ///   - account: The WebDAV account.
    ///   - password: The WebDAV account's password.
    ///   - completion: Runs upon completion.
    ///   - success: Whether or not the folder was successfully created.
    /// - Returns: The data task for the request.
    @discardableResult
    public func createFolder(atPath path: String, account: DAVAccount, password: String, completion: @escaping (_ success: Bool) -> Void) -> URLSessionDataTask? {
        guard let request = authorizedRequest(path: path, account: account, password: password, method: .mkcol) else {
            completion(false)
            return nil
        }
        
        let task = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil).dataTask(with: request) { data, response, error in
            guard let response = response as? HTTPURLResponse,
                  200...299 ~= response.statusCode,
                  error == nil else { return completion(false) }
            
            completion(true)
        }
        
        task.resume()
        return task
    }
    
    /// Delete the file or folder at the specified path.
    /// - Parameters:
    ///   - path: The path of the file or folder to delete.
    ///   - account: The WebDAV account.
    ///   - password: The WebDAV account's password.
    ///   - completion: Runs upon completion.
    ///   - success: Whether or not the item was successfully deleted.
    /// - Returns: The data task for the request.
    @discardableResult
    public func deleteFile(atPath path: String, account: DAVAccount, password: String, completion: @escaping (_ success: Bool) -> Void) -> URLSessionDataTask? {
        guard let request = authorizedRequest(path: path, account: account, password: password, method: .delete) else {
            completion(false)
            return nil
        }
        
        let task = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil).dataTask(with: request) { data, response, error in
            guard let response = response as? HTTPURLResponse,
                  200...299 ~= response.statusCode,
                  error == nil else { return completion(false) }
            
            completion(true)
        }
        
        task.resume()
        return task
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
    private func authorizedRequest(path: String, account: DAVAccount, password: String, method: HTTPMethod) -> URLRequest? {
        guard let unwrappedAccount = UnwrappedAccount(account: account),
              let auth = self.auth(username: unwrappedAccount.username, password: password) else { return nil }
        
        let url = unwrappedAccount.baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.addValue("Basic \(auth)", forHTTPHeaderField: "Authorization")
        
        return request
    }
    
    private func getError(statusCode: Int?, error: Error?) -> WebDAVError? {
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
    
}
