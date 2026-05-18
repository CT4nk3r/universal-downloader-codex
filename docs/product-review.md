# Product Review and Recommendations

Last reviewed: 2026-05-18.

## GitHub State

- Repository: `CT4nk3r/universal-downloader-codex`
- Visibility: public
- Default branch: `main`
- Open issues: none
- Open pull requests: none
- Local `gh` status: authenticated as `CT4nk3r`

The repository was renamed from `uniersal-downloader-codex` to `universal-downloader-codex`, and the local `origin` remote was updated to the corrected URL.

## Recommendations

1. Release discipline: keep the new manual release workflow as the only path to signed APK publishing. It runs tests, creates the tag, publishes the release, uploads the APK, and records the SHA-256 hash.
2. Test confidence: keep Android and iOS unit tests above 30 each, and keep Android/iOS e2e suites above 30 each. Treat failing e2e as release blockers.
3. Coverage visibility: use the uploaded coverage dashboard artifact on every PR. The 100% gate applies to deterministic core logic, while UI and platform integration are covered by e2e tests.
4. Downloader runtime decision: document and choose the production yt-dlp strategy before store submission: embedded runtime, maintained mobile wrapper, or backend downloader API.
5. Platform parity: Android currently integrates the mobile yt-dlp wrapper; iOS still uses a placeholder downloader. Decide whether iOS should use a backend service or a native-compatible runtime.
6. Compliance and safety: add release checklist items for site terms, copyright-sensitive use, app-store review notes, privacy labels, and log redaction.
7. Supportability: keep the in-app log export, but add a troubleshooting page and a known-limitations page so users can self-triage unsupported links and rate limits.
8. Repository hygiene: enable branch protection once CI is green, requiring Mobile CI and Release tests before merge.

## Work Started From This Review

- Added PR Mobile CI for Android release-variant tests, Android e2e, iOS unit/UI tests, coverage reports, and a dashboard artifact.
- Added manual release workflow with signed APK generation, tag creation, GitHub Release creation, and SHA-256 notes/assets.
- Expanded Android unit and e2e tests past the requested minimum.
- Expanded iOS unit and UI tests past the requested minimum.
- Added coverage report scripts for Android/iOS dashboard artifacts.
- Added wiki-ready documentation pages in `docs/wiki/`.

## Review Outputs Still Worth Doing Next

- Add branch protection for `main` once the new workflows pass in GitHub Actions.
- Move the wiki-ready pages into the GitHub Wiki if that is the preferred public docs surface.
- Decide and implement the production iOS downloader runtime.
- Add release signing secret rotation instructions and an incident checklist for leaked signing materials.
