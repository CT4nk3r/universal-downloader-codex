# Testing and Coverage

## Pull Request Gates

Every pull request to `main` or `develop` runs Mobile CI:

- Android release-variant unit tests
- Android release packaging
- Android e2e tests
- iOS unit tests
- iOS UI tests
- Android JaCoCo coverage
- iOS xccov coverage
- combined coverage dashboard artifact

## Test Suite Targets

- Android unit tests: at least 30
- Android e2e tests: at least 30
- iOS unit tests: at least 30
- iOS UI/e2e tests: at least 30

## Coverage Policy

The strict 100% unit coverage gates focus on deterministic core logic. Platform UI and downloader integration are covered by e2e tests because they depend on Android/iOS runtime behavior, simulators, and external downloader libraries.

Coverage reports are uploaded as GitHub Actions artifacts:

- `android-coverage`
- `ios-coverage`
- `coverage-dashboard`

## Local Android Tests

```bash
cd android
./gradlew testDebugUnitTest testReleaseUnitTest jacocoTestReport jacocoCoverageVerification
```

## Local iOS Tests

```bash
cd ios
xcodegen generate
cd ..
DESTINATION="$(python3 scripts/select_ios_destination.py)"
xcodebuild test -project ios/UniversalDownloader.xcodeproj -scheme UniversalDownloader -destination "$DESTINATION" -enableCodeCoverage YES
```
