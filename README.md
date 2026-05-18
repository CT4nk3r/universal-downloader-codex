# Universal Downloader

Native mobile wrappers around `yt-dlp` style downloading for shared links from YouTube, X/Twitter, Reddit, and other supported sites.

[Code coverage dashboard](https://ct4nk3r.github.io/universal-downloader-codex/code-coverage/)

## What is included

- `android/`: Kotlin Android app using Material Components.
  - Registers a share target for `text/plain` links.
  - Shows a Material download screen.
  - Starts downloads from the regular app or directly from Android Sharesheet.
  - Uses a `YtDlpDownloader` abstraction so you can plug in `youtubedl-android`, a bundled binary, or your own backend.
- `ios/`: Swift iOS app plus Share Extension source.
  - Receives URLs from the iOS share sheet.
  - Stores incoming links in an App Group queue.
  - Opens the host app to process downloads.
  - Uses a `YTDLPClient` abstraction so the executable/engine can be swapped safely.
- `.github/workflows/`: Mobile CI plus the manual release workflow for signed Android APKs.
- `docs/wiki/`: wiki-ready release, testing, roadmap, and troubleshooting pages.

## Important packaging note

`yt-dlp` is Python-based and frequently updated. The wrapper layer in this repo is intentionally isolated from app UI and share-extension plumbing. For production, decide whether downloads happen via:

- an embedded mobile-compatible yt-dlp runtime,
- a maintained mobile wrapper library,
- or a server-side downloader API.

Check each platform's store rules and the terms of services of sites you support before shipping.

## Android quick start

Open `android/` in Android Studio and run the `app` configuration.

The downloader currently uses a stub implementation in `YtDlpDownloader.kt`. Replace the `TODO` block with a real engine call, keeping the `Downloader` interface stable.

## iOS quick start

Install XcodeGen, then generate the Xcode project:

```sh
cd ios
xcodegen generate
open UniversalDownloader.xcodeproj
```

Update the App Group in `project.yml`, `AppConfig.swift`, and the extension entitlements before running on a device.

## Tests and releases

Pull requests run Android release-variant unit tests, Android e2e tests, iOS unit/UI tests, and coverage reporting. Manual releases are created from **Actions** -> **Release** with a version like `v0.4.0`; the workflow signs the Android APK, creates the tag, publishes the GitHub Release, and includes the APK SHA-256 hash.

See `.github/ANDROID_BUILD_PIPELINE.md` and `docs/wiki/Testing-and-Coverage.md` for setup details.
