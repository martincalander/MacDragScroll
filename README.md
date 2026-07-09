<p align="center">
  <img src="docs/assets/mac-drag-scroll-icon.png" width="128" alt="Mac Drag Scroll app icon">
</p>

<h1 align="center">Mac Drag Scroll</h1>

<p align="center">
  <strong>Native-feeling middle-mouse drag scrolling for external mice on macOS.</strong>
</p>

<p align="center">
  Hold the middle mouse button, move the mouse, and glide through long pages, editors, timelines, and canvases without touching the wheel.
</p>

<p align="center">
  <a href="https://github.com/martincalander/MacDragScroll/actions/workflows/ci.yml"><img alt="Quality Gate" src="https://github.com/martincalander/MacDragScroll/actions/workflows/ci.yml/badge.svg?branch=main"></a>
  <a href="https://github.com/martincalander/MacDragScroll/actions/workflows/codeql.yml"><img alt="CodeQL" src="https://github.com/martincalander/MacDragScroll/actions/workflows/codeql.yml/badge.svg?branch=main"></a>
  <a href="https://scorecard.dev/viewer/?uri=github.com/martincalander/MacDragScroll"><img alt="OpenSSF Scorecard" src="https://api.scorecard.dev/projects/github.com/martincalander/MacDragScroll/badge"></a>
  <a href="https://github.com/martincalander/MacDragScroll/actions/workflows/secret-scan.yml"><img alt="Secret Scan" src="https://github.com/martincalander/MacDragScroll/actions/workflows/secret-scan.yml/badge.svg?branch=main"></a>
  <a href="https://github.com/martincalander/MacDragScroll/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/martincalander/MacDragScroll?display_name=tag&sort=semver"></a>
  <img alt="macOS 26.2+" src="https://img.shields.io/badge/macOS-26.2%2B-111111?logo=apple&logoColor=white">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-2f80ed.svg"></a>
</p>

<p align="center">
  <img src="docs/assets/mac-drag-scroll-hero.png" alt="Mac Drag Scroll Liquid Glass drag indicator preview">
</p>

<p align="center">
  <a href="https://github.com/martincalander/MacDragScroll/releases/latest"><strong>Download the latest release</strong></a>
</p>

<p align="center">
  English | <a href="README.ja.md">日本語</a> | <a href="README.zh-Hans.md">简体中文</a>
</p>

## Overview

Mac Drag Scroll is a small menu bar app that brings the familiar Windows middle-click drag scroll gesture to macOS. It is designed for external mice, stays out of the Dock, and keeps normal trackpad gestures untouched.

- **Drag to scroll:** press the middle mouse button, move away from the origin, and release to stop.
- **All-direction movement:** vertical, horizontal, and diagonal scrolling work from the same gesture.
- **Stable targeting:** scrolling stays tied to the window where the drag started.
- **Liquid Glass visualizer:** a compact glass origin marker reacts to direction, distance, double-clicks, and fast flicks.
- **Menu bar first:** keep it running quietly in the background, with Settings available when needed.
- **Trackpad-safe by design:** trackpad gestures are ignored, and unsafe primary/secondary click triggers require modifiers.
- **Recoverable diagnostics:** crash reports stay local and can be opened, copied, or cleared from Settings.

## Install

Recommended:

```sh
brew install --cask martincalander/tap/mac-drag-scroll
```

Manual install:

