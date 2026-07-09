# Changelog

All notable user-facing changes to Mac Drag Scroll are tracked here.

This project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for public releases. `CFBundleShortVersionString` is the public app version, and `CFBundleVersion` is the monotonically increasing build number used by Sparkle.

## [Unreleased]

### Added

### Changed

### Fixed

## [1.0.0] - 2026-07-09

### Added

- Added Windows-style middle-mouse drag scrolling for external mice on macOS.
- Added menu bar app controls for enabling, disabling, settings, updates, and quitting.
- Added a Liquid Glass drag visualizer with size, intensity, tint, visibility, and animation controls.
- Added Launch at Login, ignored apps, trigger safety, scroll speed, acceleration, dead-zone, horizontal scrolling, and horizontal inversion settings.
- Added first-run welcome flow, Permissions, Updates, and About settings sections.
- Added Sparkle-based in-app updates backed by signed update archives.
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
