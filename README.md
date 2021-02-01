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

The functions currently available include

+ `listFiles`
+ `upload`
+ `download`
+ `createFolder`
+ `deleteFile`

These functions will each return a [URLSessionTask](https://developer.apple.com/documentation/foundation/urlsessiontask) which can be cancelled later.

#### Example

```swift
let baseURL = "https://nextcloud.example.com/remote.php/dav/files/Username/"
let account = SimpleAccount(username: username, baseURL: baseURL)
let path = "file.txt"
let data = "File contents".data(using: .utf8)
        
webDAV.upload(data: data, toPath: path, account: account, password: password) { error in
    // Handle the error
}
```

### Image cache

Included is functionality for downloading and caching images.
This is based on [3lvis/Networking](https://github.com/3lvis/Networking).

You can download an image like you would any other file using `downloadImage`.
This will download the image and save it to both an memory and disk cache.

#### Functions

Image cache functions include

+ `downloadImage`
+ `deleteCachedData`
+ `getCachedDataURL`
+ `deleteAllCachedData`
+ `cancelRequest`
+ `getCacheByteCount`
+ `getCacheSize`

Unlike the other request functions, `downloadImage` does not return a URLSessionTask.
This is because it's based on 3lvis/Networking.
Instead it returns a request identifier that can be used to cancel the request using the `cancelRequest` function.

## Contribution

This package depends on [drmohundro/SWXMLHash](https://github.com/drmohundro/SWXMLHash)
and [3lvis/Networking](https://github.com/3lvis/Networking).
which should automatically be fetched by Swift Package Manager in Xcode.

To test any contributions you make, make test functions in `WebDAVTests`.
In order to run tests, you need to pass account information in as environment variables.

### Adding a WebDAV account

You'll need to add a WebDAV account to your scheme to be able to test.

Edit your scheme in Xcode. Ensure the "Shared" checkbox is _unchecked_ to keep the scheme private.

Under Arguments in Test, add the following environment variables:

+ `webdav_user`: The username for your WebDAV account to test with
+ `webdav_password`: The password for your WebDAV account
+ `webdav_url`: The URL of the WebDAV server your account is on
+ `image_path`: The path to an image file in the WebDAV storage

Note that running the tests will create files on your WebDAV server, though they should also be deleted, assuming all the tests pass.
