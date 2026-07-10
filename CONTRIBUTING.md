# Contributing

Thanks for helping improve Mac Drag Scroll. The main README is written for users; this file is for people changing the app or documentation.

## Project Direction

Mac Drag Scroll should stay small, reliable, and native-feeling:

- Prefer focused fixes over broad rewrites.
- Keep the app safe for trackpads and normal pointer behavior.
- Keep the menu bar experience quiet.
- Match the app name exactly as **Mac Drag Scroll** in user-facing text.
- Use `MacDragScroll` only where spaces are awkward, such as repository names or internal identifiers.
- Treat settings persistence, permissions, and input handling as reliability-sensitive code.
- Keep public docs clear enough for non-developers; avoid exposing implementation detail unless it helps users make a decision.

## Requirements

- macOS 26.2 or later
- Xcode 26.2 or later

## Build And Test

Open `macdragscroll.xcodeproj` in Xcode, or run:

```sh
xcodebuild test \
  -project macdragscroll.xcodeproj \
  -scheme macdragscroll \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/MacDragScrollDerivedData
```

For CI-style local builds and static analysis:

```sh
xcodebuild build \
  -project macdragscroll.xcodeproj \
  -scheme macdragscroll \
  -destination 'platform=macOS' \
  -configuration Release \
  CODE_SIGNING_ALLOWED=NO

xcodebuild analyze \
  -project macdragscroll.xcodeproj \
  -scheme macdragscroll \
  -destination 'platform=macOS'
```

Use separate `-derivedDataPath` values when running multiple `xcodebuild` commands at the same time.

Swift fuzz harnesses live in `Fuzzers/`. To verify they still compile:

```sh
scripts/check-fuzz-harnesses.sh
```

## Local Settings

Release builds use:

```text
~/Library/Preferences/com.martincalander.macdragscroll.plist
~/Library/Application Support/Mac Drag Scroll/Preferences.plist
```

Debug builds use `com.martincalander.macdragscroll.development` and a separate Application Support folder. Tests use per-process test domains. This keeps local development from overwriting a user's production settings.

## Pull Requests

Before opening a pull request:

- Run the test command above.
- Keep UI changes consistent with the existing Liquid Glass direction.
- Include a short explanation of behavior changes.
- Add or update tests when changing scroll math, settings persistence, permissions, or update behavior.
- Update `README.md`, localized READMEs, `SUPPORT.md`, or `PRIVACY.md` when behavior changes what users need to know.

Mac Drag Scroll is currently a solo-maintainer project, so required PR approval is not enforced yet. Independent required review should be enabled if or when trusted collaborators are available.

## Documentation Style

- Use **Mac Drag Scroll** in prose.
- Use short sections, direct verbs, and concrete file paths where they help troubleshooting.
- Keep installation steps aligned across `README.md`, `README.ja.md`, and `README.zh-Hans.md`.
- Keep release-process details in `docs/RELEASING.md`, not in the main README.

## Coding Standards

- Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
- Preserve the existing AppKit and SwiftUI ownership boundaries described in `ARCHITECTURE.md`.
- Treat compiler warnings and static-analysis findings as defects; do not suppress them without a documented reason.
- Prefer small, testable helpers for input classification, persistence normalization, and release-sensitive behavior.
- Add comments only where a safety invariant or platform limitation is not evident from the code.

## Release Notes

When a change affects users, add it to `CHANGELOG.md` under `Unreleased`.
