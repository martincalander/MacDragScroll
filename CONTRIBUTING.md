# Contributing

Thanks for helping improve Mac Drag Scroll. The main README is written for users; this file is for people changing the app or documentation.

## Project Direction

Mac Drag Scroll should stay small, reliable, and native-feeling:

- Prefer focused fixes over broad rewrites.
- Keep the app safe for trackpads and normal pointer behavior.
- Keep the menu bar experience quiet.
- Match the app name exactly as **Mac Drag Scroll** in user-facing text.
- Use `MacDragScroll` only where spaces are awkward, such as repository names or internal identifiers.

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

For CI-style local builds without signing:

```sh
xcodebuild build \
  -project macdragscroll.xcodeproj \
  -scheme macdragscroll \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

## Pull Requests

Before opening a pull request:

- Run the test command above.
- Keep UI changes consistent with the existing Liquid Glass direction.
- Include a short explanation of behavior changes.
- Add or update tests when changing scroll math, settings persistence, permissions, or update behavior.

## Release Notes

When a change affects users, add it to `CHANGELOG.md` under `Unreleased`.
