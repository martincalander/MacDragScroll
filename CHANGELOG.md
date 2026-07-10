# Changelog

All notable user-facing changes to Mac Drag Scroll are tracked here.

This project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for public releases. `CFBundleShortVersionString` is the public app version, and `CFBundleVersion` is the monotonically increasing build number used by Sparkle.

## [Unreleased]

## [1.1.0] - 2026-07-10

### Changed

- Lowered the supported runtime requirement to macOS 14 while retaining native Liquid Glass on macOS 26 and a native material fallback on earlier systems.
- Expanded the required quality gate with strict compiler warnings, dependency review, deterministic Swift fuzz execution under macOS Guard Malloc, Xcode static analysis, code coverage reporting, and universal Intel/Apple Silicon compatibility verification.
- Auto Update now enables Sparkle's automatic update downloads as well as scheduled checks.
- Release signing tools are checksum-verified before the Sparkle private key is made available.
- The Homebrew cask now verifies the exact release archive checksum.
- The CLI installer now stops instead of installing an archive without a valid published checksum.
- Permission, update, and crash-report screens are now fully translated in every bundled language.
- The project landing pages now use descriptive product artwork, artifact-free demos, and complete install, trust, build, and contributor guidance in English, Japanese, and Simplified Chinese.

### Fixed

- Cancel active scrolling when macOS disables the event tap so stale drag state cannot keep scrolling after the tap is restored.
- Keep cleared macOS crash reports from being imported again on the next launch while still importing newer reports.

## [1.0.7] - 2026-07-10

### Fixed

- Replaced corrupted `NaN` and infinite numeric preferences with safe defaults before they can affect scrolling or visualizer calculations.

## [1.0.6] - 2026-07-10

### Fixed

- Prevented drag scrolling from capturing mouse shortcuts when extra Command, Option, Control, or Shift modifiers are held beyond the configured trigger chord.

## [1.0.5] - 2026-07-10

### Fixed

- Moved crash reports to the documented `Mac Drag Scroll` Application Support folder and safely migrated reports created in the legacy `MacDragScroll` folder.

## [1.0.4] - 2026-07-09

### Added

- Added a quiet update check on every app launch when Auto Update is enabled.

### Changed

- GitHub release assets are now published through a pinned GoReleaser action after the existing Xcode build, Sparkle signing, checksums, and provenance steps complete.

## [1.0.3] - 2026-07-09

### Added

- Added resilient preference backup storage so user settings can be restored from `~/Library/Application Support/Mac Drag Scroll/Preferences.plist` if the primary preferences domain is missing.
- Added local crash-report import for macOS `.crash` and `.ips` DiagnosticReports, alongside the existing in-app crash report tools.
- Added dedicated development and test preference domains so local debug builds and test runs do not overwrite production user settings.
- Added OpenSSF Scorecard and Gitleaks security scans with README badges.
- Added CodeQL Swift static analysis and pinned GitHub Action dependencies for supply-chain hardening.
- Added a Swift fuzz harness for preference-input parsing and normalization paths.
- Added directional Settings tab transitions with subtle vertical movement based on the previous tab position.
- Added OpenSSF Best Practices BadgeApp prefill metadata, README badges, and documented the remaining Scorecard CII and contributor-organization remediation steps.
- Added Scorecard notes for solo-maintainer code review and macOS packaging detection limits.

### Changed

- The CLI installer now stages the new app bundle before replacing the installed copy, with rollback if the replacement fails.
- Settings and update preferences now persist through a shared preference layer instead of direct scattered writes.
- Sparkle is now resolved as an exact Swift Package dependency instead of storing the binary framework in the source repository.
- Changed the About logo to an in-place squishy interaction instead of a draggable export item.
- Consolidated the README workflow badges into one `Checks 3/3` aggregate badge.

### Fixed

- Fixed local options appearing to reset after updates or development builds by anchoring production settings to `com.martincalander.macdragscroll` and mirroring recoverable values.
- Fixed automated tests polluting the real per-user Mac Drag Scroll preferences on development machines.
- Improved crash logging reliability by relying on safe exception handling plus macOS DiagnosticReports import instead of unsafe Swift work inside POSIX signal handlers.
- Fixed the Settings red close button leaving Mac Drag Scroll visible in the Dock while the menu bar helper stayed active.

## [1.0.2] - 2026-07-09

### Added

- Added a dedicated Version History view in Updates.
- Added a hidden diagnostic Update Log that can be revealed when Sparkle troubleshooting is needed.

### Changed

- Updates now shows release history by default instead of showing raw update-check events.

### Fixed

- Kept the bundled version history covered by tests so the current release row stays aligned with the app build.

## [1.0.1] - 2026-07-09

### Added

- Added a General setting to keep Mac Drag Scroll running in the menu bar after closing Settings.
- Added clearer permission setup for Accessibility and Input Monitoring, including app-copy reveal and restart repair actions.

### Changed

- Settings now opens to General from the menu bar, with keep-running behavior surfaced near the top.
- Permission and welcome screens now show both required macOS permissions instead of only Accessibility.

### Fixed

- Fixed cases where granted Accessibility access still left drag scrolling blocked by missing Input Monitoring.
- Fixed up-to-date Sparkle checks being shown as update failures.
- Fixed last-window-close behavior so the app stays alive unless Quit is chosen from the menu bar.

## [1.0.0] - 2026-07-09

### Added

- Added Windows-style middle-mouse drag scrolling for external mice on macOS.
- Added menu bar app controls for enabling, disabling, settings, updates, and quitting.
- Added a Liquid Glass drag visualizer with size, intensity, tint, visibility, and animation controls.
- Added Launch at Login, ignored apps, trigger safety, scroll speed, acceleration, dead-zone, horizontal scrolling, and horizontal inversion settings.
- Added first-run welcome flow, Permissions, Updates, and About settings sections.
- Added Sparkle-based in-app updates backed by verified update archives.
- Added localized settings UI across the bundled languages.
- Added branded app icon, dock icon, menu bar icon, and About logo.
- Added duplicate-instance monitoring and warnings.
- Added GitHub Actions quality checks and user documentation.

### Changed

- Treat this polished product state as the first stable public release.
- Standardized update/version reporting around `1.0.0` plus an internal build number.

### Fixed

- Improved scroll reliability around trackpads, screen changes, permission changes, and ignored apps.
- Fixed visualizer origin centering and reduced visual clutter in the drag indicator.
