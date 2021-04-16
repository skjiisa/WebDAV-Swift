//
//  Account.swift
//  WebDAV-Swift
//
//  Created by Isaac Lyons on 10/29/20.
//

import Foundation

//MARK: WebDAVAccount

public protocol WebDAVAccount: Hashable {
    var username: String? { get }
    var baseURL: String? { get }
}

//MARK: UnwrappedAccount

internal struct UnwrappedAccount: Hashable {
    var username: String
    var baseURL: URL
    
    init?<Account: WebDAVAccount>(account: Account) {
        guard let username = account.username,
              let baseURLString = account.baseURL,
              var baseURL = URL(string: baseURLString) else { return nil }
        
        switch baseURL.scheme {
        case nil:
            baseURL = URL(string: "https://" + baseURLString) ?? baseURL
        case "https":
            break
        default:
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
            components?.scheme = "https"
            baseURL = components?.url ?? baseURL
        }
        
        self.username = username
        self.baseURL = baseURL
    }
    
    /// Description of the unwrapped account in the format "username@baseURL".
    var description: String {
        "\(username)@\(baseURL.absoluteString)"
    }
    
    /// Description of the unwrapped account in the format "username@baseURL"
    /// with the baseURL encoded.
    ///
    /// Replaces slashes with colons (for easier reading on macOS)
    /// and other special characters  with their percent encoding.
    /// - Note: Only the baseURL is encoded. The username and @ symbol are unchanged.
    var encodedDescription: String? {
        guard let encodedURL = baseURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else { return nil }
        return "\(username)@\(encodedURL.replacingOccurrences(of: "%2F", with: ":"))"
    }
}

//MARK: AccountPath

public struct AccountPath: Hashable, Codable {
    private static let slash = CharacterSet(charactersIn: "/")
    
    var username: String?
    var baseURL: String?
    var path: String
    
    init<Account: WebDAVAccount>(account: Account, path: String) {
        self.username = account.username
        self.baseURL = account.baseURL
        self.path = path.trimmingCharacters(in: AccountPath.slash)
    }
}

//MARK: SimpleAccount

public struct SimpleAccount: WebDAVAccount {
    public var username: String?
    public var baseURL: String?
}
