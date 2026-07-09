<p align="center">
  <img src="docs/assets/mac-drag-scroll-icon.png" width="128" alt="Mac Drag Scroll app icon">
</p>

<h1 align="center">Mac Drag Scroll</h1>

<p align="center">
  <strong>Windows-style drag scrolling for external mice on macOS.</strong>
</p>

<p align="center">
  Hold the middle mouse button, move the mouse, and scroll in any direction without touching the wheel.
</p>

<p align="center">
  <a href="https://github.com/martincalander/MacDragScroll/actions/workflows/ci.yml"><img alt="Quality Gate" src="https://github.com/martincalander/MacDragScroll/actions/workflows/ci.yml/badge.svg?branch=main"></a>
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

## What It Does

Mac Drag Scroll brings the familiar Windows middle-click drag scroll gesture to macOS. It is built for people who use an external mouse and want fast, comfortable scrolling in long pages, code editors, spreadsheets, design canvases, and chat apps.

- **Hold and drag to scroll**: press the middle mouse button and move in the direction you want to scroll.
- **Works in any direction**: vertical, horizontal, or diagonal scrolling from the same gesture.
- **Keeps the original window active**: scrolling stays targeted at the window where the drag started.
- **Small Liquid Glass indicator**: a subtle origin marker shows where the drag began and how far you are pulling.
- **Lives in the menu bar**: no dock clutter while the app is running in the background.
- **Built for safety**: it avoids trackpad gestures and only listens for the configured mouse trigger.

## Install

1. Open the [latest release](https://github.com/martincalander/MacDragScroll/releases/latest).
2. Download `MacDragScroll.dmg`.
3. Open the disk image and move **Mac Drag Scroll** to your Applications folder.
4. First launch only: right-click **Mac Drag Scroll** in Finder, choose **Open**, then confirm.
5. Approve Accessibility access when macOS asks.

<p align="center">
  <img src="docs/assets/mac-drag-scroll-install-demo.gif" width="760" alt="Mac Drag Scroll installation demo">
</p>

Current releases are unsigned and not Apple-notarized, so macOS may block the first launch. This is expected for the free release flow. You only need to use the right-click **Open** bypass once per downloaded build.

<p align="center">
  <img src="docs/assets/mac-drag-scroll-gatekeeper-bypass.gif" width="760" alt="How to open an unsigned Mac Drag Scroll build">
</p>

CLI install:

```sh
curl -fsSL https://raw.githubusercontent.com/martincalander/MacDragScroll/main/scripts/install.sh | bash
```

Homebrew tap support is prepared for release maintainers; see [Releasing](docs/RELEASING.md).

## Grant Permission

Mac Drag Scroll needs Accessibility permission so it can detect the middle mouse button and send scroll events.

1. Open **System Settings**.
2. Go to **Privacy & Security**.
3. Open **Accessibility**.
4. Enable **Mac Drag Scroll**.

<p align="center">
  <img src="docs/assets/mac-drag-scroll-permission-demo.gif" width="760" alt="Mac Drag Scroll Accessibility permission demo">
</p>

The app shows permission status in Settings, and it disables drag scrolling if permission is removed.

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
| Speed | Adjusts the scroll speed. |
| Acceleration | Changes how quickly speed ramps up as you drag farther. |
| Dead zone | Sets the small area around the origin where scrolling has not started yet. |
| Visualizer size | Makes the drag indicator larger or smaller. |
| Liquid Glass | Controls the glass-style drag visual. |
| Launch at Login | Starts Mac Drag Scroll automatically when you sign in. |
| Excluded Apps | Keeps drag scrolling disabled in chosen apps. |

Settings are saved per macOS user at `~/Library/Preferences/com.martincalander.macdragscroll.plist`. Normal app removal or reinstall does not delete this file, so preferences survive uninstall and upgrade cycles.

## Privacy

Mac Drag Scroll is designed as a local utility. It needs Accessibility access for the drag-scroll gesture, but it does not record what you type, inspect document contents, or track your browsing.

Read the full [privacy note](PRIVACY.md).

## Updates

Use **Settings -> Updates** or the menu bar **Check For Update** command to check for new versions. Updates are verified by Sparkle and hosted on GitHub Releases. The app is not Apple-notarized unless a future release says otherwise.

## Support

Need help? Start with [Support](SUPPORT.md), then open an issue if the problem is reproducible.

## Requirements

- macOS 26.2 or later
- External mouse with a middle button or scroll-wheel click
- Accessibility permission

## Made By

Mac Drag Scroll is made by [Martin Calander](https://martincalander.com).

Developers and contributors can read [Contributing](CONTRIBUTING.md).

Release maintainers can read [Releasing](docs/RELEASING.md).
