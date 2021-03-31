//
//  WebDAV+OCS.swift
//  WebDAV-Swift
//
//  Created by Isaac Lyons on 3/30/21.
//

import Foundation
import SWXMLHash

extension WebDAV {
    
    @discardableResult
    func getColorHex<A: WebDAVAccount>(account: A, password: String, completion: @escaping (_ color: String?, _ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
        
        guard let unwrappedAccount = UnwrappedAccount(account: account),
              let auth = self.auth(username: unwrappedAccount.username, password: password),
              let baseURL = nextcloudBaseURL(for: unwrappedAccount.baseURL) else {
            completion(nil, .invalidCredentials)
            return nil
        }
        
        let url = baseURL.appendingPathComponent("ocs/v1.php/cloud/capabilities")
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.get.rawValue
        request.addValue("Basic \(auth)", forHTTPHeaderField: "Authorization")
        
        request.setValue("true", forHTTPHeaderField: "OCS-APIRequest")
        
        let task = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil).dataTask(with: request) { data, response, error in
            guard let data = data,
                  let string = String(data: data, encoding: .utf8) else {
                let webDAVError = WebDAVError.getError(response: response, error: error)
                return completion(nil, webDAVError)
            }
            
            let xml = SWXMLHash.parse(string)
            var color = xml["ocs"]["data"]["capabilities"]["theming"]["color"].element?.text
            if color?.first == "#" {
                color?.removeFirst()
            }
            
            completion(color, WebDAVError.getError(response: response, error: error))
        }
        
        task.resume()
        return task
    }
    
}
