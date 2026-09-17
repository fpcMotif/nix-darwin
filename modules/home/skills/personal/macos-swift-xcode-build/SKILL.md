---
name: macos-swift-xcode-build
description: How to build and test Swift SPM packages on macOS when CommandLineTools SDK version mismatches Xcode toolchain
---

# macOS Swift Xcode Toolchain Environment Setup

When building or testing Swift Package Manager (SPM) projects on macOS where the system CommandLineTools SDK version differs from the Xcode toolchain version (e.g. Swift module interface version mismatches like `Apple Swift version 6.4` vs `6.3.3`), pass `DEVELOPER_DIR` and `SDKROOT` explicitly to `swift` or `make`.

## Environment Variables

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
SDKROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
```

## Usage

### Running SPM Tests
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer SDKROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk swift test
```

### Building Release Bundles / Install
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer SDKROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk make bundle
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer SDKROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk make install
```
