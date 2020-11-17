# WebDAV-Swift

WebDAV communication library for Swift

## Install

Install using Swift Package Manager.

```
https://github.com/Isvvc/WebDAV-Swift.git
```

In Xcode: File -> Swift Packages -> Add Package Dependency...  
or add in Project settings.

## Usage

```swift
import WebDAV
```

Create and instance of the WebDAV class.
This currently has two functions: `listFiles` and `upload`.
WebDAV functions require a path, account, and password.

### Account

`Account` is a protocol that contains a username and base URL for the WebDAV server.
These properties are optional for easier conformance,
but they must not be optional when making a request, or the request will fial.

Create a class or struct that conforms to `Account` that can be used in WebDAV calls.
Because the properties are optional, conformance can be added to CoreData entities.
