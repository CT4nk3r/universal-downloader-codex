# iOS Handoff

This file captures the iOS state so work can pause while Android is built first.

## Current iOS Shape

The iOS source lives in `ios/`.

It is a native Swift app plus Share Extension scaffold:

- `ios/project.yml`: XcodeGen project definition.
- `ios/UniversalDownloader/`: host iOS app.
- `ios/ShareExtension/`: iOS share extension.
- `ios/Shared/`: code shared by the host app and extension.

The intended flow is:

1. User taps Share in YouTube, X/Twitter, Reddit, or another app.
2. User chooses Universal Downloader in the iOS share sheet.
3. The Share Extension extracts a URL from either URL or plain text input.
4. The extension writes the URL into an App Group queue.
5. The extension opens the host app with `universaldownloader://shared`.
6. The host app drains the queued link and starts the download.

## Files To Know

- `ios/ShareExtension/ShareViewController.swift`
  - Receives shared content.
  - Extracts a URL using `NSItemProvider`.
  - Stores the URL through `SharedLinkStore`.
  - Opens the containing app through `extensionContext?.open(...)`.

- `ios/Shared/SharedLinkStore.swift`
  - Stores pending shared links in `UserDefaults(suiteName:)`.
  - Uses `AppConfig.appGroupIdentifier`.

- `ios/Shared/AppConfig.swift`
  - Contains the App Group id and custom URL scheme.
  - Current App Group placeholder: `group.com.universaldownloader.shared`.

- `ios/UniversalDownloader/DownloadViewController.swift`
  - Basic native UIKit screen.
  - Drains pending shared links on launch/open.
  - Starts a simulated download via `YTDLPClient`.

- `ios/UniversalDownloader/YTDLPClient.swift`
  - Current downloader abstraction.
  - It simulates progress.
  - Replace this with the real yt-dlp runtime, wrapper, or backend client.

## Before Building On The Intel Mac

Install:

```sh
brew install xcodegen
```

Then generate the project:

```sh
cd ios
xcodegen generate
open UniversalDownloader.xcodeproj
```

In Xcode:

1. Set the development team for both targets.
2. Replace the App Group id with a real group tied to the Apple Developer account.
3. Update the same App Group string in:
   - `ios/project.yml`
   - `ios/Shared/AppConfig.swift`
   - `ios/UniversalDownloader/UniversalDownloader.entitlements`
   - `ios/ShareExtension/ShareExtension.entitlements`
4. Confirm the URL scheme `universaldownloader` is acceptable, or rename it consistently.

## Known Incomplete Work

The iOS downloader is not wired to real yt-dlp yet.

`YTDLPClient.download(url:)` currently emits simulated progress and returns `downloaded-video.mp4`.

The next decision is the actual download architecture:

- Embedded runtime:
  - Hardest on iOS.
  - Needs careful packaging, sandboxing, update strategy, and App Store review risk assessment.

- Backend downloader API:
  - Cleanest iOS path.
  - The app sends the shared URL to a server, the server runs yt-dlp, and the app receives the file or a download URL.

- Hybrid:
  - Android can use an embedded/native wrapper.
  - iOS can use a backend until a safe local runtime is proven.

## Recommended Next iOS Steps

1. Generate the Xcode project with XcodeGen.
2. Build the host app target first.
3. Build the Share Extension target.
4. Test sharing plain text from Notes into Universal Downloader.
5. Test sharing a YouTube URL from Safari.
6. Confirm the host app opens and begins the simulated download.
7. Replace `YTDLPClient` with the chosen real implementation.

## Risk Notes

Directly downloading from YouTube, X/Twitter, Reddit, and similar services can involve terms-of-service, copyright, and App Store review concerns. The wrapper architecture keeps this isolated so the UI and share-extension plumbing can survive even if the download engine changes.

