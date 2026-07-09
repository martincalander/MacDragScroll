# Releasing Mac Drag Scroll

Mac Drag Scroll ships as a signed, notarized macOS app with Sparkle updates.

## Strategy

- **In-app updates:** Sparkle 2 installs signed update archives from the GitHub release appcast.
- **Manual installer:** each release publishes `MacDragScroll.dmg` with the app and an Applications shortcut.
- **CLI install:** `scripts/install.sh` downloads the latest `MacDragScroll.zip` release asset and installs it into `/Applications`.
- **Homebrew:** publish `packaging/homebrew/Casks/mac-drag-scroll.rb` to a separate `martincalander/homebrew-tap` repo after the first release exists. The cask downloads the same `MacDragScroll.zip` asset and sets `auto_updates true`.

GitHub Releases is the source of truth. The appcast URL embedded in the app is:

```text
https://github.com/martincalander/MacDragScroll/releases/latest/download/appcast.xml
```

User preferences live in `~/Library/Preferences/com.martincalander.macdragscroll.plist`. Installers and the Homebrew cask intentionally leave this file alone so settings survive uninstall/reinstall and app updates.

## Versioning

Use SemVer for public releases:

```text
MAJOR.MINOR.PATCH
```

Examples:

- `1.0.1`: bug fixes only.
- `1.1.0`: new user-facing feature, backwards compatible.
- `2.0.0`: breaking behavior or major redesign.

The app has two version fields:

- `MARKETING_VERSION` -> `CFBundleShortVersionString`, shown to users.
- `CURRENT_PROJECT_VERSION` -> `CFBundleVersion`, used by Sparkle and must increase on every shipped build.

For `1.0.0`, the build number starts at `100`. A practical next sequence is:

- `1.0.1` -> build `101`
- `1.1.0` -> build `110`
- `2.0.0` -> build `200`

## Changelog

Every user-facing change goes into `CHANGELOG.md`.

Keep this structure:

```markdown
## [Unreleased]

### Added

### Changed

### Fixed

## [1.0.1] - YYYY-MM-DD
```

Before tagging a release:

1. Move relevant `Unreleased` entries into a new version section.
2. Set the release date.
3. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
4. Run `scripts/extract-release-notes.sh 1.0.1` and confirm it prints useful notes.

## Required GitHub Secrets

The release workflow needs these repository secrets:

```text
APPLE_ID
APPLE_APP_SPECIFIC_PASSWORD
APPLE_TEAM_ID
MACOS_CERTIFICATE_P12
MACOS_CERTIFICATE_PASSWORD
SPARKLE_PRIVATE_KEY
```

`MACOS_CERTIFICATE_P12` is a base64-encoded Developer ID Application certificate export:

```sh
base64 -i DeveloperIDApplication.p12 | pbcopy
```

To set the Apple secrets from an exported `.p12` file:

```sh
scripts/set-apple-release-secrets.sh ~/Desktop/DeveloperIDApplication.p12 "$P12_PASSWORD" "you@example.com" "$APP_SPECIFIC_PASSWORD"
```

`SPARKLE_PRIVATE_KEY` is the exported Sparkle EdDSA private key. The public key embedded in the app is:

```text
IRTPmGbPo3tpWiuGZIjzn99mFwiCjaCCPw6Kz62hkvQ=
```

Export the matching private key from the Mac where it was generated:

```sh
./bin/generate_keys --account com.martincalander.macdragscroll -x sparkle_private_key.txt
pbcopy < sparkle_private_key.txt
rm sparkle_private_key.txt
```

Use Sparkle `2.9.4` for that command, matching the vendored framework.

## Release

1. Confirm the app builds and tests locally:

```sh
xcodebuild test -project macdragscroll.xcodeproj -scheme macdragscroll -destination 'platform=macOS'
scripts/check-release-readiness.sh 1.0.0
```

2. Commit the release changes.

3. Tag the release:

```sh
git tag v1.0.0
git push origin main --tags
```

4. The `Release` GitHub Actions workflow will:

- verify the tag matches `MARKETING_VERSION`;
- run tests;
- archive and export a Developer ID app;
- notarize and staple the app;
- create `MacDragScroll.zip`;
- create `MacDragScroll.dmg`;
- generate signed `appcast.xml`;
- publish/update the GitHub release.

## Verify A Release

After the workflow completes:

```sh
curl -I https://github.com/martincalander/MacDragScroll/releases/latest/download/appcast.xml
curl -I https://github.com/martincalander/MacDragScroll/releases/latest/download/MacDragScroll.zip
curl -fsSL https://github.com/martincalander/MacDragScroll/releases/latest/download/SHA256SUMS.txt
```

Install from CLI:

```sh
curl -fsSL https://raw.githubusercontent.com/martincalander/MacDragScroll/main/scripts/install.sh | bash
```

To test Sparkle, run an older installed build and choose **Check For Update** from the menu bar.

## Homebrew Tap

After `v1.0.0` is published, create a tap repo once:

```sh
gh repo create martincalander/homebrew-tap --public --clone
mkdir -p homebrew-tap/Casks
cp packaging/homebrew/Casks/mac-drag-scroll.rb homebrew-tap/Casks/
cd homebrew-tap
git add Casks/mac-drag-scroll.rb
git commit -m "Add Mac Drag Scroll cask"
git push origin main
```

Users can then install with:

```sh
brew tap martincalander/tap
brew install --cask mac-drag-scroll
```

For future releases, update `version` in the cask and commit it to the tap. The cask uses `sha256 :no_check` because the Sparkle-signed app archive is the trust boundary and the app auto-updates itself.
