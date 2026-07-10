# Support

If Mac Drag Scroll is not working as expected, check these first:

1. Confirm you are using macOS 14 or later.
2. Confirm your mouse has a working middle button or scroll-wheel click.
3. Open **System Settings -> Privacy & Security -> Accessibility** and make sure **Mac Drag Scroll** is enabled.
4. Open **System Settings -> Privacy & Security -> Input Monitoring** and make sure **Mac Drag Scroll** is enabled.
5. Open Mac Drag Scroll Settings and confirm the app is enabled.
6. Check whether the current app is listed under **Excluded Apps**.

## Common Fixes

- Quit and reopen Mac Drag Scroll after granting permissions.
- Remove and re-add Mac Drag Scroll in Accessibility or Input Monitoring if macOS shows stale permission state.
- Try a lower speed or larger dead zone if scrolling starts too aggressively.
- Disable the visualizer if a specific full-screen app does not like overlays.

## Settings Or Updates

User settings are stored here:

```text
~/Library/Preferences/com.martincalander.macdragscroll.plist
```

Recoverable app settings are also mirrored here:

```text
~/Library/Application Support/Mac Drag Scroll/Preferences.plist
```

Updates, Homebrew upgrades, normal reinstall, and moving the app in or out of `/Applications` should not delete these files.

## Crash Reports

If Mac Drag Scroll crashed, open **Settings -> General -> Crash Reports**. You can open the folder, copy the latest report, reveal it in Finder, or clear saved reports.

Crash reports are stored locally at:

```text
~/Library/Application Support/Mac Drag Scroll/Crash Reports
```

## Open An Issue

Open an issue when the problem is reproducible. Include:

- Mac Drag Scroll version.
- macOS version.
- Mouse model.
- The app where the issue happens.
- What you expected.
- What happened instead.
- Whether Accessibility and Input Monitoring are both enabled.
- The latest crash report if one exists and it is safe to share.
