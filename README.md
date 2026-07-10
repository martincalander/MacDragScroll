<p align="center">
  <img src="docs/assets/mac-drag-scroll-icon.png" width="112" alt="Mac Drag Scroll app icon">
</p>

<h1 align="center">Mac Drag Scroll</h1>

<p align="center">
  <strong>Middle-button drag scrolling that feels at home on macOS.</strong><br>
  Hold the wheel, move the mouse, and glide through long pages, editors, timelines, and canvases.
</p>

<p align="center">
  <a href="https://github.com/martincalander/MacDragScroll/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/martincalander/MacDragScroll?display_name=tag&sort=semver"></a>
  <a href="https://github.com/martincalander/MacDragScroll/actions/workflows/checks-summary.yml"><img alt="Checks 3/3" src="https://github.com/martincalander/MacDragScroll/actions/workflows/checks-summary.yml/badge.svg?branch=main"></a>
  <a href="https://scorecard.dev/viewer/?uri=github.com/martincalander/MacDragScroll"><img alt="OpenSSF Scorecard" src="https://api.scorecard.dev/projects/github.com/martincalander/MacDragScroll/badge"></a>
  <a href="https://www.bestpractices.dev/projects/13546"><img alt="OpenSSF Best Practices" src="https://www.bestpractices.dev/projects/13546/badge"></a>
  <img alt="macOS 14 or later" src="https://img.shields.io/badge/macOS-14%2B-111111?logo=apple&logoColor=white">
  <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/badge/license-MIT-2f80ed.svg"></a>
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.ja.md">日本語</a> · <a href="README.zh-Hans.md">简体中文</a>
</p>

<p align="center">
  <img src="docs/assets/mac-drag-scroll-hero.png" alt="Mac Drag Scroll controlling a long document with a compact Liquid Glass drag indicator">
</p>

<p align="center">
  <strong><a href="https://github.com/martincalander/MacDragScroll/releases/latest">Download for macOS</a></strong>
  &nbsp;·&nbsp;
  <a href="#quick-start">Install with Homebrew</a>
  &nbsp;·&nbsp;
  <a href="#build-from-source">Build from source</a>
</p>

Mac Drag Scroll brings the familiar Windows-style middle-click drag gesture to an external mouse on macOS. It is a small native menu bar utility: no account, no cloud service, and no interference with normal trackpad gestures.

## See It in Action

<p align="center">
  <img src="docs/assets/mac-drag-scroll-usage-demo.gif" width="800" alt="Hold the middle mouse button, drag to scroll, flick to reverse, and release to stop">
</p>

Press and hold the middle mouse button, then move away from the origin. Distance controls speed, direction controls the scroll vector, and releasing stops immediately. The compact visualizer can be resized, restyled, animated, or turned off.

## Why Mac Drag Scroll

| | |
| --- | --- |
| **Natural control** | Scroll vertically, horizontally, or diagonally with one continuous gesture. |
| **Stable targeting** | The gesture stays attached to the window where the drag began. |
| **External-mouse focus** | Trackpad gestures are ignored instead of being intercepted or remapped. |
| **Responsive feedback** | The one-dot Liquid Glass visualizer reacts to direction, distance, double-clicks, and fast reversals. |
| **Menu bar native** | Run quietly in the background and open Settings only when needed. |
| **Made to recover** | Permission repair, persistent preferences, local diagnostics, and verified updates are built in. |

## Quick Start

### Homebrew

```sh
brew install --cask martincalander/tap/mac-drag-scroll
```

### Direct Download

