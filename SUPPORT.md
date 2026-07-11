# Support

If Mac Drag Scroll is not working as expected, check these first:

1. Confirm you are using macOS 14 or later.
2. Confirm your mouse has a working middle button or scroll-wheel click.
3. Open **System Settings -> Privacy & Security -> Accessibility** and make sure **Mac Drag Scroll** is enabled.
4. Open Mac Drag Scroll Settings and confirm the app is enabled.
5. Check whether the current app is listed under **Excluded Apps**.

## Common Fixes

- Use the restart action in the Permissions tab only if Accessibility is granted but Event Monitoring does not become Active automatically.
- Remove and re-add Mac Drag Scroll in Accessibility if macOS shows stale permission state.
- Try a lower speed or larger dead zone if scrolling starts too aggressively.
- Disable the visualizer if a specific full-screen app does not like overlays.

The first update from `1.1.0` or earlier to `1.2.0` requires one final Accessibility grant. Normal updates after that retain the same macOS code identity and should not reset it. Input Monitoring is not required.

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
- Whether Accessibility is enabled and Event Monitoring shows Active.
- The latest crash report if one exists and it is safe to share.
