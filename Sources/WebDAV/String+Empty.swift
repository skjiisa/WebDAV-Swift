//
//  String+Empty.swift
//  WebDAV-Swift
//
//  Created by Isaac Lyons on 4/7/21.
//

import Foundation

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
