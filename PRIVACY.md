# Privacy

Mac Drag Scroll is a local macOS utility.

## What The App Needs

Mac Drag Scroll needs Accessibility permission to detect the configured mouse button globally and send scroll events to the active app. Input Monitoring is not required.

## What The App Does Not Do

- It does not record keystrokes.
- It does not read document contents.
- It does not track browsing history.
- It does not sell or share personal data.

## Network Access

Mac Drag Scroll may contact GitHub when you check for updates or when Auto Update is enabled. It downloads Sparkle update metadata and, when a newer version is available, the signed update archive. Sparkle verifies that archive before installation.

## Local Settings

Settings such as speed, visualizer size, launch-at-login preference, and excluded apps are stored locally on your Mac.

Release builds store preferences at:

```text
~/Library/Preferences/com.martincalander.macdragscroll.plist
~/Library/Application Support/Mac Drag Scroll/Preferences.plist
```

The second file is a local recovery backup for app settings.

## Diagnostics

If the app crashes, saved crash reports stay local unless you choose to share them. Crash reports are stored at:

```text
~/Library/Application Support/Mac Drag Scroll/Crash Reports
```

Mac Drag Scroll does not upload crash reports automatically.
