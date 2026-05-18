# Mobile CI and Android Release Setup

This repository now has two GitHub Actions workflows:

- `.github/workflows/android-build.yml`: runs on pushes, pull requests, and manual dispatch. It has separate Android release, Android unit, Android e2e, iOS unit, and iOS e2e jobs. The unit jobs publish coverage reports plus a combined coverage dashboard.
- `.github/workflows/release.yml`: runs manually from the Actions tab. It reruns the same split test gates, builds a signed Android APK, creates the requested tag, publishes a GitHub Release, uploads the APK, and includes the APK SHA-256 hash in the release notes and as a `.sha256` asset.

## Required GitHub Secrets

Signed release builds require these repository secrets:

- `KEYSTORE_BASE64`: base64-encoded Android release keystore.
- `KEYSTORE_PASSWORD`: password for the keystore file.
- `KEY_ALIAS`: alias of the signing key.
- `KEY_PASSWORD`: password for the signing key. This can match `KEYSTORE_PASSWORD` if the same password was used for both.

Set them in GitHub under **Settings** -> **Secrets and variables** -> **Actions**.

## Encoding the Keystore

Use the release keystore stored outside the repository. For example, on macOS:

```bash
base64 -i /Users/ct4nk3r/Downloads/my-release-key.keystore | pbcopy
```

On Linux:

```bash
base64 -w 0 /path/to/my-release-key.keystore | xclip -selection clipboard
```

On Windows PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("your-release-key.keystore")) | Set-Clipboard
```

## Creating a Release Keystore

If a keystore is not available yet:

```bash
keytool -genkey -v -keystore release.keystore -alias release-key -keyalg RSA -keysize 2048 -validity 10000
```

Keep the keystore and passwords private. The workflow decodes the keystore into the runner temp directory and removes it after the build.

## Manual Release

1. Open **Actions** -> **Release**.
2. Click **Run workflow**.
3. Enter a version tag such as `v0.4.0`.
4. Choose whether it is a prerelease.
5. Start the workflow.

The workflow refuses to reuse an existing tag. On success it creates:

- a signed APK asset named `UniversalDownloader-<version>.apk`,
- a matching `UniversalDownloader-<version>.apk.sha256` asset,
- release notes containing the SHA-256 hash.

## Local Signed Build

```bash
export KEYSTORE_FILE=/path/to/your/release.keystore
export KEYSTORE_PASSWORD=your_keystore_password
export KEY_ALIAS=your_key_alias
export KEY_PASSWORD=your_key_password

cd android
./gradlew testReleaseUnitTest assembleRelease
```

The signed APK is written to `android/app/build/outputs/apk/release/app-release.apk`.

Without signing environment variables, `assembleRelease` still validates release packaging and writes an unsigned release APK. That path is used by pull-request CI so release-variant tests can run safely without exposing secrets.

## Coverage

Android coverage is generated with JaCoCo. iOS coverage is generated from `xccov`. The CI dashboard artifact links both platform reports.

The strict 100% unit coverage gates are scoped to deterministic core logic. App UI, platform integration, and downloader runtime behavior are covered by the Android and iOS e2e suites.
