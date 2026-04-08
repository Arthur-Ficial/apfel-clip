# App Store Prep

This repo now includes the app-side assets needed to move `apfel-clip` toward Mac App Store distribution:

- `Config/AppStore.entitlements`
- `Resources/PrivacyInfo.xcprivacy`
- Self-contained `.app` packaging via `scripts/build-app.sh`
- Embedded helper support via `APFEL_HELPER_PATH` or a system `apfel`

## What still has to happen at release time

1. Build a reviewable `.app` with an embedded `apfel` helper inside `Contents/Helpers/apfel`.
2. Sign the app and helper with the correct Mac App Store certificate and provisioning profile.
3. Archive and submit the sandboxed bundle with App Store Connect tooling.

## Important blocker to avoid

Do not submit a Mac App Store build that depends on the user installing `apfel` through Homebrew first. The review build must be self-contained.

## Direct distribution

For GitHub releases and Homebrew casks, use the same embedded-helper packaging path and then sign/notarize the app for Developer ID distribution.

## GitHub release automation

`.github/workflows/release.yml` is prepared to produce notarized GitHub release artifacts when these repository secrets are configured:

- `APPLE_DEVELOPER_ID_APPLICATION_NAME`
- `APPLE_DEVELOPER_ID_APPLICATION_P12`
- `APPLE_DEVELOPER_ID_APPLICATION_PASSWORD`
- `APPLE_NOTARY_APPLE_ID`
- `APPLE_NOTARY_TEAM_ID`
- `APPLE_NOTARY_PASSWORD`

Without those secrets, local and CI builds still package correctly, but direct-download zips will fail Gatekeeper notarization checks.
