//
//  SettingsWindow.swift
//  macdragscroll
//
//  Created by Martin Calander on 2026-01-16.
//

import SwiftUI
import AppKit
import Combine

private func localized(_ key: String, value: String, comment: String) -> String {
    AppLocalization.shared.localizedString(key, value: value, comment: comment)
}

struct SettingsWindowView: View {
    private static let tabTransitionHorizontalOffset: CGFloat = 32

    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var permissionState = AppDelegate.permissionState
    @ObservedObject private var updateManager = UpdateManager.shared
    @ObservedObject private var navigation = SettingsWindowNavigation.shared
    @ObservedObject private var instanceMonitor = AppInstanceMonitor.shared
    @ObservedObject private var crashHandler = CrashHandler.shared

    @State private var capturedFrontmostBundleId: String?
    @State private var showingResetConfirmation = false
    @State private var showingClearCrashReportsConfirmation = false
    @State private var logoPop = false
    @State private var logoDragOffset: CGSize = .zero
    @State private var settingsIntroVisible = false
    @State private var showsUpdateLog = false
    @FocusState private var focusedSidebarTab: SettingsTab?

    var body: some View {
        ZStack {
            LiquidGlassBackdrop()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    sidebar

                    Divider()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if !permissionState.hasRequiredPermissions,
                               navigation.selectedTab != .permissions {
                                permissionBanner
                            }

	                            contentHeader
	                            selectedContent
	                                .id(navigation.selectedTab)
                                    .transition(selectedContentTransition)
	                        }
	                        .padding(22)
	                        .frame(maxWidth: .infinity, alignment: .topLeading)
	                        .animation(.smooth(duration: 0.22), value: navigation.selectedTab)
                    }
                }

                Divider()
                bottomBar
            }
            .opacity(settingsIntroVisible ? 1 : 0)
            .scaleEffect(settingsIntroVisible ? 1 : 0.985, anchor: .center)
            .offset(y: settingsIntroVisible ? 0 : 10)
            .blur(radius: settingsIntroVisible ? 0 : 0.9)
            .animation(.smooth(duration: 0.32), value: settingsIntroVisible)
        }
        .frame(minWidth: 760, minHeight: 560)
        .preferredColorScheme(settings.appAppearance.colorScheme)
        .background {
            SettingsKeyboardMonitor { command in
                handleKeyboardCommand(command)
            }
            .frame(width: 0, height: 0)
        }
        .onAppear {
            focusedSidebarTab = navigation.selectedTab
            AppDelegate.refreshAccessibilityPermission()
            guard !settingsIntroVisible else { return }
            DispatchQueue.main.async {
                settingsIntroVisible = true
            }
        }
        .onChange(of: navigation.selectedTab) { _, selectedTab in
            focusedSidebarTab = selectedTab
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                    Image("BrandMark")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(AppDelegate.appName)
                        .font(.system(size: 13, weight: .semibold))
                    Text("v\(AppDelegate.appVersion)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 4)

            VStack(spacing: 0) {
                ForEach(SettingsTab.allCases) { tab in
                    SettingsSidebarButton(
                        tab: tab,
                        isSelected: navigation.selectedTab == tab,
                        isFocused: focusedSidebarTab == tab
                    ) {
                        selectTab(tab)
                    }
                    .focused($focusedSidebarTab, equals: tab)
                    .keyboardShortcut(tab.keyboardShortcut, modifiers: .command)
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(width: 178, alignment: .topLeading)
        .adaptiveGlassEffect(
            tint: Color(nsColor: .controlBackgroundColor).opacity(0.18),
            in: Rectangle()
        )
    }

    private func handleKeyboardCommand(_ command: SettingsKeyboardCommand) {
        switch command {
        case let .select(tab):
            selectTab(tab)
        case .previous:
            selectTab(SettingsTab.previous(before: navigation.selectedTab))
        case .next:
            selectTab(SettingsTab.next(after: navigation.selectedTab))
        }
    }

    private func selectTab(_ tab: SettingsTab) {
        focusedSidebarTab = tab
        withAnimation(.smooth(duration: 0.22)) {
            navigation.select(tab)
        }
    }

    private var selectedContentTransition: AnyTransition {
        let verticalOffset = Self.tabTransitionHorizontalOffset * 0.25 * CGFloat(navigation.transitionVerticalDirection)
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: Self.tabTransitionHorizontalOffset, y: verticalOffset)),
            removal: .opacity.combined(with: .offset(x: -Self.tabTransitionHorizontalOffset, y: -verticalOffset))
        )
    }

    private var contentHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label(navigation.selectedTab.title, systemImage: navigation.selectedTab.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .labelStyle(.titleAndIcon)

                Text(navigation.selectedTab.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            #if DEBUG
            DevelopmentWatermarkBadge(style: .topBar)
            #endif
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch navigation.selectedTab {
        case .general:
            generalSettings
        case .visualizer:
            visualizerSettings
        case .scrolling:
            scrollingSettings
        case .apps:
            appSettings
        case .permissions:
            permissionsSettings
        case .updates:
            updateSettings
        case .about:
            aboutSettings
        }
    }

    private var generalSettings: some View {
        VStack(spacing: 14) {
            GlassSection {
                ToggleRow(
                    icon: "power",
                    title: localized("enabled", value: "Enabled", comment: "Enabled toggle"),
                    isOn: $settings.isEnabled,
                    tooltip: localized("tooltip_enabled", value: "Turn drag scrolling on or off.", comment: "Enabled tooltip")
                )

                Divider()

                ToggleRow(
                    icon: "menubar.rectangle",
                    title: localized("keep_running_in_menu_bar", value: "Keep Running in Menu Bar", comment: "Keep running in menu bar toggle"),
                    isOn: $settings.keepRunningInMenuBar,
                    tooltip: localized("tooltip_keep_running_in_menu_bar", value: "When Settings is closed with Command-Q, keep Mac Drag Scroll active in the menu bar.", comment: "Keep running in menu bar tooltip")
                )

                Divider()

                SettingRow(
                    icon: "computermouse",
                    title: localized("trigger_button", value: "Trigger Button", comment: "Trigger Button setting"),
                    tooltip: localized("tooltip_trigger", value: "Click to capture a new mouse trigger.", comment: "Trigger button tooltip")
                ) {
                    TriggerCaptureButton(triggerConfig: $settings.triggerConfig)
                }

                Divider()

                ToggleRow(
                    icon: "rectangle.on.rectangle",
                    title: localized("launch_at_login", value: "Launch at Login", comment: "Launch at Login toggle"),
                    isOn: $settings.launchAtLogin,
                    tooltip: localized("tooltip_launch_at_login", value: "Automatically start Mac Drag Scroll when you log in.", comment: "Launch at login tooltip")
                )

                Divider()

                LanguagePickerRow(selection: $settings.appLanguage)

                Divider()

                AppearancePickerRow(selection: $settings.appAppearance)
            }

            if crashHandler.hasCrashReports {
                crashReportsSection
            }
        }
        .onAppear {
            crashHandler.refreshCrashReports()
        }
    }

    private var crashReportsSection: some View {
        GlassSection {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.orange)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(localized("crash_reports", value: "Crash Reports", comment: "Crash reports setting title"))
                            .font(.system(size: 12, weight: .semibold))

                        Text(crashReportSummary)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.14), in: Capsule())
                    }

                    Text(localized("crash_reports_help", value: "Crash reports are stored locally and can be shared when diagnosing issues.", comment: "Crash reports help text"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }

            Divider()

            HStack(spacing: 8) {
                Button {
                    crashHandler.openCrashReportsFolder()
                } label: {
                    Label(localized("open_crash_reports_folder", value: "Open Folder", comment: "Open crash reports folder button"), systemImage: "folder")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button {
                    crashHandler.copyLatestCrashReportToClipboard()
                } label: {
                    Label(localized("copy_latest_crash_report", value: "Copy Latest", comment: "Copy latest crash report button"), systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    crashHandler.revealLatestCrashReport()
                } label: {
                    Label(localized("reveal_latest_crash_report", value: "Reveal Latest", comment: "Reveal latest crash report button"), systemImage: "magnifyingglass")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button(role: .destructive) {
                    showingClearCrashReportsConfirmation = true
                } label: {
                    Label(localized("clear_crash_reports", value: "Clear", comment: "Clear crash reports button"), systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .alert(localized("clear_crash_reports_title", value: "Clear Crash Reports?", comment: "Clear crash reports confirmation title"), isPresented: $showingClearCrashReportsConfirmation) {
            Button(localized("cancel", value: "Cancel", comment: "Cancel button"), role: .cancel) { }
            Button(localized("clear_crash_reports", value: "Clear", comment: "Clear crash reports button"), role: .destructive) {
                crashHandler.clearCrashReports()
            }
        } message: {
            Text(localized("clear_crash_reports_message", value: "This removes saved crash reports from this Mac.", comment: "Clear crash reports confirmation message"))
        }
    }

    private var crashReportSummary: String {
        let format = localized("crash_reports_available_format", value: "%d saved, latest %@", comment: "Crash reports count and latest date")
        let latestDate = crashHandler.latestCrashReport.map {
            DateFormatter.localizedString(from: $0.createdAt, dateStyle: .medium, timeStyle: .short)
        } ?? localized("unknown", value: "Unknown", comment: "Unknown value")

        return String(format: format, crashHandler.crashReportCount, latestDate)
    }

    private var visualizerSettings: some View {
        VStack(spacing: 14) {
            VisualizerPreviewCard(settings: settings)

            GlassSection {
                ToggleRow(
                    icon: "dot.circle",
                    title: localized("show_indicator", value: "Show Indicator", comment: "Show Indicator toggle"),
                    isOn: $settings.showIndicator,
                    tooltip: localized("tooltip_show_indicator", value: "Show the visual indicator while drag scrolling.", comment: "Show indicator tooltip")
                )

                ToggleRow(
                    icon: "play.circle",
                    title: localized("visualizer_animation", value: "Animation", comment: "Visualizer animation toggle"),
                    isOn: $settings.visualizerAnimationsEnabled,
                    tooltip: localized("tooltip_visualizer_animation", value: "Animate the visualizer when it appears, disappears, and reacts to drag direction.", comment: "Visualizer animation tooltip")
                )
                .disabled(!settings.showIndicator)
                .opacity(settings.showIndicator ? 1 : 0.55)

                Divider()

                SliderRow(
                    icon: "arrow.up.left.and.arrow.down.right",
                    title: localized("visualizer_size", value: "Size", comment: "Visualizer size setting"),
                    value: $settings.visualizerSize,
                    range: SettingsManager.visualizerSizeRange,
                    step: 0.05,
                    format: { value in "\(Int((value * 100).rounded()))%" },
                    tooltip: localized("tooltip_visualizer_size", value: "Controls the size of the drag visualizer.", comment: "Visualizer size tooltip")
                )

                SliderRow(
                    icon: "drop.circle",
                    title: localized("liquid_glass", value: "Liquid Glass", comment: "Liquid Glass setting"),
                    value: $settings.liquidGlassIntensity,
                    range: SettingsManager.liquidGlassIntensityRange,
                    step: 0.05,
                    format: { value in "\(Int((value * 100).rounded()))%" },
                    tooltip: localized("tooltip_liquid_glass", value: "Controls glass refraction, sheen, and drag-reactive movement.", comment: "Liquid Glass tooltip")
                )

                SliderRow(
                    icon: "circle.lefthalf.filled",
                    title: localized("opacity", value: "Opacity", comment: "Opacity setting"),
                    value: $settings.overlayOpacity,
                    range: 0.2...1.0,
                    step: 0.05,
                    format: { value in "\(Int((value * 100).rounded()))%" },
                    tooltip: localized("tooltip_opacity", value: "Controls visualizer opacity.", comment: "Opacity tooltip")
                )

                TintStyleRow(selection: $settings.visualizerTintStyle)
            }
        }
    }

    private var scrollingSettings: some View {
        GlassSection {
            SliderRow(
                icon: "gauge.with.dots.needle.50percent",
                title: localized("speed", value: "Speed", comment: "Speed setting"),
                value: $settings.scrollSpeed,
                range: 0.5...5.0,
                step: 0.5,
                format: "%.1fx",
                tooltip: localized("tooltip_speed", value: "Controls scroll speed.", comment: "Speed tooltip")
            )

            SliderRow(
                icon: "arrow.up.right",
                title: localized("acceleration", value: "Acceleration", comment: "Acceleration setting"),
                value: $settings.acceleration,
                range: 1.0...3.0,
                step: 0.2,
                format: accelerationLabel,
                tooltip: localized("tooltip_acceleration", value: "Controls how quickly scrolling ramps up.", comment: "Acceleration tooltip")
            )

            SliderRow(
                icon: "circle.dashed",
                title: localized("dead_zone", value: "Dead Zone", comment: "Dead Zone setting"),
                value: $settings.deadZoneRadius,
                range: 5...50,
                step: 5,
                format: "%.0fpx",
                tooltip: localized("tooltip_dead_zone", value: "Mouse movement before scrolling starts.", comment: "Dead zone tooltip")
            )

            Divider()

            ToggleRow(
                icon: "arrow.up.arrow.down",
                title: localized("reverse_direction", value: "Reverse Direction", comment: "Reverse Direction toggle"),
                isOn: $settings.reverseScrollDirection,
                tooltip: localized("tooltip_reverse_direction", value: "Flip drag scrolling if the direction feels backwards.", comment: "Reverse direction tooltip")
            )

            Divider()

            ToggleRow(
                icon: "arrow.left.and.right",
                title: localized("horizontal_scrolling", value: "Horizontal Scrolling", comment: "Horizontal scrolling toggle"),
                isOn: $settings.horizontalScrollingEnabled,
                tooltip: localized("tooltip_horizontal_scrolling", value: "Allow sideways drag movement to send horizontal scroll events.", comment: "Horizontal scrolling tooltip")
            )

            Divider()

            ToggleRow(
                icon: "arrow.left.arrow.right",
                title: localized("invert_horizontal", value: "Invert Horizontal", comment: "Invert horizontal scrolling toggle"),
                isOn: $settings.invertHorizontalScroll,
                tooltip: localized("tooltip_invert_horizontal", value: "Flip only the horizontal scroll direction.", comment: "Invert horizontal tooltip")
            )
            .disabled(!settings.horizontalScrollingEnabled)
            .opacity(settings.horizontalScrollingEnabled ? 1 : 0.55)

            Divider()

            ToggleRow(
                icon: "scope",
                title: localized("keep_cursor_in_place", value: "Keep Cursor in Place", comment: "Keep cursor in place toggle"),
                isOn: $settings.keepCursorInPlace,
                tooltip: localized(
                    "tooltip_keep_cursor_in_place",
                    value: "Keep the pointer at the drag origin while using Middle Click. Releasing the button or any interruption restores normal pointer movement immediately.",
                    comment: "Keep cursor in place tooltip"
                )
            )
        }
    }

    private var appSettings: some View {
        GlassSection {
            Label(localized("ignored_apps_list", value: "Ignored Apps", comment: "Ignored apps list title"), systemImage: "hand.raised.slash")
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            if !settings.excludedApps.isEmpty {
                VStack(spacing: 4) {
                    ForEach(settings.excludedApps, id: \.self) { bundleId in
                        CompactAppRow(bundleId: bundleId) {
                            withAnimation(.easeOut(duration: 0.15)) {
                                settings.removeExcludedApp(bundleId)
                            }
                        }
                    }
                }
            } else {
                Text(localized("no_excluded_apps", value: "No ignored apps yet.", comment: "No excluded apps message"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            InlineAppPickerView(
                excludedApps: settings.excludedApps,
                frontmostBundleId: capturedFrontmostBundleId,
                onAdd: { bundleId in
                    withAnimation(.easeOut(duration: 0.15)) {
                        settings.addExcludedApp(bundleId)
                    }
                }
            )
        }
        .onAppear {
            capturedFrontmostBundleId = SettingsManager.shared.getFrontmostAppBundleId()
        }
    }

    private var permissionsSettings: some View {
        VStack(spacing: 14) {
            GlassSection {
                permissionOverview

                Divider()

                permissionChecklistRow(
                    icon: "figure.arms.open",
                    title: localized("permission_accessibility", value: "Accessibility Permission", comment: "Accessibility permission title"),
                    detail: permissionState.hasAccessibilityPermission
                        ? localized("permission_accessibility_granted_detail", value: "Mac Drag Scroll can monitor the configured mouse trigger and send scroll events.", comment: "Accessibility granted detail")
                        : localized("permission_accessibility_missing_detail", value: "Grant Accessibility permission so the app can detect mouse drags globally.", comment: "Accessibility missing detail"),
                    isGranted: permissionState.hasAccessibilityPermission
                )

                Divider()

                permissionChecklistRow(
                    icon: "cursorarrow.motionlines",
                    title: localized("permission_input_monitoring", value: "Input Monitoring", comment: "Input Monitoring permission title"),
                    detail: permissionState.hasInputMonitoringPermission
                        ? localized("permission_input_monitoring_granted_detail", value: "Mac Drag Scroll can listen for the configured mouse trigger.", comment: "Input Monitoring granted detail")
                        : localized("permission_input_monitoring_missing_detail", value: "Allow Input Monitoring so the mouse trigger can be detected reliably.", comment: "Input Monitoring missing detail"),
                    isGranted: permissionState.hasInputMonitoringPermission
                )

                Divider()

                HStack(spacing: 8) {
                    if !permissionState.hasRequiredPermissions {
                        Button {
                            AppDelegate.openPrivacySettingsForMissingPermission()
                        } label: {
                            Label(localized("open_system_settings", value: "Open System Settings", comment: "Open System Settings button"), systemImage: "gear")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    Button {
                        AppDelegate.refreshAccessibilityPermission()
                    } label: {
                        Label(localized("check_again", value: "Check Again", comment: "Check permission again button"), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        AppDelegate.revealApplication()
                    } label: {
                        Label(localized("reveal_this_app", value: "Reveal This App", comment: "Reveal current app copy button"), systemImage: "scope")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()
                }
            }

            GlassSection {
                InfoRow(
                    icon: "app.dashed",
                    title: localized("this_app_copy", value: "This App Copy", comment: "Current app copy label"),
                    value: AppDelegate.applicationBundlePath
                )

                Divider()

                InfoRow(
                    icon: "cursorarrow.motionlines",
                    title: localized("event_monitoring", value: "Event Monitoring", comment: "Event monitoring label"),
                    value: eventMonitoringStatusText
                )

                Divider()

                InfoRow(
                    icon: "power",
                    title: localized("app_state", value: "App State", comment: "App state label"),
                    value: settings.isEnabled
                        ? localized("status_enabled", value: "Enabled", comment: "Enabled state")
                        : localized("status_disabled", value: "Disabled", comment: "Disabled state")
                )

                if permissionState.hasRequiredPermissions && permissionState.eventMonitoringState != .active {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text(localized("permission_repair_title", value: "Permission Granted, Monitoring Not Started", comment: "Permission repair title"))
                            .font(.system(size: 12, weight: .semibold))
                        Text(localized("permission_repair_detail", value: "macOS sometimes needs the app restarted after permission changes. Start monitoring again or restart Mac Drag Scroll.", comment: "Permission repair detail"))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            Button {
                                AppDelegate.refreshAccessibilityPermission()
                            } label: {
                                Label(localized("start_monitoring", value: "Start Monitoring", comment: "Start monitoring button"), systemImage: "play.circle")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)

                            Button {
                                AppDelegate.restartApplication()
                            } label: {
                                Label(localized("restart_app", value: "Restart App", comment: "Restart app button"), systemImage: "arrow.triangle.2.circlepath")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var permissionOverview: some View {
        HStack(spacing: 12) {
            Image(systemName: permissionState.hasRequiredPermissions ? "checkmark.shield.fill" : "hand.raised.circle.fill")
                .font(.system(size: 26, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(permissionState.hasRequiredPermissions ? .green : .orange)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(permissionState.hasRequiredPermissions
                     ? localized("permission_ready_title", value: "Permissions Ready", comment: "Permissions ready title")
                     : localized("permission_setup_title", value: "Finish Permission Setup", comment: "Permission setup title"))
                    .font(.system(size: 13, weight: .semibold))
                Text(permissionState.hasRequiredPermissions
                     ? localized("permission_ready_detail", value: "Mac Drag Scroll can listen for the mouse trigger and send scroll events.", comment: "Permissions ready detail")
                     : localized("permission_setup_detail", value: "Grant both permissions to this exact app copy. Mac Drag Scroll checks automatically after you switch them on.", comment: "Permission setup detail"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            StatusBadge(
                title: permissionState.hasRequiredPermissions
                    ? localized("permission_granted", value: "Granted", comment: "Permission granted")
                    : localized("permission_needed", value: "Needed", comment: "Permission needed"),
                color: permissionState.hasRequiredPermissions ? .green : .orange
            )
        }
    }

    private func permissionChecklistRow(icon: String, title: String, detail: String, isGranted: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: SettingsLayout.rowIconWidth)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            StatusBadge(
                title: isGranted
                    ? localized("permission_granted", value: "Granted", comment: "Permission granted")
                    : localized("permission_needed", value: "Needed", comment: "Permission needed"),
                color: isGranted ? .green : .orange
            )
        }
    }

    private var updateSettings: some View {
        VStack(spacing: 14) {
            GlassSection {
                ToggleRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: localized("auto_update", value: "Auto Update", comment: "Auto update toggle"),
                    isOn: $updateManager.autoUpdateEnabled,
                    tooltip: localized("tooltip_auto_update", value: "Automatically check for verified app updates.", comment: "Auto update tooltip")
                )

                Divider()

                InfoRow(
                    icon: "shippingbox",
                    title: localized("current_version", value: "Current Version", comment: "Current version label"),
                    value: updateManager.currentVersionDisplay
                )

                Divider()

                InfoRow(
                    icon: "clock",
                    title: localized("last_checked", value: "Last Checked", comment: "Last checked label"),
                    value: formattedDate(updateManager.lastChecked)
                )
            }

            GlassSection {
                HStack(spacing: 12) {
                    Image(systemName: updateStatusIcon)
                        .font(.system(size: 24, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(updateStatusColor)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(updateManager.status.statusTitle)
                            .font(.system(size: 13, weight: .semibold))
                        Text(updateManager.status.statusDetail)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }

                Divider()

                HStack(spacing: 8) {
                    Button {
                        updateManager.checkForUpdates()
                    } label: {
                        Label(
                            updateManager.status.isChecking
                                ? localized("checking", value: "Checking", comment: "Checking update button")
                                : localized("check_for_update", value: "Check For Update", comment: "Check for update button"),
                            systemImage: "arrow.clockwise"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(updateManager.status.isChecking)

                    if updateManager.status.isMenuActionEnabled {
                        Button {
                            updateManager.openReleasePage()
                        } label: {
                            Label(localized("open_release", value: "Open Release", comment: "Open release button"), systemImage: "arrow.up.forward.app")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Spacer()
                }
            }

            versionHistorySection

            if showsUpdateLog {
                updateLogSection
            }
        }
    }

    private var versionHistorySection: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Label(localized("version_history", value: "Version History", comment: "Version history title"), systemImage: "clock.badge.checkmark")
                        .font(.system(size: 12, weight: .semibold))

                    Spacer(minLength: 10)

                    Button {
                        withAnimation(.smooth(duration: 0.18)) {
                            showsUpdateLog.toggle()
                        }
                    } label: {
                        Label(
                            showsUpdateLog
                                ? localized("hide_update_log", value: "Hide Update Log", comment: "Hide update log button")
                                : localized("show_update_log", value: "Show Update Log", comment: "Show update log button"),
                            systemImage: showsUpdateLog ? "chevron.up.circle" : "list.bullet.rectangle"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Divider()

                ForEach(UpdateManager.versionHistory.indices, id: \.self) { index in
                    versionHistoryRow(UpdateManager.versionHistory[index])

                    if index < UpdateManager.versionHistory.count - 1 {
                        Divider()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func versionHistoryRow(_ entry: VersionHistoryEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: entry.isCurrent ? "checkmark.seal.fill" : "shippingbox")
                .font(.system(size: 13, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(entry.isCurrent ? Color.green : Color.secondary)
                .frame(width: SettingsLayout.rowIconWidth)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("\(localized("version", value: "Version", comment: "Version label")) \(entry.version)")
                        .font(.system(size: 12, weight: .semibold))

                    if entry.isCurrent {
                        StatusBadge(
                            title: localized("current_release", value: "Current", comment: "Current release badge"),
                            color: .green
                        )
                    }

                    Spacer(minLength: 8)

                    Text(entry.releaseDate)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Text(String(format: localized("build_format", value: "Build %@", comment: "Build number format"), entry.build))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(entry.changes, id: \.self) { change in
                        HStack(alignment: .top, spacing: 7) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 3, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 6, height: 12)
                                .padding(.top, 2)

                            Text(change)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var updateLogSection: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 8) {
                Label(localized("update_log", value: "Update Log", comment: "Update log title"), systemImage: "list.bullet.rectangle")
                    .font(.system(size: 12, weight: .semibold))

                Text(localized("update_log_detail", value: "Diagnostic Sparkle events and manual update checks.", comment: "Update log detail"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                ForEach(updateManager.history) { entry in
                    HStack(alignment: .top, spacing: 8) {
                        Text(historyTime(entry.date))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: 74, alignment: .leading)

                        Text(entry.message)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var aboutLogo: some View {
        let popScale = logoPop ? 1.08 : 1.0

        return Image("BrandMark")
            .resizable()
            .interpolation(.high)
            .frame(width: 92, height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 6)
            .scaleEffect(
                x: popScale * aboutLogoSquashX,
                y: popScale * aboutLogoSquashY,
                anchor: .center
            )
            .rotationEffect(.degrees(aboutLogoRotationDegrees))
            .offset(logoDragOffset)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .gesture(aboutLogoDragGesture)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                triggerAboutLogoBounce()
            }
            .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.62), value: logoDragOffset)
            .animation(.spring(response: 0.22, dampingFraction: 0.46), value: logoPop)
    }

    private var aboutLogoDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                logoDragOffset = boundedAboutLogoOffset(value.translation)
            }
            .onEnded { value in
                let distance = hypot(value.translation.width, value.translation.height)
                if distance < 4 {
                    triggerAboutLogoBounce()
                }

                withAnimation(.spring(response: 0.34, dampingFraction: 0.48)) {
                    logoDragOffset = .zero
                }
            }
    }

    private var aboutLogoSquashX: CGFloat {
        let horizontal = min(abs(logoDragOffset.width) / 24, 1)
        let vertical = min(abs(logoDragOffset.height) / 24, 1)
        return 1 + horizontal * 0.075 - vertical * 0.035
    }

    private var aboutLogoSquashY: CGFloat {
        let horizontal = min(abs(logoDragOffset.width) / 24, 1)
        let vertical = min(abs(logoDragOffset.height) / 24, 1)
        return 1 + vertical * 0.075 - horizontal * 0.035
    }

    private var aboutLogoRotationDegrees: Double {
        Double(logoDragOffset.width / 24 * 5) + (logoPop ? -2.5 : 0)
    }

    private func triggerAboutLogoBounce() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.46)) {
            logoPop = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                logoPop = false
            }
        }
    }

    private func boundedAboutLogoOffset(_ translation: CGSize) -> CGSize {
        let maxLength: CGFloat = 24
        let length = hypot(translation.width, translation.height)
        guard length > maxLength, length > 0 else {
            return translation
        }

        let scale = maxLength / length
        return CGSize(width: translation.width * scale, height: translation.height * scale)
    }

    private var aboutSettings: some View {
        VStack(spacing: 14) {
            GlassSection {
                HStack(spacing: 16) {
                    aboutLogo
                    .accessibilityLabel(localized("app_logo", value: "App logo", comment: "App logo accessibility label"))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 3) {
                            Text(AppDelegate.appName)
                                .font(.system(size: 28, weight: .semibold))

                            Text("©")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.top, 3)
                        }
                        .accessibilityElement(children: .combine)

                        Text(localized("about_slogan", value: "Windows-style drag scrolling, built for macOS.", comment: "About slogan"))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Text(localized("about_author", value: "Made by Martin Calander", comment: "Author credit"))
                            .font(.system(size: 12, weight: .medium))
                    }

                    Spacer()
                }
            }

            GlassSection {
                InfoRow(
                    icon: "number",
                    title: localized("version", value: "Version", comment: "Version label"),
                    value: AppDelegate.appVersion
                )

                Divider()

                AssetLinkRow(
                    assetName: "GitHubMark",
                    title: localized("github_repository", value: "GitHub Repository", comment: "GitHub repository label"),
                    url: UpdateManager.repositoryURL
                )

                Divider()

                LinkRow(
                    icon: "globe",
                    title: localized("website", value: "Website", comment: "Website label"),
                    url: UpdateManager.websiteURL
                )

                Divider()

                LinkRow(
                    icon: "envelope",
                    title: localized("support_email", value: "Support Email", comment: "Support email label"),
                    url: URL(string: "mailto:macdragscroll@martincalander.com")!,
                    displayText: "macdragscroll@martincalander.com"
                )

                Divider()

                SettingRow(
                    icon: "sparkles",
                    title: localized("show_welcome", value: "Show Welcome", comment: "Show welcome button"),
                    tooltip: localized("tooltip_show_welcome", value: "Open the welcome page again.", comment: "Show welcome tooltip")
                ) {
                    Button {
                        AppDelegate.requestWelcomeWindow()
                    } label: {
                        Label(localized("open", value: "Open", comment: "Open button"), systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            GlassSection {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Copyright 2026 Martin Calander. All rights reserved.")
                        .font(.system(size: 11, weight: .medium))
                    Text(localized("about_runtime_note", value: "Designed as a quiet menu bar utility with native macOS controls and a Liquid Glass drag indicator.", comment: "About runtime note"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var permissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised.circle")
                .font(.system(size: 22))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(localized("permissions_required_title", value: "Permissions Required", comment: "Permissions required title"))
                    .font(.system(size: 12, weight: .semibold))
                Text(localized("permissions_required_message", value: "Mac Drag Scroll needs Accessibility and Input Monitoring to listen for the mouse trigger.", comment: "Permissions required message"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                navigation.select(.permissions)
            } label: {
                Label(
                    localized("settings_permissions", value: "Permissions", comment: "Permissions settings tab"),
                    systemImage: "arrow.right"
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .adaptiveGlassEffect(
            tint: Color.orange.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.orange.opacity(0.24), lineWidth: 0.5)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Label(
                    settings.isEnabled
                        ? localized("status_enabled", value: "Active", comment: "Enabled status")
                        : localized("status_disabled", value: "Disabled", comment: "Disabled status"),
                    systemImage: settings.isEnabled ? "checkmark.circle.fill" : "pause.circle.fill"
                )
                .foregroundStyle(settings.isEnabled ? .primary : .secondary)

                if instanceMonitor.hasDuplicateInstances {
                    Label(
                        localized("multiple_instances_warning", value: "Multiple Copies Running", comment: "Multiple instances warning"),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                    .help(localized("multiple_instances_warning_detail", value: "Quit the extra copy so only one Mac Drag Scroll monitor is active.", comment: "Multiple instances warning detail"))
                }

                #if DEBUG
                DevelopmentWatermarkBadge(style: .bottomBar)
                #endif
            }
            .font(.system(size: 11, weight: .medium))

            Spacer()

            Button {
                showingResetConfirmation = true
            } label: {
                Label(localized("reset_to_defaults", value: "Reset to Defaults", comment: "Reset to Defaults button"), systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .alert(localized("reset_confirm_title", value: "Reset Settings?", comment: "Reset confirmation title"), isPresented: $showingResetConfirmation) {
                Button(localized("cancel", value: "Cancel", comment: "Cancel button"), role: .cancel) { }
                Button(localized("reset", value: "Reset", comment: "Reset button"), role: .destructive) {
                    settings.resetToDefaults()
                }
            } message: {
                Text(localized("reset_confirm_message", value: "This will restore the default drag scroll settings.", comment: "Reset confirmation message"))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .adaptiveGlassEffect(
            tint: Color(nsColor: .controlBackgroundColor).opacity(0.16),
            in: Rectangle()
        )
    }

    private var eventMonitoringStatusText: String {
        switch permissionState.eventMonitoringState {
        case .active:
            return localized("status_active", value: "Active", comment: "Active state")
        case .waiting:
            return localized("status_waiting", value: "Waiting", comment: "Waiting state")
        case .failed:
            return localized("status_failed", value: "Failed", comment: "Failed state")
        }
    }

    private func accelerationLabel(_ value: Double) -> String {
        switch value {
        case ..<1.4:
            return localized("acceleration_low", value: "Low", comment: "Low")
        case ..<2.0:
            return localized("acceleration_med", value: "Med", comment: "Med")
        case ..<2.6:
            return localized("acceleration_high", value: "High", comment: "High")
        default:
            return localized("acceleration_max", value: "Max", comment: "Max")
        }
    }

    private var updateStatusIcon: String {
        switch updateManager.status {
        case .checking:
            return "arrow.triangle.2.circlepath"
        case .upToDate:
            return "checkmark.circle.fill"
        case .available:
            return "arrow.down.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var updateStatusColor: Color {
        switch updateManager.status {
        case .checking:
            return .blue
        case .upToDate:
            return .secondary
        case .available:
            return .orange
        case .failed:
            return .secondary
        }
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else {
            return localized("never", value: "Never", comment: "Never date")
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func historyTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d HH:mm"
        return formatter.string(from: date)
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case visualizer
    case scrolling
    case apps
    case permissions
    case updates
    case about

    var id: String { rawValue }

    var keyboardShortcut: KeyEquivalent {
        KeyEquivalent(Character(keyboardShortcutLabel))
    }

    var keyboardShortcutLabel: String {
        switch self {
        case .general:
            return "1"
        case .visualizer:
            return "2"
        case .scrolling:
            return "3"
        case .apps:
            return "4"
        case .permissions:
            return "5"
        case .updates:
            return "6"
        case .about:
            return "7"
        }
    }

    static func tab(forShortcut shortcut: String) -> SettingsTab? {
        guard let index = Int(shortcut), allCases.indices.contains(index - 1) else {
            return nil
        }
        return allCases[index - 1]
    }

    static func previous(before tab: SettingsTab) -> SettingsTab {
        guard let index = allCases.firstIndex(of: tab) else { return tab }
        let previousIndex = index == allCases.startIndex ? allCases.index(before: allCases.endIndex) : allCases.index(before: index)
        return allCases[previousIndex]
    }

    static func next(after tab: SettingsTab) -> SettingsTab {
        guard let index = allCases.firstIndex(of: tab) else { return tab }
        let nextIndex = allCases.index(after: index)
        return nextIndex == allCases.endIndex ? allCases[allCases.startIndex] : allCases[nextIndex]
    }

    static func transitionVerticalDirection(from previousTab: SettingsTab, to selectedTab: SettingsTab) -> Int {
        guard
            previousTab != selectedTab,
            let previousIndex = allCases.firstIndex(of: previousTab),
            let selectedIndex = allCases.firstIndex(of: selectedTab)
        else {
            return 0
        }

        return previousIndex < selectedIndex ? -1 : 1
    }

    var title: String {
        switch self {
        case .general:
            return localized("settings_general", value: "General", comment: "General settings tab")
        case .visualizer:
            return localized("settings_visualizer", value: "Visualizer", comment: "Visualizer settings tab")
        case .scrolling:
            return localized("settings_scrolling", value: "Scrolling", comment: "Scrolling settings tab")
        case .apps:
            return localized("settings_apps", value: "Ignored Apps", comment: "Apps settings tab")
        case .permissions:
            return localized("settings_permissions", value: "Permissions", comment: "Permissions settings tab")
        case .updates:
            return localized("settings_updates", value: "Updates", comment: "Updates settings tab")
        case .about:
            return localized("settings_about", value: "About", comment: "About settings tab")
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            return localized("settings_general_subtitle", value: "Activation, trigger, and startup behavior.", comment: "General settings subtitle")
        case .visualizer:
            return localized("settings_visualizer_subtitle", value: "Tune the drag visualizer and preview it instantly.", comment: "Visualizer settings subtitle")
        case .scrolling:
            return localized("settings_scrolling_subtitle", value: "Adjust speed, acceleration, and dead zone.", comment: "Scrolling settings subtitle")
        case .apps:
            return localized("settings_apps_subtitle", value: "Disable drag scrolling in selected apps.", comment: "Apps settings subtitle")
        case .permissions:
            return localized("settings_permissions_subtitle", value: "Check required macOS permissions and runtime status.", comment: "Permissions settings subtitle")
        case .updates:
            return localized("settings_updates_subtitle", value: "Check verified updates, automatic update status, and update history.", comment: "Updates settings subtitle")
        case .about:
            return localized("settings_about_subtitle", value: "Product identity, links, and credits.", comment: "About settings subtitle")
        }
    }

    var icon: String {
        switch self {
        case .general:
            return "switch.2"
        case .visualizer:
            return "circle.hexagongrid"
        case .scrolling:
            return "scroll"
        case .apps:
            return "app.badge"
        case .permissions:
            return "checkmark.shield"
        case .updates:
            return "arrow.triangle.2.circlepath"
        case .about:
            return "info.circle"
        }
    }
}

final class SettingsWindowNavigation: ObservableObject {
    static let shared = SettingsWindowNavigation()

    @Published private(set) var selectedTab: SettingsTab = .visualizer
    @Published private(set) var transitionVerticalDirection: Int = 0

    private init() {}

    func select(_ tab: SettingsTab) {
        guard tab != selectedTab else { return }
        transitionVerticalDirection = SettingsTab.transitionVerticalDirection(from: selectedTab, to: tab)
        selectedTab = tab
    }
}
