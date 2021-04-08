//
//  WebDAV+OCS.swift
//  WebDAV-Swift
//
//  Created by Isaac Lyons on 3/30/21.
//

import Foundation
import SWXMLHash

struct OCSTheme {
    var name: String?
    var url: String?
    var slogan: String?
    var colorHex: String?
    var elementColorHex: String?
    var brightElementColorHex: String?
    var darkElementColorHex: String?
    var logo: String?
    var background: String?
    var plainBackground: String?
    var defaultBackground: String?
    
    internal init?(xml: XMLIndexer) {
        let theme = xml["ocs"]["data"]["capabilities"]["theming"]
        guard theme.all.count != 0 else { return nil }
        name                    = theme["name"]                 .element?.text.nilIfEmpty
        url                     = theme["url"]                  .element?.text.nilIfEmpty
        slogan                  = theme["slogan"]               .element?.text.nilIfEmpty
        colorHex                = theme["color"]                .element?.text.nilIfEmpty
        elementColorHex         = theme["color-element"]        .element?.text.nilIfEmpty
        brightElementColorHex   = theme["color-element-bright"] .element?.text.nilIfEmpty
        darkElementColorHex     = theme["color-element-dark"]   .element?.text.nilIfEmpty
        logo                    = theme["logo"]                 .element?.text.nilIfEmpty
        background              = theme["background"]           .element?.text.nilIfEmpty
        plainBackground         = theme["background-plain"]     .element?.text.nilIfEmpty
        defaultBackground       = theme["background-default"]   .element?.text.nilIfEmpty
    }
}

extension WebDAV {
    
    @discardableResult
    func getNextcloudTheme<A: WebDAVAccount>(account: A, password: String, completion: @escaping (_ theme: OCSTheme?, _ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
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
            let theme = OCSTheme(xml: xml)
            
            completion(theme, WebDAVError.getError(response: response, error: error))
        }
        
        task.resume()
        return task
    }
    
    @discardableResult
    func getNextcloudColorHex<A: WebDAVAccount>(account: A, password: String, completion: @escaping (_ color: String?, _ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
        getNextcloudTheme(account: account, password: password) { theme, error in
            completion(theme?.colorHex, error)
        }
    }
    
}
