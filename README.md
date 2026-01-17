# Mac Drag Scroll

A lightweight macOS menu bar app that enables Windows-style middle mouse button scrolling.

Hold the middle mouse button and move your mouse to scroll in any direction — just like on Windows.

## Features

- **Middle-click drag scrolling** — Hold middle mouse button and drag to scroll in any direction
- **Window locking** — Scroll stays locked to the original window even if your cursor moves elsewhere
- **Visual indicator** — Shows a dot at the origin point with an arrow indicating scroll direction
- **Configurable settings**:
  - **Speed** — Adjust scroll speed (0.5x - 5.0x)
  - **Acceleration** — Control how quickly scrolling ramps up (Low/Med/High/Max)
  - **Dead zone** — Set the radius where no scrolling occurs (5-50px)
  - **Opacity** — Adjust indicator transparency
- **Show/Hide indicator** — Toggle the visual overlay on or off
- **Launch at Login** — Optionally start the app when you log in
- **Per-app exclusions** — Disable scrolling for specific applications
- **Quick-click detection** — Brief clicks don't show the indicator overlay
- **Menu bar app** — Lives quietly in your menu bar, no dock icon
- **Multi-language support** — English, Swedish, and Simplified Chinese

## Requirements

- macOS 13.0 or later
- Accessibility permissions (required for global mouse event monitoring)

## Installation

1. Download the latest release or build from source
2. Move `Mac Drag Scroll.app` to your Applications folder
3. Launch the app
4. Grant Accessibility permissions when prompted:
   - Go to **System Settings → Privacy & Security → Accessibility**
   - Enable **Mac Drag Scroll** in the list

## Usage

1. Click the middle mouse button and hold
2. Move your mouse in the direction you want to scroll
3. Release the middle mouse button to stop scrolling

The further you move from the starting point, the faster it scrolls. The scroll will continue affecting the original window even if you move your cursor to a different window.

## Settings

Click (left or right) the menu bar icon to open the settings popover:

| Setting | Description |
|---------|-------------|
| **Enable toggle** | Turn middle-click scrolling on/off |
| **Speed** | Scroll speed multiplier (0.5x - 5.0x) |
| **Acceleration** | How quickly scroll speed increases with distance |
| **Dead Zone** | Radius around origin where scrolling doesn't activate |
| **Opacity** | Transparency of the visual indicator |
| **Show Indicator & Animations** | Toggle the visual overlay |
| **Launch at Login** | Start app automatically on login |
| **Excluded Apps** | Apps where scrolling is disabled |

## Building from Source

1. Open `macdragscroll.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities
3. Build and run (⌘R)

## Permissions

Mac Drag Scroll requires **Accessibility** permissions to:
- Detect middle mouse button events globally
- Simulate scroll wheel events

The app will prompt you to grant permissions on first launch. If permissions are revoked while the app is running, it will notify you and disable scrolling until permissions are restored.

## Localization

The app supports the following languages:
- English (default)
- Swedish (Svenska)
- Simplified Chinese (简体中文)

To change the language, go to **System Settings → General → Language & Region → Applications** and add Mac Drag Scroll with your preferred language.

## Version History

- **1.18.0** — Added multi-language support (English, Swedish, Chinese), window-locked scrolling
- **1.17.0** — Added permission dialogs, right-click menu bar support, improved app picker
- **1.16.0** — Added Launch at Login option
- **1.15.0** — Added opacity setting, permission state monitoring
- **1.14.0** — Renamed to Mac Drag Scroll, improved UI
- **1.4.0** — Fixed Y-axis scroll direction
- **1.3.0** — Added accessibility permission detection and setup prompt
- **1.2.0** — Added version display in menu bar, improved scroll functionality
- **1.1.0** — Fixed overlay positioning, simplified UI
- **1.0.0** — Initial release

## Author

Made by Martin Calander

## License

MIT License — feel free to use, modify, and distribute.
