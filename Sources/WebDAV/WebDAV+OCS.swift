//
//  WebDAV+OCS.swift
//  WebDAV-Swift
//
//  Created by Isaac Lyons on 3/30/21.
//

import Foundation
import SWXMLHash

//MARK: OCSTheme

/// Theming information from a WebDAV server that supports OCS.
public struct OCSTheme {
    /// Name of the server.
    public var name: String?
    /// URL of the server.
    public var url: String?
    /// Slogan of the server.
    public var slogan: String?
    /// The theme color as a hex code starting with #.
    public var colorHex: String?
    /// Element color as a hex code starting with #.
    public var elementColorHex: String?
    /// Element color to be used on light backgrounds as a hex code starting with #.
    public var brightElementColorHex: String?
    /// Element color to be used on dark backgrounds as a hex code starting with #.
    public var darkElementColorHex: String?
    /// URL of the logo.
    public var logo: String?
    /// URL of background image.
    public var background: String?
    public var plainBackground: String?
    public var defaultBackground: String?
    
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

//MARK: Public

public extension WebDAV {
    
    /// Get the theme information from a WebDAV server that supports OCS (including Nextcloud).
    /// - Parameters:
    ///   - account: The WebDAV account.
    ///   - password: The WebDAV account's password.
    ///   - completion: If account properties are invalid, this will run immediately on the same thread.
    ///   Otherwise, it runs when the network call finishes on a background thread.
    ///   - theme: The theme information for the server.
    ///   - error: A WebDAVError if the call was unsuccessful.
    /// - Returns: The data task for the request.
    @discardableResult
    func getNextcloudTheme<A: WebDAVAccount>(account: A, password: String, completion: @escaping (_ theme: OCSTheme?, _ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
        guard let unwrappedAccount = UnwrappedAccount(account: account),
              let auth = self.auth(username: unwrappedAccount.username, password: password) else {
            completion(nil, .invalidCredentials)
            return nil
        }
        guard let baseURL = nextcloudBaseURL(for: unwrappedAccount.baseURL) else {
            completion(nil, .unsupported)
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
    
    /// Get the theme color from a WebDAV server that supports OCS (including Nextcloud).
    /// - Parameters:
    ///   - account: The WebDAV account.
    ///   - password: The WebDAV account's password.
    ///   - completion: If account properties are invalid, this will run immediately on the same thread.
    ///   Otherwise, it runs when the network call finishes on a background thread.
    ///   - color: The theme color for the server as a hex color starting with #.
    ///   - error: A WebDAVError if the call was unsuccessful.
    /// - Returns: The data task for the request.
    @discardableResult
    func getNextcloudColorHex<A: WebDAVAccount>(account: A, password: String, completion: @escaping (_ color: String?, _ error: WebDAVError?) -> Void) -> URLSessionDataTask? {
        getNextcloudTheme(account: account, password: password) { theme, error in
            completion(theme?.colorHex, error)
        }
    }
    
}
