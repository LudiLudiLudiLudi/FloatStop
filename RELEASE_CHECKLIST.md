# FloatStop Release Checklist

## Pre-release cleanup

- [ ] Confirm no local paths such as `/Users/admin/V13` appear in README or source comments
- [ ] Confirm no `build/`, `dist/`, `DerivedData/`, `.DS_Store`, logs, ZIPs, or DMGs are committed
- [ ] Confirm Bundle Identifier is `com.eladperegrubens.FloatStop`
- [ ] Confirm `MARKETING_VERSION` is `0.1.0`
- [ ] Confirm `CURRENT_PROJECT_VERSION` is `1`
- [ ] Confirm `LICENSE` exists
- [ ] Confirm `.gitignore` exists

## Build

- [ ] Run `xcodebuild -project FloatStop.xcodeproj -scheme FloatStop -configuration Release build`
- [ ] Confirm build succeeds without Swift compile warnings

## Manual app verification

- [ ] Launch FloatStop
- [ ] Floating stopwatch panel appears
- [ ] Stopwatch starts
- [ ] Stopwatch pauses
- [ ] Stopwatch resets
- [ ] Menu bar icon appears
- [ ] Show / Hide works
- [ ] Closing the floating panel does not terminate the app
- [ ] Show FloatStop brings the panel back
- [ ] Hide Dock Icon toggles Dock visibility
- [ ] Hide Dock Icon persists across relaunch
- [ ] Launch at Login toggle does not crash
- [ ] Quit exits cleanly

## macOS behavior checks

- [ ] Confirm app stays above normal windows
- [ ] Confirm README documents full-screen Space limitation
- [ ] Confirm README states no global hotkeys
- [ ] Confirm README states no `.screenSaver` level hacks

## GitHub release

- [ ] Push source to GitHub
- [ ] Create tag `v0.1.0`
- [ ] Create GitHub Release
- [ ] If attaching a ZIP, label it clearly as unsigned / experimental unless signed and notarized
- [ ] Mention that users may need right-click → Open for unsigned builds
- [ ] Recommend building from source for maximum transparency
