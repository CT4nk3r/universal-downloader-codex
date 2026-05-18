# Release Process

Releases are created from GitHub Actions.

## Manual Release

1. Open **Actions**.
2. Select **Release**.
3. Choose **Run workflow**.
4. Enter a version tag such as `v0.4.0`.
5. Choose whether the release is a prerelease.
6. Run the workflow.

The release workflow:

- runs Android unit tests,
- runs Android e2e tests,
- runs iOS unit and UI tests,
- builds an unsigned iOS `.ipa` for AltStore/Sideloadly-style sideloading,
- validates Android signing secrets,
- builds the signed Android APK,
- computes the APK SHA-256 hash,
- creates and pushes the release tag,
- creates a GitHub Release,
- uploads the APK, unsigned IPA, and `.sha256` files.

## Required Secrets

- `KEYSTORE_BASE64`
- `KEYSTORE_PASSWORD`
- `KEY_ALIAS`
- `KEY_PASSWORD`

## Local Signed Build

```bash
export KEYSTORE_FILE=/path/to/release.keystore
export KEYSTORE_PASSWORD=your_keystore_password
export KEY_ALIAS=your_key_alias
export KEY_PASSWORD=your_key_password

cd android
./gradlew testReleaseUnitTest assembleRelease
```

## Unsigned iOS IPA

The GitHub Release includes `UniversalDownloader-<version>-unsigned.ipa`.

This file is not App Store signed and does not require an Apple Developer Program account to produce. It is intended for tools such as AltStore or Sideloadly, which re-sign the IPA locally with the user's Apple ID before installing it on a device. Free Apple ID signing usually needs to be refreshed after about 7 days.