1. Download `MacDragScroll.dmg` from the [latest release](https://github.com/martincalander/MacDragScroll/releases/latest).
2. Open the disk image and drag **Mac Drag Scroll** into **Applications**.
3. Right-click the app in Finder, choose **Open**, then confirm the first launch.
4. Grant Accessibility and Input Monitoring access when macOS asks.

<p align="center">
  <img src="docs/assets/mac-drag-scroll-install-demo.gif" width="800" alt="Drag Mac Drag Scroll into the Applications folder">
</p>

<details>
<summary><strong>Why does the first launch require right-click → Open?</strong></summary>

Current releases are not Apple-notarized because notarization requires a paid Apple Developer membership. macOS may therefore block a normal double-click on a newly downloaded build. In Finder, right-click **Mac Drag Scroll**, choose **Open**, and confirm. This is required once for each downloaded build.

The project still publishes Sparkle signatures and GitHub build provenance so release files can be verified independently. See [Security](SECURITY.md) and [Releasing](docs/RELEASING.md).
</details>

<details>
<summary><strong>Install without Homebrew</strong></summary>

```sh
curl -fsSL https://github.com/martincalander/MacDragScroll/raw/main/install.sh | bash
```
</details>

## Grant Permissions

Mac Drag Scroll needs two macOS permissions: **Input Monitoring** detects the external mouse button globally, and **Accessibility** sends scroll events to the target window. It does not use these permissions to record typing or inspect content.

<p align="center">
  <img src="docs/assets/mac-drag-scroll-permission-demo.gif" width="800" alt="Enable Accessibility and Input Monitoring for Mac Drag Scroll">
</p>

Open **System Settings → Privacy & Security**, enable Mac Drag Scroll under both **Accessibility** and **Input Monitoring**, then reopen the app if macOS requests it. The Permissions tab shows live status and provides repair shortcuts.

## Tune the Feel

Open Settings from the menu bar icon.

| Setting | What it controls |
| --- | --- |
| Speed and acceleration | Base scroll rate and how quickly it increases with drag distance. |
| Dead zone | The neutral area around the gesture origin. |
| Trigger | Middle click by default, with guarded alternatives for primary and secondary buttons. |
| Visualizer | Size, opacity, tint, glass intensity, and motion effects. |
| Excluded apps | Applications where drag scrolling should stay disabled. |
| Launch behavior | Login startup and whether the helper remains in the menu bar. |
| Updates | Automatic checks, release history, and manual update controls. |

Preferences are stored per macOS user and survive app updates and normal uninstall/reinstall cycles. Details and recovery paths are documented in [Support](SUPPORT.md).

## Built for Trust

- **Local by design:** no account, analytics, advertising, or cloud backend.
- **Narrow input scope:** only the configured mouse trigger starts scrolling; trackpad gestures are filtered out.
- **Permission aware:** scrolling disables itself when required access is missing or revoked.
- **Inspectable releases:** automated checks, secret scanning, CodeQL, Sparkle signatures, and GitHub attestations run through the public repository.
- **Private diagnostics:** crash reports stay on the Mac until the user chooses to share them.

Read [Privacy](PRIVACY.md), [Security](SECURITY.md), and the implementation [Architecture](ARCHITECTURE.md).

## Build from Source

Requirements: macOS 14 or later and Xcode 26.2 or later.

```sh
git clone https://github.com/martincalander/MacDragScroll.git
cd MacDragScroll
xcodebuild -project macdragscroll.xcodeproj \
  -scheme macdragscroll \
  -configuration Debug \
  build
```

Run the test suite with:

```sh
xcodebuild -project macdragscroll.xcodeproj \
  -scheme macdragscroll \
  -destination 'platform=macOS' \
  test
```

Contributions are welcome. Start with [Contributing](CONTRIBUTING.md), the [Code of Conduct](CODE_OF_CONDUCT.md), and the [Roadmap](ROADMAP.md).

## Project Guide

| Resource | Purpose |
| --- | --- |
| [Support](SUPPORT.md) | Permission repair, diagnostics, and common questions. |
| [Architecture](ARCHITECTURE.md) | Runtime boundaries, safety invariants, and event flow. |
| [Privacy](PRIVACY.md) | What the app can access and what it never collects. |
| [Security](SECURITY.md) | Vulnerability reporting and release verification. |
| [Governance](GOVERNANCE.md) | Maintainer roles, review policy, and project decisions. |
| [Changelog](CHANGELOG.md) | Version history and release notes. |
| [Scorecard notes](docs/SCORECARD.md) | OpenSSF posture, controls, and current limitations. |
| [Releasing](docs/RELEASING.md) | Maintainer release and provenance process. |

## Requirements

- macOS 14 or later
- An external mouse with a middle button or clickable scroll wheel
- Accessibility and Input Monitoring permissions

## Credits

- Japanese translation review: [uglykatsuki](https://github.com/uglykatsuki)

## License

Mac Drag Scroll is available under the [MIT License](LICENSE).

<p align="center">
  Made by <a href="https://martincalander.com">Martin Calander</a>.
</p>
