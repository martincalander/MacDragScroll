# Changelog

All notable user-facing changes to Mac Drag Scroll are tracked here.

This project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for public releases. `CFBundleShortVersionString` is the public app version, and `CFBundleVersion` is the monotonically increasing build number used by Sparkle.

## [Unreleased]

### Added

- Added resilient preference backup storage so user settings can be restored from `~/Library/Application Support/Mac Drag Scroll/Preferences.plist` if the primary preferences domain is missing.
- Added local crash-report import for macOS `.crash` and `.ips` DiagnosticReports, alongside the existing in-app crash report tools.
- Added dedicated development and test preference domains so local debug builds and test runs do not overwrite production user settings.

### Changed

- The CLI installer now stages the new app bundle before replacing the installed copy, with rollback if the replacement fails.
- Settings and update preferences now persist through a shared preference layer instead of direct scattered writes.

### Fixed

- Fixed local options appearing to reset after updates or development builds by anchoring production settings to `com.martincalander.macdragscroll` and mirroring recoverable values.
- Fixed automated tests polluting the real per-user Mac Drag Scroll preferences on development machines.
- Improved crash logging reliability by relying on safe exception handling plus macOS DiagnosticReports import instead of unsafe Swift work inside POSIX signal handlers.

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
