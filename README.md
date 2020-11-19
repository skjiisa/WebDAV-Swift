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

`WebDAVAccount` is a protocol that contains a username and base URL for the WebDAV server.
These properties are optional for easier conformance,
but they must not be optional when making a request, or the request will fail.

Create a class or struct that conforms to `WebDAVAccount` that can be used in WebDAV calls,
or use the provided `SimpleAccount` struct.
Because the properties are optional, conformance can be added to CoreData entities.

When instantiating a `WebDAVAccount`, the `baseURL` property should be the URL to access the WebDAV server.
For Nextcloud, this should include `remote.php/dav/files/[username]/`
(can be found under Settings in the bottom-left of any Files page).

Example:

```swift
SimpleAccount(username: "test", baseURL: "https://nextcloud.example.com/remote.php/dav/files/test/")
```

### Making requests

Every request requires a path, `WebDAVAccount`, and password. There is no "logging in".
This is so apps can easily support having multiple accounts without having to log in or out of each.

#### Passwords

It is highly recommended you use an app-specific password (for Nextcloud, see [Login flow v2](https://docs.nextcloud.com/server/latest/developer_manual/client_apis/LoginFlow/index.html#login-flow-v2)).
Do not store the user's password in plain text.
Use [URLCredentialStorage](https://developer.apple.com/documentation/foundation/urlcredentialstorage) or [Keychain](https://developer.apple.com/documentation/security/keychain_services) (or something like [KeychainSwift](https://github.com/evgenyneu/keychain-swift) for easier use).

#### Path

The path passed into functions should be the path to the file or directory relative to the `baseURL` in your account.

For fuctions that read from or write to a file, this path should include the file name and extension.

#### Functions

The functions currently available are

+ `listFiles`
+ `upload`

## Contribution

This package depends on [SWXMLHash](https://github.com/drmohundro/SWXMLHash).
This should automatically be fetched by Swift Package Manager in Xcode.

To test any contributions you make, make test functions in `WebDAVTests`.
In order to run tests, you need to pass account information in as environment variables.

### Adding a WebDAV account

You'll need to add a WebDAV account to your scheme to be able to test.

Edit your scheme in Xcode. Ensure the "Shared" checkbox is _unchecked_ to keep the scheme private.

Under Arguments in Test, add the following environment variables:

+ `webdav_user`: The username for your WebDAV account to test with
+ `webdav_password`: The password for your WebDAV account
+ `webdav_url`: The URL of the WebDAV server your account is on

Note that the `testUploadData` test will upload a 36-byte file named `WebDAVSwiftUploadTest.txt`
to the root folder of your WebDAV account and will overwrite any other file with that same name.
