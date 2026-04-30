# Signing and Notarization (post-v0.1.0)

This document describes the minimum steps to move from unsigned releases to trusted macOS distribution.

## Preconditions

- Active Apple Developer Program membership.
- `Developer ID Application` certificate installed in Keychain.
- App-specific password or App Store Connect API key for notarization.

## Recommended release flow

1. Build release artifact:
   - `scripts/release/package_release.sh vX.Y.Z`
2. Code sign the app bundle:
   - `codesign --force --deep --options runtime --sign "Developer ID Application: <Team Name>" dist/vX.Y.Z/MacMicWidget.app`
3. Verify signature:
   - `codesign --verify --deep --strict --verbose=2 dist/vX.Y.Z/MacMicWidget.app`
4. Submit for notarization:
   - `xcrun notarytool submit dist/vX.Y.Z/MacMicWidget-vX.Y.Z-macos-arm64-unsigned.zip --wait --apple-id <apple_id> --team-id <team_id> --password <app_specific_password>`
5. Staple ticket:
   - `xcrun stapler staple dist/vX.Y.Z/MacMicWidget.app`
6. Final assess:
   - `spctl --assess --type execute --verbose dist/vX.Y.Z/MacMicWidget.app`

## Notes

- The current package script intentionally produces an unsigned artifact for fast launch.
- Once signing/notarization are in place, rename output artifact to remove `-unsigned`.
- Keep release notes explicit about trust status until notarized artifacts are published.
