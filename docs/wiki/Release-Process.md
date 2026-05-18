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
- validates Android signing secrets,
- builds the signed Android APK,
- computes the APK SHA-256 hash,
- creates and pushes the release tag,
- creates a GitHub Release,
- uploads the APK and `.sha256` file.

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
