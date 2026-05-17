# Android Build Pipeline Setup

This document describes how to configure the GitHub Actions pipeline for building signed Android APKs.

## Overview

The repository includes a GitHub Actions workflow (`.github/workflows/android-build.yml`) that:
- Builds a debug APK on all pushes and pull requests
- Builds a signed release APK when pushing to `main` or `develop` branches
- Uploads build artifacts for download

## Required GitHub Secrets

To build signed release APKs, you need to configure the following secrets in your GitHub repository:

### Setting up secrets

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** for each of the following:

### Required secrets:

#### `KEYSTORE_BASE64`
The base64-encoded keystore file for signing the APK.

To generate this from your keystore file:
```bash
base64 -i your-release-key.keystore | pbcopy  # macOS
base64 -i your-release-key.keystore | xclip   # Linux
```

Or on Windows PowerShell:
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("your-release-key.keystore")) | Set-Clipboard
```

#### `KEYSTORE_PASSWORD`
The password for the keystore file.

#### `KEY_ALIAS`
The alias of the key within the keystore.

#### `KEY_PASSWORD`
The password for the specific key (can be the same as `KEYSTORE_PASSWORD`).

## Creating a Release Keystore

If you don't have a keystore yet, create one using:

```bash
keytool -genkey -v -keystore release.keystore -alias release-key -keyalg RSA -keysize 2048 -validity 10000
```

Follow the prompts to set:
- Keystore password
- Key password
- Your organization details

**Important:** Keep your keystore file and passwords secure. Never commit them to the repository.

## Build Artifacts

After the workflow runs:
- **Debug APK**: Available in workflow artifacts as `app-debug` (30-day retention)
- **Release APK**: Available in workflow artifacts as `app-release` (90-day retention)

Download artifacts from:
- GitHub Actions → Select workflow run → Scroll to "Artifacts" section

## Local Build

To build locally with signing:

```bash
# Set environment variables
export KEYSTORE_FILE=/path/to/your/release.keystore
export KEYSTORE_PASSWORD=your_keystore_password
export KEY_ALIAS=your_key_alias
export KEY_PASSWORD=your_key_password

# Build release APK
cd android
./gradlew assembleRelease
```

The signed APK will be at: `android/app/build/outputs/apk/release/app-release.apk`

## Troubleshooting

### Build fails with "Keystore file not found"
- Ensure `KEYSTORE_BASE64` secret is properly set
- Verify the base64 encoding is correct

### Build fails with "Incorrect keystore password"
- Double-check `KEYSTORE_PASSWORD` and `KEY_PASSWORD` secrets
- Ensure there are no extra spaces or newlines in the secret values

### Build fails with "Key alias not found"
- Verify `KEY_ALIAS` matches the alias in your keystore
- List aliases in your keystore: `keytool -list -v -keystore release.keystore`
