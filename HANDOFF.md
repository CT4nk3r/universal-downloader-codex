# Universal Downloader PR #2 Handoff

Date: 2026-05-17

Repo: `CT4nk3r/uniersal-downloader-codex`

Branch: `pr-2`

PR: https://github.com/CT4nk3r/uniersal-downloader-codex/pull/2

## Current State

This workspace has uncommitted changes for the Android app. The user is testing playlist downloads on an emulator and hit a confusing playlist progress bug. The immediate next task is to debug that bug, not to start a new feature.

The app currently builds and installs locally. Last known good build command:

```bash
cd /Users/ct4nk3r/Documents/Codex/2026-05-17/ct4nk3r-uniersal-downloader-codex-2-https/repo/android
export JAVA_HOME='/usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home'
export ANDROID_HOME="$HOME/Library/Android/sdk"
bash ./gradlew :app:testDebugUnitTest :app:assembleDebug --stacktrace
```

Install and start:

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
"$ANDROID_HOME/platform-tools/adb" install -r android/app/build/outputs/apk/debug/app-debug.apk
"$ANDROID_HOME/platform-tools/adb" shell am start -n com.universaldownloader/.MainActivity
```

Useful emulator/device:

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
"$ANDROID_HOME/emulator/emulator" -avd Pixel_7_API_35
```

## Environment

- Android Studio is installed.
- Android SDK is at `~/Library/Android/sdk`.
- AVD created earlier: `Pixel_7_API_35`.
- JDK 17 is installed via Homebrew at:
  `/usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`

## Files Changed So Far

- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/java/com/universaldownloader/AppLogger.kt`
- `android/app/src/main/java/com/universaldownloader/DownloadView.kt`
- `android/app/src/main/java/com/universaldownloader/Downloader.kt`
- `android/app/src/main/java/com/universaldownloader/MainActivity.kt`
- `android/app/src/main/java/com/universaldownloader/UniversalDownloaderApp.kt`
- `android/app/src/main/java/com/universaldownloader/YtDlpDownloader.kt`
- `android/app/src/main/java/com/universaldownloader/YtDlpErrorMapper.kt`
- `android/app/src/main/res/xml/file_paths.xml`

## Implemented Changes

### Format and quality UI

- Audio-only mode now uses audio formats.
- Video/audio format choices are remembered separately while switching modes.
- Both modes default to `Source`.
- Audio format order: `Source`, `MP3`, `WAV`, `OGG`, `M4A`.
- Video format order: `Source`, `MP4`, `MOV`, `MKV`, `WEBM`.
- Added `OutputFormat.Webm` and yt-dlp mapping to `--remux-video webm`.
- Changed `Orig` label to `Source`.
- Changed quality first option to `Original`.
- Changed video mode label from `Quality` to `Video quality`.
- Audio mode label remains `Audio quality`.

### Logging

- Added `AppLogger.kt`.
- Logs to app-private file: `files/universal-downloader.log`.
- Mirrors logs to logcat with tag `UniversalDownloader`.
- Trims log file around 256 KB.
- URL logging is intentionally redacted/summarized.
- Logs option changes, download requests, yt-dlp output-format decisions, states, failures, cancellation, and cleanup.

### About and log sharing

- Removed the large `Share logs` button from the main page.
- Added small info button in the app header.
- About dialog includes:
  - `Email logs`
  - `Share logs`
  - `Close`
- Email intent targets GitHub noreply email:
  `59850112+CT4nk3r@users.noreply.github.com`
- Generic share is still available so users can save, copy, AirDrop, upload, or send logs another way.
- Added `FileProvider` and XML paths for sharing the app log file.

### Stop/cancel and playlist progress

- `DownloadState.Running` now carries playlist item data.
- Added `DownloadState.Stopped`.
- Added `DownloadItem` and `DownloadItemStatus`.
- Stop button moved into the download status section.
- Stop cancels the coroutine, destroys the yt-dlp process by process id, hides progress immediately, and deletes only `*.part` files in the download directory.
- `YtDlpDownloader` uses a unique process id for each download.
- Added `--concurrent-fragments 4`.
- Playlist UI now has `Playlist progress`, an active area, and `Downloaded` rows.
- Placeholder rows like `Item 22` were removed from display by only showing rows once real progress/file/title data exists.

## Current Bug To Resume

The user pasted a YouTube playlist. The screenshot shows:

- Status card says `Sleeping 6.00 seconds as required by the site...`.
- Progress bar area is empty.
- Downloaded section shows completed rows for `1/260`, `7/260`, and `13/260`.
- This looks wrong to the user because it suggests non-sequential or parallel playlist downloads.

The user asked: "How does this happen, what is happening?" They gave permission to inspect logs and can collect them later.

## First Suspicions

The `--concurrent-fragments 4` option limits fragment downloads inside one media item. It should not make yt-dlp download 13 playlist entries in parallel. yt-dlp playlist downloads are generally sequential unless separate processes are launched.

The weird `1/260`, `7/260`, `13/260` display is probably UI/parser confusion, skipped playlist entries, or the current progress model marking items finished too optimistically.

Likely parser issue:

- `PlaylistProgress.finishPreviousRunningItem()` marks a previously running item as `Finished` when yt-dlp moves to a new playlist item.
- That is unsafe. yt-dlp can move to another playlist index because an item was skipped, unavailable, already downloaded, failed, age restricted, or only metadata was fetched.
- A row should be marked `Finished` only after an explicit completion signal, successful final file event, or file existence check.

Likely empty progress issue:

- The UI currently only shows active rows after a destination/progress line gives enough file-level data.
- While yt-dlp is sleeping, extracting metadata, or downloading webpage info, there may be a current playlist index but no destination filename yet.
- The UI should show a separate "Preparing item X/Y" or "Current item X/Y" row before the filename exists, instead of an empty progress section.

## Logs To Collect

App-private file log:

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
"$ANDROID_HOME/platform-tools/adb" shell run-as com.universaldownloader cat files/universal-downloader.log > /tmp/universal-downloader.log
```