1. Open the [latest release](https://github.com/martincalander/MacDragScroll/releases/latest).
2. Download `MacDragScroll.dmg`.
3. Open the disk image and move **Mac Drag Scroll** to your Applications folder.
4. First launch only: right-click **Mac Drag Scroll** in Finder, choose **Open**, then confirm.
5. Approve Accessibility and Input Monitoring access when macOS asks.

<p align="center">
  <img src="docs/assets/mac-drag-scroll-install-demo.gif" width="760" alt="Mac Drag Scroll installation demo">
</p>

Current releases are unsigned and not Apple-notarized, so macOS may block the first launch. This is expected for the free release flow. You only need to use the right-click **Open** bypass once per downloaded build.

<p align="center">
  <img src="docs/assets/mac-drag-scroll-gatekeeper-bypass.gif" width="760" alt="How to open an unsigned Mac Drag Scroll build">
</p>

CLI install without Homebrew:

```sh
curl -fsSL https://github.com/martincalander/MacDragScroll/raw/main/install.sh | bash
```

## Grant Permissions

Mac Drag Scroll needs Accessibility and Input Monitoring permissions so it can detect the middle mouse button globally and send scroll events.

1. Open **System Settings**.
2. Go to **Privacy & Security**.
3. Open **Accessibility** and enable **Mac Drag Scroll**.
4. Open **Input Monitoring** and enable **Mac Drag Scroll**.
5. Quit and reopen Mac Drag Scroll if macOS asks for a restart.

<p align="center">
  <img src="docs/assets/mac-drag-scroll-permission-demo.gif" width="760" alt="Mac Drag Scroll permissions demo">
</p>

The app shows permission status in Settings, and it disables drag scrolling if either required permission is removed.

## Use

1. Press and hold the middle mouse button.
2. Move the mouse away from the starting point.
3. Release the middle mouse button to stop.

<p align="center">
  <img src="docs/assets/mac-drag-scroll-usage-demo.gif" width="760" alt="Mac Drag Scroll drag scrolling usage demo">
</p>

The farther you drag from the origin, the faster the scroll becomes. A small glass indicator appears while dragging unless you turn it off in Settings.

## Settings

Open Settings from the menu bar icon.

| Setting | What it changes |
| --- | --- |
| Enable | Turns Mac Drag Scroll on or off. |
| Keep in Menu Bar | Keeps the menu bar helper alive after closing Settings. |
| Speed | Adjusts the scroll speed. |
| Acceleration | Changes how quickly speed ramps up as you drag farther. |
| Dead zone | Sets the small area around the origin where scrolling has not started yet. |
| Visualizer | Controls size, opacity, tint, Liquid Glass intensity, and animation. |
| Launch at Login | Starts Mac Drag Scroll automatically when you sign in. |
| Excluded Apps | Keeps drag scrolling disabled in chosen apps. |
| Permissions | Shows Accessibility and Input Monitoring status, with repair shortcuts. |
| Updates | Checks GitHub Releases through Sparkle and shows version history. |

Settings are saved per macOS user at:

```text
~/Library/Preferences/com.martincalander.macdragscroll.plist
```

Mac Drag Scroll also mirrors recoverable app settings to:

```text
~/Library/Application Support/Mac Drag Scroll/Preferences.plist
```

Normal app removal, reinstall, Homebrew upgrades, and Sparkle updates leave these files alone, so preferences survive update and uninstall cycles.

## Diagnostics

If the app crashes, Settings shows a **Crash Reports** section with options to open the folder, copy the latest report, reveal the latest report, or clear saved reports.

Crash reports are stored locally at:

```text
~/Library/Application Support/Mac Drag Scroll/Crash Reports
```

macOS DiagnosticReports for Mac Drag Scroll are imported into that folder on the next launch when available.

## Privacy

Mac Drag Scroll is designed as a local utility. It needs Accessibility and Input Monitoring access for the drag-scroll gesture, but it does not record what you type, inspect document contents, or track your browsing.

Read the full [privacy note](PRIVACY.md).

## Updates

Use **Settings -> Updates** or the menu bar **Check For Update** command to check for new versions. Updates are verified by Sparkle and hosted on GitHub Releases.

The current free release flow is unsigned and not Apple-notarized. If macOS blocks a freshly downloaded build, use the Finder right-click **Open** flow shown above.

## Support

Need help? Start with [Support](SUPPORT.md), then open an issue if the problem is reproducible.

## Requirements

- macOS 26.2 or later
- External mouse with a middle button or scroll-wheel click
- Accessibility and Input Monitoring permissions

## Made By

Mac Drag Scroll is made by [Martin Calander](https://martincalander.com).

Developers and contributors can read [Contributing](CONTRIBUTING.md).

Release maintainers can read [Releasing](docs/RELEASING.md).
