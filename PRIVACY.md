# Privacy

Mac Drag Scroll is a local macOS utility.

## What The App Needs

Mac Drag Scroll needs Accessibility permission to detect the configured mouse button globally and send scroll events to the active app. Website rules also use Accessibility to read the address metadata of the selected Safari or Google Chrome page so the app can compare its hostname. Input Monitoring and browser Automation permission are not required.

## Website Rules

Mac Drag Scroll checks the current page only when its menu needs to show a website action or when a configured website rule must be evaluated for a drag. The full page address is transient: the app immediately reduces it to a normalized hostname for local matching. Only hostnames that you choose to ignore are stored.

The app does not collect browsing history, inspect page contents, or store page paths, queries, fragments, titles, or full addresses. Website information is never sent over the network.

## What The App Does Not Do

- It does not record keystrokes.
- It does not read document or page contents.
- It does not track browsing history or store full page addresses.
- It does not sell or share personal data.

## Network Access

Mac Drag Scroll may contact GitHub when you check for updates or when Auto Update is enabled. It downloads Sparkle update metadata and, when a newer version is available, the signed update archive. Sparkle verifies that archive before installation.

## Local Settings

Settings such as speed, visualizer size, launch-at-login preference, per-app Ignore or Allow lists, and ignored website hostnames are stored locally on your Mac.

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
