# FloatStop

A tiny floating stopwatch for macOS.

## What is FloatStop?

FloatStop is a small native macOS stopwatch that floats above normal windows
and stays accessible from the menu bar. It is built with Swift, SwiftUI, and
AppKit. No Electron. No third-party dependencies.

## Features

- Floating always-on-top stopwatch
- Large readable time display
- Start / Pause / Reset
- Menu bar access
- Optional Dock icon hiding
- Optional Launch at Login
- Native macOS app
- No network access
- No analytics
- No tracking
- No special permissions required

## Screenshots

Screenshots coming soon.

## Requirements

- macOS 13 Ventura or newer
- Xcode 15 or newer for building from source
- Swift 5.9 or newer

## Build from source

```sh
git clone https://github.com/YOUR_USERNAME/FloatStop.git
cd FloatStop
open FloatStop.xcodeproj
```

Then press ⌘R in Xcode. Or build from the command line:

```sh
xcodebuild -project FloatStop.xcodeproj -scheme FloatStop -configuration Release build
```

## Install local build

Build in Xcode, then copy `FloatStop.app` to `/Applications`.

Optionally, you can locate the built app under Xcode's DerivedData folder
after a command-line build and copy it from there, but the simple path is
to build in Xcode and drag the result.

## Menu bar access

FloatStop adds a small menu bar stopwatch icon. From the menu bar you can:

- Show / Hide the floating stopwatch
- Start / Pause
- Reset
- Toggle **Hide Dock Icon**
- Toggle **Launch at Login**
- Quit

## Dock icon

FloatStop can run with or without a Dock icon. Use:

**Menu bar icon → Hide Dock Icon**

If the Dock icon is hidden, FloatStop remains accessible from the menu bar
icon.

## Launch at Login

Use:

**Menu bar icon → Launch at Login**

On macOS 13+, FloatStop uses Apple's ServiceManagement / `SMAppService` API.

For unsigned local builds, Launch at Login behavior may vary depending on
macOS security and signing state. For best reliability, use a properly
signed build.

## Known limitations

- FloatStop uses `NSPanel` with `.floating` level.
- It stays above normal windows.
- It can join Spaces.
- macOS does not guarantee that ordinary floating panels appear above
  arbitrary third-party full-screen apps.
- FloatStop intentionally does not use `.screenSaver` window level hacks.
- No global hotkeys.
- No countdown timer.
- No lap history.

## Privacy

- FloatStop does not collect data.
- FloatStop does not use network access.
- FloatStop does not include analytics.
- FloatStop does not track users.
- FloatStop does not require special permissions.

## Distribution status

v0.1.0 is intended as an open-source source release.

Unsigned binary builds may trigger macOS Gatekeeper warnings. Users who
prefer maximum transparency should build from source.

## License

MIT License. See [LICENSE](LICENSE).
