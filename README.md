# WebDAV-Swift

WebDAV communication library for Swift

## Table of contents

+ [Install](#install)
+ [Usage](#usage)
  + [Account](#account)
  + [Making requests](#making-requests)
  + [Listing files](#listing-files)
  + [Data cache](#data-cache)
  + [Images](#images)
  + [Thumbnails](#thumbnails)
  + [Theming](#theming)
+ [Upgrading](#upgrading)
+ [Contribution](#contribution)
  + [Adding a WebDAV account](#adding-a-webdav-account)

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

For functions that read from or write to a file, this path should include the file name and extension.

#### Functions

The basic WebDAV functions currently available include

+ `listFiles`
+ `upload`
+ `download`
+ `createFolder`
+ `deleteFile`
+ `moveFile`
+ `copyFile`

These functions will each return a [URLSessionTask](https://developer.apple.com/documentation/foundation/urlsessiontask) which can be cancelled later.

#### Example

```swift
let baseURL = "https://nextcloud.example.com/remote.php/dav/files/Username/"
let account = SimpleAccount(username: username, baseURL: baseURL)
let path = "file.txt"
let data = "File contents".data(using: .utf8)
        
webDAV.upload(data: data, toPath: path, account: account, password: password) { error in
    // Check the error
}
```

### Listing files

The `listFiles` function, if successful, will complete with a `WebDAVFile` array, which will be cached to memory and disk for quick retrieval later.
By default, subsequent calls of `listFiles` on the same path with the same account will give the cached results instead of making a network request.
See [Caching behavior](#caching-behavior) for how to change this behavior.

A useful option for listing files in particular is `.requestEvenIfCached`:

```swift
webDAV.listFiles(atPath: path, account: account, password: password, caching: .requestEvenIfCached) { files, error in
    // Show the cached files immediately.
    // Update to show the newly fetched files list after the request is complete.
}
```

In this case, if there are cached files, the completion closure will run immediately with those cached files.
Then a network request will be made to get an updated files list.
If the files list from the server is unchanged from the cache, the function ends here and nothing else is called.
If the files list from the server is different from the cache, the completion closure will run a second time with the new files list.

The files cache can be cleared using `clearFilesCache`, `clearFilesDiskCache`, or `clearFilesMemoryCache`.

### Data cache

Included is functionality for downloading and caching data, images, and thumbnails (on Nextcloud servers).

Data downloaded using the `download` function, or the various image and thumbnail fetching functions, will cache to both memory and disk.
The memory function is based off of [NSCache](https://developer.apple.com/documentation/foundation/nscache),
meaning it uses Apple's own auto-eviction policies to clear up system memory.
The disk cache data is stored in the `app.lyons.webdav-swift` folder in the [caches directory](https://developer.apple.com/documentation/foundation/filemanager/searchpathdirectory/cachesdirectory).

Data cache functions include

+ `getCachedData`
+ `deleteCachedData`
+ `deleteAllCachedData`
+ `getCacheByteCount`
+ `getCacheSize`
+ `cachedDataURL`
+ `cachedDataURLIfExists`
+ `deleteAllDiskCachedData`

#### Caching behavior

**Default caching behavior** is to return a cached result instead of making a request if there is one.
Otherwise, make a request and cache the result.

Use the `caching options` parameter in functions to change the caching behavior based on `WebDAVCachingOptions`.
Setting the caching options to an empty set will use default behavior.

Caching options include

+ `doNotCacheResult`
+ `doNotReturnCachedResult`
+ `removeExistingCache`
  + Removes the cached result after returning it, if it exists.
  + Use with `doNotReturnCachedResult` if you do not want the cached result returned.
+ `requestEvenIfCached`
  + The completion closure for the request will run once with the cached data,
  then again with the newly fetched data, assuming it is different.

Convenience options include

+ `ignoreCache` will ignore the cached result if there is one, and won't cache the new result.
  + Same as `[.doNotCacheResult, .doNotReturnCachedResult]`.
+ `disableCache` disables all caching for the request and deletes any existing cache for it.
  + Same as `[.doNotCacheResult, .removeExistingCache, .doNotReturnCachedResult]`.

### Images

Images can be downloaded and cached using `downloadImage`. This will complete with a `UIImage` if available and caches the same way as the data cache.

Image functions include:

+ `downloadImage`
+ `getCachedImage`

_Why is there no `deleteCachedImage` or `cachedImageURL` function when there is `getCachedThumbnail` and `cachedThumbnailURL`?_  
Images are stored in the disk cache the same way as data. The image-specific functions exist as a convenience for converting the data to UIImages and caching them in memory that way. Since the cached data URL does not change whether the data is an image or not, `deleteCachedData` and `cachedDataURL` can be used for images.

#### Thumbnail preview

If there are already cached thumbnails for the image you are trying to fetch, you can use the `preview` parameter to specify that you would like to get that thumbnail first while the full-size image is downloading.

```swift
webDAV.downloadImage(path: imagePath, account: account, password: password, preview: .memoryOnly) { image, error in
    // Display the image.
    // This will run once on the largest cached thumbnail (if there are any)
    // and again with the full-size image.
}
```

See [Thumbnails](#thumbnails) for more details on thumbnails.

### Thumbnails

Along with downloading full-sized images, you can download **thumbnails** from Nextcloud servers.
This currently only works with Nextcloud servers as thumbnail generation is not part of the WebDAV standard.

Thumbnail generation requires you to specify the properties for how the server should render the thumbnail.
These properties exist as `ThumbnailProperties` objects and include dimensions and content mode.
If no dimensions are specified, the server's default will be used (default is 64x64 on Nextcloud).
When getting the URL of or deleting a cached URL, you must also specify these properties in order to access the correct specific thumbnail.
If you wish to access all thumbnails for a specific image at once, you can use `getAllCachedThumbnails` and `deleteAllCachedThumbnails`.

Example:

```swift
webDAV.downloadThumbnail(path: imagePath, account: account, password: password, with: .init((width: 512, height: 512), contentMode: .fill)) { image, error in
    // Check the error
    // Display the image
}
```

Note that `ThumbnailProperties` objects can also be initialized using a `CGSize`, but doing so will truncate the size to integer pixel counts.

Thumbnail functions include

+ `downloadThumbnail`
+ `getCachedThumbnail`
+ `getAllCachedThumbnails`
+ `deleteCachedThumbnail`
+ `deleteAllCachedThumbnails`
+ `cachedThumbnailURL`
+ `cachedThumbnailURLIfExists`

### Theming

WebDAV servers that support OCS (such as Nextcloud and ownCloud) can give you theming information including accent color, name, slogan, background image, etc.
Two functions exist for this:

+ `getNextcloudColorHex`
+ `getNextcloudTheme`

`getNextcloudColorHex` will give the server's accent color as a hex code starting with '#' (eg `#0082c9`).
`getNextcloudTheme` will give the server's full theming information in the form of an `OCSTheme` object.

## Upgrading

Version 2.x used [3lvis/Networking](https://github.com/3lvis/Networking) for its image caching,
but this was replaced with a custom in-house caching solution in 3.0.
If upgrading from v2 to v3, run the function `clearV2Cache()` in order to remove previously cached data.

For example, you could run something like this on startup

```swift
if !UserDefaults.standard.bool(forKey: "webDAV-v3-upgrade") {
    try? webDAV.clearV2Cache()
    UserDefaults.standard.setValue(true, forKey: "webDAV-v3-upgrade")
}
```

## Contribution

This package depends on [drmohundro/SWXMLHash](https://github.com/drmohundro/SWXMLHash)
which should automatically be fetched by Swift Package Manager in Xcode.

To test any contributions you make, make test functions in `WebDAVTests`.
In order to run tests, you need to add a WebDAV account to the environment variables as described below.

### Adding a WebDAV account

You'll need to add a WebDAV account to your scheme to be able to test.

Edit your scheme in Xcode. Ensure the "Shared" checkbox is _unchecked_ to keep the scheme private.

Under Arguments in Test, add the following environment variables:

+ `webdav_user`: The username for your WebDAV account to test with
+ `webdav_password`: The password for your WebDAV account
+ `webdav_url`: The URL of the WebDAV server your account is on
+ `image_path`: The path to an image file of type jpg/jpeg, png, or gif in the WebDAV storage

Note that running the tests will create files on your WebDAV server, though they should also be deleted, assuming all the tests pass.
