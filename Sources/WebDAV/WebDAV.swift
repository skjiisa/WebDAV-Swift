//
//  WebDAV.swift
//  WebDAV-Swift
//
//  Created by Isaac Lyons on 10/29/20.
//

import Foundation
import SwiftyXMLParser

public class WebDAV: NSObject, URLSessionDownloadDelegate, URLSessionDataDelegate {
    private var tasks: [URLSessionTask: (Bool) -> Void] = [:]
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        tasks.removeValue(forKey: downloadTask)
    }
    
    public func cancelAll() {
        tasks.forEach { task, completion in
            if task.state != .completed {
                completion(false)
            }
            task.cancel()
            tasks.removeValue(forKey: task)
        }
    }
    
    public func cancel(_ task: URLSessionTask) {
        if let completion = tasks[task],
           task.state != .completed {
           completion(false)
        }
        task.cancel()
        tasks.removeValue(forKey: task)
    }
    
    @discardableResult
    public func listFiles(atPath path: String, account: Account, password: String, completion: @escaping (Bool) -> Void) -> URLSessionDataTask? {
        guard let unwrappedAccount = UnwrappedAccount(account: account),
              let auth = self.auth(username: unwrappedAccount.username, password: password) else {
            completion(false)
            return nil
        }
        
        let url = unwrappedAccount.baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.propfind.rawValue
        request.addValue("Basic \(auth)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession(configuration: .default, delegate: self, delegateQueue: nil).dataTask(with: request) { data, response, error in
            guard let response = response as? HTTPURLResponse,
                  200...299 ~= response.statusCode else { return completion(false) }
            
            if let data = data,
               let string = String(data: data, encoding: .utf8) {
                do {
                    let xml = try XML.parse(string)
                    print(xml["d:multistatus"]["d:response"].map { $0["d:href"].text })
                    return completion(true)
                } catch {
                    // Report the error
                    completion(false)
                }
            }
            
            completion(false)
        }
        
        tasks[task] = completion
        task.resume()
        return task
    }
    
    private func auth(username: String, password: String) -> String? {
        let authString = username + ":" + password
        let authData = authString.data(using: .utf8)
        return authData?.base64EncodedString()
    }
    
}
