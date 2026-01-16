# MacDragScroll

A lightweight macOS menu bar app that enables Windows-style middle mouse button scrolling.

Hold the middle mouse button and move your mouse to scroll in any direction — just like on Windows.

## Features

- **Middle-click scrolling** — Hold middle mouse button and drag to scroll
- **Visual indicator** — Shows a dot at the origin point with an arrow indicating scroll direction
- **Dead zone** — Small area around the origin where no scrolling occurs, preventing accidental scrolls
- **Variable speed** — Scroll faster by moving further from the origin point
- **Menu bar app** — Lives quietly in your menu bar, no dock icon
- **Enable/Disable toggle** — Quickly turn scrolling on or off from the menu bar

## Requirements

- macOS 13.0 or later
- Accessibility permissions (required for global mouse event monitoring)

## Installation

1. Download the latest release or build from source
2. Move `MacDragScroll.app` to your Applications folder
3. Launch the app
4. Grant Accessibility permissions when prompted:
   - Go to **System Settings → Privacy & Security → Accessibility**
   - Enable **MacDragScroll** in the list

## Usage

1. Click the middle mouse button and hold
2. Move your mouse in the direction you want to scroll
3. Release the middle mouse button to stop scrolling

The further you move from the starting point, the faster it scrolls.

## Building from Source

1. Open `MacDragScroll.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities
3. Build and run (⌘R)

## Menu Bar Options

| Option | Description |
|--------|-------------|
| **MacDragScroll vX.X.X** | Current version (read-only) |
| **Enabled** | Toggle middle-click scrolling on/off |
| **Quit MacDragScroll** | Exit the application |

## Permissions

MacDragScroll requires **Accessibility** permissions to:
- Detect middle mouse button events globally
- Simulate scroll wheel events

The app will prompt you to grant permissions on first launch and can open System Settings directly.

## Version History

- **1.4.0** — Fixed Y-axis scroll direction
- **1.3.0** — Added accessibility permission detection and setup prompt
- **1.2.0** — Added version display in menu bar, improved scroll functionality
- **1.1.0** — Fixed overlay positioning, simplified UI
- **1.0.0** — Initial release

## License

MIT License — feel free to use, modify, and distribute.