Logcat filtered to app logger:

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
"$ANDROID_HOME/platform-tools/adb" logcat -d -s UniversalDownloader:D '*:S' > /tmp/universal-downloader-logcat.txt
```

If run-as fails, check package name and installed build:

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
"$ANDROID_HOME/platform-tools/adb" shell pm list packages | grep universal
```

## Parser Lines To Handle Better

Add tests around representative yt-dlp output. Useful lines include:

```text
[download] Downloading item 13 of 260
[youtube] VIDEO_ID: Downloading webpage
[download] Destination: /path/name.f399.mp4
[download] 24.3% of ...
[download] 100% of ...
[download] name has already been downloaded
[Merger] Merging formats into "/path/name.mp4"
[ExtractAudio] Destination: /path/name.mp3
[MoveFiles] Moving file "/tmp/name.part" to "/final/name.mp4"
[download] Finished downloading playlist: ...
ERROR: ...
WARNING: ...
```

## Recommended Next Tasks

1. Pull the actual log from the emulator and inspect the surrounding lines for items `1`, `7`, and `13`.
2. Add focused unit tests for `PlaylistProgress` using sample yt-dlp lines.
3. Change the model so playlist cursor and file download rows are separate:
   - `currentPlaylistIndex`
   - `playlistTotal`
   - `currentMessage`
   - active file rows
   - completed file rows
   - skipped/failed rows
4. Remove the behavior that marks the previous item done just because a new playlist item starts.
5. Mark rows as finished only on explicit completion/post-processing/final-file evidence.
6. Show "Preparing item X/Y" while yt-dlp is sleeping/extracting/downloading webpage and no file destination exists yet.
7. Reconfirm only one app download coroutine/process can run at a time from the UI.

## Known Warnings

Last build had only warnings:

- `lateinit is unnecessary` for `stopButton`.
- `No cast needed` near the selected segmented-control id logic.

These are cleanup-level warnings, not blockers.

## Important Caution

Do not revert the dirty worktree. These changes are the active implementation work for the user's PR branch.

