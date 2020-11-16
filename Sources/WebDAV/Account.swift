//
//  File.swift
//  
//
//  Created by Isaac Lyons on 10/29/20.
//

import Foundation

public protocol Account {
    var username: String? { get }
    var baseURL: String? { get }
}

internal struct UnwrappedAccount {
    var username: String
    var baseURL: URL
    
    init?(account: Account) {
        guard let username = account.username,
              let baseURLString = account.baseURL,
              let baseURL = URL(string: baseURLString) else { return nil }
        self.username = username
        self.baseURL = baseURL
    }
}
