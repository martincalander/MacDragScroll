# Releasing Mac Drag Scroll

Mac Drag Scroll currently ships as an unsigned macOS app with Sparkle-verified updates.

This release flow does not require a paid Apple Developer Program account. Because the app is not Developer ID signed or notarized, macOS may block the first launch for most users. The install instructions document the standard Finder bypass: right-click the app, choose **Open**, then confirm.

## Strategy

- **In-app updates:** Sparkle 2 verifies and installs update archives from the GitHub release appcast.
- **Manual installer:** each release publishes `MacDragScroll.dmg` with the app and an Applications shortcut.
- **CLI install:** `install.sh` downloads the latest `MacDragScroll.zip` release asset, verifies the checksum when available, stages the app, and installs it into `/Applications`.
- **Homebrew:** publish `packaging/homebrew/Casks/mac-drag-scroll.rb` to `martincalander/homebrew-tap`. The cask downloads the same `MacDragScroll.zip` asset and sets `auto_updates true`.
- **Release integrity:** each release publishes a detached Sparkle EdDSA signature and GitHub build-provenance bundle alongside the app archives.

GitHub Releases is the source of truth. The appcast URL embedded in the app is:

```text
https://github.com/martincalander/MacDragScroll/releases/latest/download/appcast.xml
```

User preferences live in:

```text
~/Library/Preferences/com.martincalander.macdragscroll.plist
~/Library/Application Support/Mac Drag Scroll/Preferences.plist
```

Installers, Sparkle updates, and the Homebrew cask intentionally leave these files alone so settings survive uninstall, reinstall, and app updates. Debug builds use a separate development domain, and tests use per-process domains.

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

For `1.0.0`, the build number starts at `100`. The current public line is:

- `1.0.4` -> build `104`

A practical next sequence is:

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
4. Update `packaging/homebrew/Casks/mac-drag-scroll.rb` to the same version.
5. Update `UpdateManager.versionHistory` so the latest row matches the shipped app build.
6. Run `scripts/extract-release-notes.sh <version>` and confirm it prints useful notes.

## Required GitHub Secret

The release workflow only needs the Sparkle EdDSA private key:

```text
SPARKLE_PRIVATE_KEY
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

Use Sparkle `2.9.4` for that command, matching the app package dependency and release workflow.

Never commit the private key, exported key files, or workflow logs containing the private key.

Apple Developer ID signing and notarization can be added later, but they are intentionally not required by the current workflow.

## Release

1. Confirm the app builds and tests locally:

```sh
xcodebuild test \
  -project macdragscroll.xcodeproj \
  -scheme macdragscroll \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/MacDragScroll-Test

xcodebuild analyze \
  -project macdragscroll.xcodeproj \
  -scheme macdragscroll \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/MacDragScroll-Analyze

xcodebuild build \
  -project macdragscroll.xcodeproj \
  -scheme macdragscroll \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/MacDragScroll-Release

bash -n install.sh scripts/*.sh
scripts/validate-homebrew-cask.sh
scripts/check-release-readiness.sh <version>
```

2. Commit and push the release changes to `main`.

3. Publish the release tag:

```sh
scripts/publish-release.sh <version>
```

4. The `Release` GitHub Actions workflow will:

- verify the tag matches `MARKETING_VERSION`;
- run tests;
- build the Release app;
- apply an ad-hoc local code signature for bundle consistency;
- create `MacDragScroll.zip`;
- create `MacDragScroll.dmg`;
- generate the Sparkle appcast;
- publish the archive's detached Sparkle signature as `MacDragScroll.zip.sig`;
- create `SHA256SUMS.txt`;
- attest the release files and publish `MacDragScroll.intoto.jsonl` for offline verification;
- publish/update the GitHub release and its assets through GoReleaser.

## Verify A Release

After the workflow completes:

```sh
curl -I https://github.com/martincalander/MacDragScroll/releases/latest/download/appcast.xml
curl -I https://github.com/martincalander/MacDragScroll/releases/latest/download/MacDragScroll.zip
curl -I https://github.com/martincalander/MacDragScroll/releases/latest/download/MacDragScroll.zip.sig
curl -fsSL https://github.com/martincalander/MacDragScroll/releases/latest/download/SHA256SUMS.txt

release_dir="$(mktemp -d)"
gh release download --repo martincalander/MacDragScroll --dir "$release_dir"
gh attestation verify "$release_dir/MacDragScroll.zip" --repo martincalander/MacDragScroll
```

The detached `.sig` contains the same Sparkle EdDSA signature embedded in `appcast.xml`. The `.intoto.jsonl` file is the portable GitHub attestation bundle. These supply-chain signatures do not replace Apple Developer ID signing or notarization, so Gatekeeper can still require the documented first-launch bypass.

Install from CLI:

```sh
curl -fsSL https://github.com/martincalander/MacDragScroll/raw/main/install.sh | bash
```

Install from Homebrew after the tap has been updated:

```sh
brew install --cask martincalander/tap/mac-drag-scroll
```

To test Sparkle, run an older installed build and choose **Check For Update** from the menu bar.

## Homebrew Tap

The tap repo is [martincalander/homebrew-tap](https://github.com/martincalander/homebrew-tap). Users can install with:

```sh
brew install --cask martincalander/tap/mac-drag-scroll
```

For future releases, copy the updated cask into the tap repo after the GitHub release exists:

```sh
git clone https://github.com/martincalander/homebrew-tap.git
cp packaging/homebrew/Casks/mac-drag-scroll.rb homebrew-tap/Casks/mac-drag-scroll.rb
cd homebrew-tap
git add Casks/mac-drag-scroll.rb
git commit -m "Update Mac Drag Scroll cask"
git push origin main
```

The cask uses `sha256 :no_check` because the GitHub release asset is checked by the release workflow and the app updates itself through Sparkle.
