# Architecture

Mac Drag Scroll is a native macOS menu bar utility. It converts a configured external-mouse drag into marked synthetic scroll events while preserving normal clicks, trackpad gestures, and app-specific exclusions.

## Components

- `AppDelegate` owns application lifecycle, permissions, menu bar state, the settings and welcome windows, and the single-instance guard.
- `MouseMonitor` owns the global event tap. It validates the trigger, input source, active application, target window, and permission state before starting a drag session.
- `ScrollPhysics` converts cursor displacement from the drag origin into bounded horizontal and vertical scroll deltas.
- `ScrollOverlayWindow` renders the optional visualizer without accepting input or becoming the active app. macOS 26 uses native Liquid Glass; macOS 14 and 15 use a native vibrancy fallback behind the same custom reflections and motion.
- `SettingsWindow` owns the settings shell and tab navigation. Reusable rows, ignored-app picking, and the visualizer preview live in focused companion files.
- `SettingsManager` exposes user preferences. `PersistentPreferences` keeps the production domain stable and mirrors recoverable values to Application Support.
- `UpdateManager` integrates Sparkle with the GitHub-hosted appcast and release history.
- `CrashHandler` stores local exception reports and imports matching macOS DiagnosticReports for user-controlled sharing.

## Input Flow

1. The event tap receives a mouse event.
2. `MouseMonitor` rejects trackpad/tablet input, unsafe primary-button triggers, excluded apps, missing permissions, and events marked as synthetic by Mac Drag Scroll.
3. A valid press records the origin, target process, target window, and trigger state.
4. Mouse movement is converted by `ScrollPhysics`; the overlay follows the same session state.
5. Synthetic scroll events carry a private marker so the event tap cannot consume its own output.
6. Release, cancellation, permission loss, app changes, or target-window changes end the session and restore normal pointer behavior.

## Safety Invariants

- Default activation accepts only an external mouse middle button. Trackpad and tablet events never begin a session.
- Left- or right-button triggers require a modifier and must not replace ordinary clicks.
- A session remains scoped to the process and window where it began.
- Ignored apps are checked before activation and while a session is active.
- Permission loss, event-tap failure, display changes, and duplicate app instances fail closed.
- Settings and visualizer animation choices affect presentation, not input-source safety.

## Storage And Distribution

- Preferences: `~/Library/Preferences/com.martincalander.macdragscroll.plist`
- Recoverable preference backup: `~/Library/Application Support/Mac Drag Scroll/Preferences.plist`
- Crash reports: `~/Library/Application Support/Mac Drag Scroll/Crash Reports`
- Updates: Sparkle verifies the signed ZIP from GitHub Releases. Releases also include checksums and GitHub build provenance.

## Verification

The test target covers input classification, trigger safety, scroll calculations, settings persistence, permissions, update state, release metadata, and crash-report handling. GitHub Actions enforces strict compiler warnings, dependency review, code coverage reporting, concurrent preference fuzz-corpus execution under Thread Sanitizer, Xcode static analysis, universal macOS 14+ release builds, release-readiness checks, CodeQL, Gitleaks, fuzz-harness compilation, and OpenSSF Scorecard analysis.
