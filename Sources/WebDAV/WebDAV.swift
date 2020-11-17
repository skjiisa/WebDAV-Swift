//
//  WebDAV.swift
//  WebDAV-Swift
//
//  Created by Isaac Lyons on 10/29/20.
//

import Foundation
import SWXMLHash

public class WebDAV: NSObject, URLSessionDelegate {
    
    /// List the files and directories at the specified path.
    /// - Parameters:
    ///   - path: The path to list files from.
    ///   - account: The WebDAV account.
    ///   - password: The WebDAV account's password.
    ///   - completion: The block run upon completion.
    ///   If account properties are invalid, this will run almost immediately after.
    ///   Otherwise, it runs when the nextwork call finishes.
    ///   - files: The files at the directory specified. `nil` if there was an error.
    /// - Returns: The data task for the request.
    @discardableResult
    public func listFiles(atPath path: String, account: Account, password: String, completion: @escaping (_ files: [WebDAVFile]?) -> Void) -> URLSessionDataTask? {
        guard var request = authorizedRequest(path: path, account: account, password: password, method: .propfind) else {
            completion(nil)
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
        
        let task = URLSession(configuration: .default, delegate: self, delegateQueue: nil).dataTask(with: request) { data, response, error in
            guard let response = response as? HTTPURLResponse,
                  200...299 ~= response.statusCode else { return completion(nil) }
            
            if let data = data,
               let string = String(data: data, encoding: .utf8) {
                let xml = SWXMLHash.config { config in
                    config.shouldProcessNamespaces = true
                }.parse(string)
                let files = xml["multistatus"]["response"].all.compactMap { WebDAVFile(xml: $0) }
                print(files)
                return completion(files)
            }
            
            completion(nil)
        }
        
        task.resume()
        return task
    }
    
    /// Upload a file to the specified file path.
    /// - Parameters:
    ///   - data: The data of the file to upload.
    ///   - path: The path, including file name and extension, to upload the file to.
    ///   - account: The WebDAV account.
    ///   - password: The WebDAV account's password.
    ///   - completion: The block run upon completion.
    ///   If account properties are invalid, this will run almost immediately after.
    ///   Otherwise, it runs when the nextwork call finishes.
    ///   - success: Boolean indicating whether the upload was successful or not.
    /// - Returns: The upload task for the request.
    @discardableResult
    public func upload(data: Data, toPath path: String, account: Account, password: String, completion: @escaping (_ success: Bool) -> Void) -> URLSessionUploadTask? {
        guard let request = authorizedRequest(path: path, account: account, password: password, method: .put) else {
            completion(false)
            return nil
        }
        
        let task = URLSession(configuration: .default, delegate: self, delegateQueue: nil).uploadTask(with: request, from: data) { _, response, error in
            guard error == nil else { return completion(false) }
            completion(true)
        }
        
        task.resume()
        return task
    }
    
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
    private func authorizedRequest(path: String, account: Account, password: String, method: HTTPMethod) -> URLRequest? {
        guard let unwrappedAccount = UnwrappedAccount(account: account),
              let auth = self.auth(username: unwrappedAccount.username, password: password) else { return nil }
        
        let url = unwrappedAccount.baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.addValue("Basic \(auth)", forHTTPHeaderField: "Authorization")
        
        return request
    }
    
}
