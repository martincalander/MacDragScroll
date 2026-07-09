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
                            if !permissionState.hasRequiredPermissions {
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
        .glassEffect(
            .regular.tint(Color(nsColor: .controlBackgroundColor).opacity(0.18)),
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
                    Button {
                        AppDelegate.requestAccessibilityPermission()
                    } label: {
                        Label(localized("grant_permissions", value: "Grant Permissions", comment: "Grant permissions button"), systemImage: "lock.open")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

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

            Button(localized("grant_permissions", value: "Grant Permissions", comment: "Grant permissions button")) {
                AppDelegate.requestAccessibilityPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .glassEffect(
            .regular.tint(Color.orange.opacity(0.12)),
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
        .glassEffect(
            .regular.tint(Color(nsColor: .controlBackgroundColor).opacity(0.16)),
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

#if DEBUG
private struct DevelopmentWatermarkBadge: View {
    enum Style {
        case topBar
        case bottomBar
    }

    let style: Style

    private var title: String {
        switch style {
        case .topBar:
            return "DEV BUILD"
        case .bottomBar:
            return "Development Build"
        }
    }

    private var icon: String {
        switch style {
        case .topBar:
            return "hammer.fill"
        case .bottomBar:
            return "wrench.and.screwdriver.fill"
        }
    }

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: fontSize, weight: .semibold))
            .lineLimit(1)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(foregroundStyle)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .glassEffect(.regular.tint(tint), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(borderColor, lineWidth: 0.6)
            }
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 1)
            .help("Debug-only development build marker. Release builds do not show this.")
    }

    private var fontSize: CGFloat {
        switch style {
        case .topBar:
            return 10
        case .bottomBar:
            return 9
        }
    }

    private var horizontalPadding: CGFloat {
        switch style {
        case .topBar:
            return 9
        case .bottomBar:
            return 7
        }
    }

    private var verticalPadding: CGFloat {
        switch style {
        case .topBar:
            return 4
        case .bottomBar:
            return 2.5
        }
    }

    private var tint: Color {
        switch style {
        case .topBar:
            return Color.orange.opacity(0.20)
        case .bottomBar:
            return Color.orange.opacity(0.12)
        }
    }

    private var foregroundStyle: Color {
        switch style {
        case .topBar:
            return Color.orange
        case .bottomBar:
            return Color.orange.opacity(0.82)
        }
    }

    private var borderColor: Color {
        switch style {
        case .topBar:
            return Color.orange.opacity(0.34)
        case .bottomBar:
            return Color.orange.opacity(0.22)
        }
    }

    private var shadowColor: Color {
        switch style {
        case .topBar:
            return Color.orange.opacity(0.12)
        case .bottomBar:
            return Color.clear
        }
    }

    private var shadowRadius: CGFloat {
        switch style {
        case .topBar:
            return 5
        case .bottomBar:
            return 0
        }
    }
}
#endif

private struct SettingsSidebarButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let isFocused: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(tab.title, systemImage: tab.icon)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                .padding(.horizontal, 12)
                .contentShape(Rectangle())
                .background(
                    isSelected ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.18) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay {
                    if isFocused && !isSelected {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.50), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .primary : .secondary)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityHint("Press Command-\(tab.keyboardShortcutLabel) to open \(tab.title).")
        .animation(.smooth(duration: 0.18), value: isSelected)
        .animation(.smooth(duration: 0.18), value: isFocused)
    }
}

private enum SettingsKeyboardCommand {
    case select(SettingsTab)
    case previous
    case next

    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let characters = event.charactersIgnoringModifiers?.lowercased()

        if flags.contains(.command), let characters, let tab = SettingsTab.tab(forShortcut: characters) {
            self = .select(tab)
            return
        }

        if flags.contains(.command) {
            switch event.keyCode {
            case 123, 126:
                self = .previous
                return
            case 124, 125:
                self = .next
                return
            default:
                break
            }

            if characters == "[" {
                self = .previous
                return
            }

            if characters == "]" {
                self = .next
                return
            }
        }

        if flags.contains(.control), event.keyCode == 48 {
            self = flags.contains(.shift) ? .previous : .next
            return
        }

        return nil
    }
}

private struct SettingsKeyboardMonitor: NSViewRepresentable {
    let onCommand: (SettingsKeyboardCommand) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.view = view
        context.coordinator.install()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.view = nsView
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator {
        var parent: SettingsKeyboardMonitor
        weak var view: NSView?
        private var monitor: Any?

        init(parent: SettingsKeyboardMonitor) {
            self.parent = parent
        }

        func install() {
            guard monitor == nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self,
                      let window = self.view?.window,
                      event.window === window,
                      let command = SettingsKeyboardCommand(event: event) else {
                    return event
                }

                self.parent.onCommand(command)
                return nil
            }
        }

        func uninstall() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit {
            uninstall()
        }
    }
}

private struct VisualizerPreviewCard: View {
    @ObservedObject var settings: SettingsManager
    @State private var previewDrag = CGSize(width: 48, height: -18)

    var body: some View {
        LiquidGlassSurface(cornerRadius: 12, tintOpacity: 0.18, strokeOpacity: 0.42, shadowOpacity: 0.08, padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(localized("live_preview", value: "Live Preview", comment: "Live preview title"))
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(localized("drag_preview_hint", value: "Drag in the preview", comment: "Drag preview hint"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.70)

                    previewBackground

                    visualizer
                }
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            previewDrag = clamped(value.translation, maxLength: 70)
                        }
                )
            }
        }
    }

    private var previewBackground: some View {
        NormalPreviewScene()
    }

    private var visualizer: some View {
        let side = ScrollOverlayGeometry.sideLength(
            deadZoneRadius: CGFloat(settings.deadZoneRadius),
            visualizerSize: CGFloat(settings.visualizerSize)
        )
        let opacity = CGFloat(settings.overlayOpacity)
        let glassIntensity = CGFloat(settings.liquidGlassIntensity)
        let distance = sqrt(previewDrag.width * previewDrag.width + previewDrag.height * previewDrag.height)
        let unitX = distance > 0 ? previewDrag.width / distance : 0
        let unitY = distance > 0 ? previewDrag.height / distance : 0
        let effectiveDistance = max(distance - CGFloat(settings.deadZoneRadius), 0)
        let travel = min(effectiveDistance * (0.55 + glassIntensity * 0.07), side * 0.25)
        let dotRadius = min(max(side * 0.074, 4.0), 10.0)
        let tintColor = settings.visualizerTintStyle.glassTintColor(intensity: settings.liquidGlassIntensity)
            ?? NSColor.white.withAlphaComponent(min(0.090 + glassIntensity * 0.018, 0.14))
        let tint = Color(nsColor: tintColor)
        let activation = min(effectiveDistance / 42, 1)
        let aeroBlue = Color(red: 0.70, green: 0.92, blue: 1.0)

        return ZStack {
            VisualizerPreviewGlassCircle(
                tint: tint,
                opacity: opacity,
                glassIntensity: glassIntensity,
                activation: activation,
                aeroBlue: aeroBlue
            )

            VisualizerPreviewDot(
                dotRadius: dotRadius,
                opacity: opacity,
                glassIntensity: glassIntensity,
                aeroBlue: aeroBlue
            )
                .frame(width: dotRadius * 2, height: dotRadius * 2)
                .offset(x: unitX * travel, y: unitY * travel)
        }
        .frame(width: side, height: side)
        .rotation3DEffect(.degrees(unitY * (3.3 + glassIntensity * 1.2)), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
        .rotation3DEffect(.degrees(-unitX * (3.3 + glassIntensity * 1.2)), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
    }

    private func clamped(_ size: CGSize, maxLength: CGFloat) -> CGSize {
        let length = sqrt(size.width * size.width + size.height * size.height)
        guard length > maxLength, length > 0 else { return size }
        let scale = maxLength / length
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}

private struct VisualizerPreviewGlassCircle: View {
    let tint: Color
    let opacity: CGFloat
    let glassIntensity: CGFloat
    let activation: CGFloat
    let aeroBlue: Color

    var body: some View {
        Circle()
            .fill(Color.white.opacity(baseFillOpacity))
            .glassEffect(.regular.tint(tint), in: Circle())
            .overlay { highlightWash }
            .overlay { outerHighlight }
            .overlay { lowerRim }
            .shadow(color: .white.opacity(upperGlowOpacity), radius: 7 + glassIntensity * 1.4, x: -1.5, y: -1.5)
            .shadow(color: .black.opacity(lowerShadowOpacity), radius: 9 + glassIntensity * 1.8, x: 0, y: 2.5)
    }

    private var highlightWash: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(topWashOpacity),
                        .white.opacity(midWashOpacity),
                        aeroBlue.opacity(blueWashOpacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
    }

    private var outerHighlight: some View {
        Circle()
            .stroke(.white.opacity(outerStrokeOpacity), lineWidth: 1.1)
    }

    private var lowerRim: some View {
        Circle()
            .stroke(.black.opacity(lowerRimOpacity), lineWidth: 0.6)
    }

    private var baseFillOpacity: CGFloat {
        min(0.060 * opacity * (0.90 + glassIntensity * 0.12), 0.16)
    }

    private var topWashOpacity: CGFloat {
        min((0.24 + activation * 0.08) * opacity * (0.86 + glassIntensity * 0.18), 0.52)
    }

    private var midWashOpacity: CGFloat {
        min(0.085 * opacity * (0.88 + glassIntensity * 0.16), 0.24)
    }

    private var blueWashOpacity: CGFloat {
        min((0.018 + activation * 0.018) * opacity * (0.75 + glassIntensity * 0.14), 0.070)
    }

    private var outerStrokeOpacity: CGFloat {
        min((0.30 + activation * 0.06) * opacity * (0.92 + glassIntensity * 0.10), 0.48)
    }

    private var lowerRimOpacity: CGFloat {
        min(0.040 * opacity * (0.80 + glassIntensity * 0.08), 0.075)
    }

    private var upperGlowOpacity: CGFloat {
        min(0.13 * opacity * (0.85 + glassIntensity * 0.10), 0.24)
    }

    private var lowerShadowOpacity: CGFloat {
        min(0.085 * opacity * (0.80 + glassIntensity * 0.12), 0.16)
    }
}

private struct VisualizerPreviewDot: View {
    let dotRadius: CGFloat
    let opacity: CGFloat
    let glassIntensity: CGFloat
    let aeroBlue: Color

    var body: some View {
        Circle()
            .fill(dotFill)
            .overlay { topStroke }
            .overlay { bottomStroke }
            .shadow(color: .white.opacity(upperGlowOpacity), radius: 3.5 + glassIntensity * 0.8, x: -0.8, y: -0.8)
            .shadow(color: .black.opacity(lowerShadowOpacity), radius: 6 + glassIntensity * 1.6, x: 0, y: 1.2)
    }

    private var dotFill: RadialGradient {
        RadialGradient(
            colors: [
                .white.opacity(coreOpacity),
                .white.opacity(midOpacity),
                aeroBlue.opacity(edgeOpacity)
            ],
            center: .topLeading,
            startRadius: 0,
            endRadius: dotRadius * 1.6
        )
    }

    private var topStroke: some View {
        Circle()
            .stroke(.white.opacity(topStrokeOpacity), lineWidth: 0.85)
    }

    private var bottomStroke: some View {
        Circle()
            .stroke(.black.opacity(bottomStrokeOpacity), lineWidth: 0.45)
    }

    private var coreOpacity: CGFloat {
        min(0.82 * opacity * (0.96 + glassIntensity * 0.06), 0.92)
    }

    private var midOpacity: CGFloat {
        min(0.54 * opacity * (0.92 + glassIntensity * 0.08), 0.76)
    }

    private var edgeOpacity: CGFloat {
        min(0.18 * opacity * (0.80 + glassIntensity * 0.12), 0.28)
    }

    private var topStrokeOpacity: CGFloat {
        min(0.45 * opacity * (0.90 + glassIntensity * 0.08), 0.58)
    }

    private var bottomStrokeOpacity: CGFloat {
        min(0.035 * opacity * (0.85 + glassIntensity * 0.10), 0.070)
    }

    private var upperGlowOpacity: CGFloat {
        min(0.20 * opacity * (0.86 + glassIntensity * 0.10), 0.32)
    }

    private var lowerShadowOpacity: CGFloat {
        min(0.090 * opacity * (0.85 + glassIntensity * 0.12), 0.17)
    }
}

private struct NormalPreviewScene: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let isDark = colorScheme == .dark

            ZStack {
                LinearGradient(
                    colors: isDark
                        ? [
                            Color(red: 0.12, green: 0.13, blue: 0.14),
                            Color(red: 0.18, green: 0.19, blue: 0.20)
                        ]
                        : [
                            Color(red: 0.83, green: 0.86, blue: 0.88),
                            Color(red: 0.74, green: 0.78, blue: 0.80)
                        ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.black.opacity(isDark ? 0.16 : 0.08))
                    .frame(width: size.width * 0.80, height: size.height * 0.76)
                    .offset(x: size.width * 0.020, y: size.height * 0.035)
                    .blur(radius: 7)

                appWindow(size: size, isDark: isDark)
                    .frame(width: size.width * 0.82, height: size.height * 0.74)
            }
        }
    }

    private func appWindow(size: CGSize, isDark: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isDark ? Color(red: 0.18, green: 0.19, blue: 0.20) : Color(red: 0.94, green: 0.95, blue: 0.95))

            VStack(spacing: 0) {
                toolbar(isDark: isDark)
                    .frame(height: max(size.height * 0.105, 22))

                HStack(spacing: 0) {
                    sidebar(isDark: isDark)
                        .frame(width: size.width * 0.18)

                    Divider().opacity(isDark ? 0.18 : 0.35)

                    documentArea(isDark: isDark)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.white.opacity(isDark ? 0.12 : 0.45), lineWidth: 0.7)
        }
    }

    private func toolbar(isDark: Bool) -> some View {
        HStack(spacing: 7) {
            Circle().fill(Color.red.opacity(0.74)).frame(width: 7, height: 7)
            Circle().fill(Color.yellow.opacity(0.74)).frame(width: 7, height: 7)
            Circle().fill(Color.green.opacity(0.74)).frame(width: 7, height: 7)

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(.white.opacity(isDark ? 0.08 : 0.58))
                .frame(width: 88, height: 12)
                .padding(.leading, 12)

            Spacer()
        }
        .padding(.horizontal, 12)
        .background(isDark ? Color.white.opacity(0.035) : Color.white.opacity(0.46))
    }

    private func sidebar(isDark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(.white.opacity(isDark ? 0.08 : 0.48))
                    .frame(width: index == 0 ? 40 : 32, height: 5)
            }

            Spacer()
        }
        .padding(12)
        .background(isDark ? Color.black.opacity(0.10) : Color.white.opacity(0.28))
    }

    private func documentArea(isDark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.07))
                .frame(width: 150, height: 11)
                .padding(.top, 14)

            ForEach(0..<7, id: \.self) { index in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.055))
                        .frame(width: 34, height: 24)

                    VStack(alignment: .leading, spacing: 5) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(isDark ? Color.white.opacity(0.11) : Color.black.opacity(0.10))
                            .frame(width: CGFloat([142, 118, 156, 132, 148, 112, 136][index]), height: 5)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(isDark ? Color.white.opacity(0.055) : Color.black.opacity(0.045))
                            .frame(width: CGFloat([96, 130, 86, 116, 102, 126, 90][index]), height: 4)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .background(isDark ? Color.white.opacity(0.018) : Color.white.opacity(0.34))
    }
}

private enum SettingsLayout {
    static let rowIconWidth: CGFloat = 18
    static let trailingControlWidth: CGFloat = 176
    static let compactControlHeight: CGFloat = 28
}

private struct TintStyleRow: View {
    @Binding var selection: VisualizerTintStyle

    var body: some View {
        SettingRow(
            icon: "paintpalette",
            title: localized("visualizer_tint", value: "Tint", comment: "Visualizer tint setting"),
            tooltip: localized("tooltip_visualizer_tint", value: "Controls the subtle tint of the glass visualizer.", comment: "Visualizer tint tooltip")
        ) {
            SettingsOptionMenu(
                selection: $selection,
                options: VisualizerTintStyle.allCases,
                title: \.displayName
            )
        }
    }
}

private struct GlassSection<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        LiquidGlassSurface(cornerRadius: 10, tintOpacity: 0.18, strokeOpacity: 0.38, shadowOpacity: 0.06) {
            VStack(spacing: 9) {
                content
            }
        }
    }
}

private struct SettingRow<Trailing: View>: View {
    let icon: String
    let title: String
    let tooltip: String
    var trailingWidth: CGFloat? = SettingsLayout.trailingControlWidth
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: SettingsLayout.rowIconWidth)

            Text(title)
                .font(.system(size: 12))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 8)

            Group {
                if let trailingWidth {
                    trailing
                        .frame(width: trailingWidth, alignment: .trailing)
                } else {
                    trailing
                }
            }
        }
        .help(tooltip)
    }
}

private struct ToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    let tooltip: String

    var body: some View {
        SettingRow(icon: icon, title: title, tooltip: tooltip) {
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
    }
}

private struct LanguagePickerRow: View {
    @Binding var selection: AppLanguage

    var body: some View {
        SettingRow(
            icon: "globe",
            title: localized("language", value: "Language", comment: "Language setting"),
            tooltip: localized("tooltip_language", value: "Choose the app language, or follow your system default.", comment: "Language tooltip")
        ) {
            SettingsOptionMenu(
                selection: $selection,
                options: AppLanguage.allCases,
                title: displayName(for:)
            )
        }
    }

    private func displayName(for language: AppLanguage) -> String {
        language == .system
            ? localized("system_default", value: "System Default", comment: "System default language")
            : language.displayName
    }
}

private struct AppearancePickerRow: View {
    @Binding var selection: AppAppearance

    var body: some View {
        SettingRow(
            icon: "circle.lefthalf.filled",
            title: localized("appearance", value: "Appearance", comment: "Appearance setting"),
            tooltip: localized("tooltip_appearance", value: "Choose Light, Dark, or follow the system appearance.", comment: "Appearance tooltip")
        ) {
            SettingsOptionMenu(
                selection: $selection,
                options: AppAppearance.allCases,
                title: \.displayName
            )
        }
    }
}

private struct SettingsOptionMenu<Option: Identifiable & Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let title: (Option) -> String
    var width: CGFloat = SettingsLayout.trailingControlWidth

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    selection = option
                } label: {
                    if option == selection {
                        Label(title(option), systemImage: "checkmark")
                    } else {
                        Text(title(option))
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(title(selection))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 8)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(width: width, height: SettingsLayout.compactControlHeight, alignment: .leading)
            .background(
                Color(nsColor: .controlBackgroundColor).opacity(0.70),
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.34), lineWidth: 0.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: SettingsLayout.rowIconWidth)

            Text(title)
                .font(.system(size: 12))

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

private struct LinkRow: View {
    let icon: String
    let title: String
    let url: URL
    var displayText: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: SettingsLayout.rowIconWidth)

            Text(title)
                .font(.system(size: 12))

            Spacer(minLength: 8)

            Link(destination: url) {
                Label(displayText ?? url.host ?? url.absoluteString, systemImage: "arrow.up.forward")
                    .font(.system(size: 11, weight: .medium))
            }
            .controlSize(.small)
        }
    }
}

private struct AssetLinkRow: View {
    let assetName: String
    let title: String
    let url: URL

    var body: some View {
        HStack(spacing: 8) {
            Image(assetName)
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(.secondary)
                .frame(width: 15, height: 15)
                .frame(width: SettingsLayout.rowIconWidth)

            Text(title)
                .font(.system(size: 12))

            Spacer(minLength: 8)

            Link(destination: url) {
                Label(url.host ?? url.absoluteString, systemImage: "arrow.up.forward")
                    .font(.system(size: 11, weight: .medium))
            }
            .controlSize(.small)
        }
    }
}

private struct StatusBadge: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(color.opacity(0.22), lineWidth: 0.5)
            }
    }
}

private struct SliderRow: View {
    let icon: String
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let formatString: String?
    let formatFunc: ((Double) -> String)?
    let tooltip: String

    init(
        icon: String,
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: String,
        tooltip: String
    ) {
        self.icon = icon
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.formatString = format
        self.formatFunc = nil
        self.tooltip = tooltip
    }

    init(
        icon: String,
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: @escaping (Double) -> String,
        tooltip: String
    ) {
        self.icon = icon
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.formatString = nil
        self.formatFunc = format
        self.tooltip = tooltip
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: SettingsLayout.rowIconWidth)

            Text(title)
                .font(.system(size: 11))
                .frame(width: 88, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Slider(value: $value, in: range, step: step)
                .controlSize(.small)

            Text(formattedValue)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
        .help(tooltip)
    }

    private var formattedValue: String {
        if let formatFunc {
            return formatFunc(value)
        }

        if let formatString {
            return String(format: formatString, value)
        }

        return "\(value)"
    }
}

private struct CompactAppRow: View {
    let bundleId: String
    let onRemove: () -> Void

    @State private var appName = ""
    @State private var appIcon: NSImage?
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            appIconView

            Text(appName.isEmpty ? bundleId : appName)
                .font(.system(size: 11))
                .lineLimit(1)

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 12))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .foregroundColor(isHovered ? .red : .secondary)
            .help(localized("remove", value: "Remove", comment: "Remove button"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.16) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onAppear(perform: loadAppInfo)
    }

    private var appIconView: some View {
        Group {
            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "app.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 16, height: 16)
    }

    private func loadAppInfo() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return
        }

        appIcon = NSWorkspace.shared.icon(forFile: url.path)
        appName = (url.lastPathComponent as NSString).deletingPathExtension
    }
}

private struct InlineAppPickerView: View {
    let excludedApps: [String]
    let frontmostBundleId: String?
    let onAdd: (String) -> Void

    @State private var apps: [(name: String, bundleId: String, icon: NSImage?)] = []
    @State private var searchText = ""
    @State private var customBundleId = ""
    @State private var isLoading = true

    private var filteredApps: [(name: String, bundleId: String, icon: NSImage?)] {
        let available = apps.filter { !excludedApps.contains($0.bundleId) }

        guard !searchText.isEmpty else {
            return Array(available.prefix(7))
        }

        return Array(available.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleId.localizedCaseInsensitiveContains(searchText)
        }.prefix(7))
    }

    private var normalizedCustomBundleId: String {
        SettingsManager.normalizedBundleIdentifier(customBundleId)
    }

    private var canAddCustomBundleId: Bool {
        let bundleId = normalizedCustomBundleId
        return !bundleId.isEmpty && !excludedApps.contains(bundleId)
    }

    var body: some View {
        VStack(spacing: 7) {
            Label(localized("add_ignored_app", value: "Add Ignored App", comment: "Add ignored app title"), systemImage: "plus.app")
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            searchField
            customBundleField

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(height: 58)
            } else if filteredApps.isEmpty {
                Text(localized("no_apps_found", value: "No apps found", comment: "No apps found"))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(height: 38)
            } else {
                VStack(spacing: 2) {
                    ForEach(filteredApps, id: \.bundleId) { app in
                        InlineAppPickerRow(
                            name: app.name,
                            bundleId: app.bundleId,
                            icon: app.icon,
                            isFrontmost: app.bundleId == frontmostBundleId,
                            onAdd: { onAdd(app.bundleId) }
                        )
                    }
                }
            }
        }
        .padding(.top, 4)
        .onAppear(perform: loadApps)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            TextField(localized("search", value: "Search", comment: "Search placeholder"), text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var customBundleField: some View {
        HStack(spacing: 6) {
            Image(systemName: "curlybraces")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            TextField(localized("custom_bundle_id", value: "Custom bundle ID", comment: "Custom bundle ID placeholder"), text: $customBundleId)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .onSubmit(addCustomBundleId)

            Button {
                addCustomBundleId()
            } label: {
                Label(localized("add", value: "Add", comment: "Add button"), systemImage: "plus.circle.fill")
                    .font(.system(size: 10, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .disabled(!canAddCustomBundleId)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.62), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .help(localized("tooltip_custom_bundle_id", value: "Use this when an app is not found in the picker. Example: com.company.AppName", comment: "Custom bundle ID tooltip"))
    }

    private func addCustomBundleId() {
        guard canAddCustomBundleId else { return }
        onAdd(normalizedCustomBundleId)
        customBundleId = ""
    }

    private func loadApps() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            let loadedApps = SettingsManager.shared.getInstalledApps(frontmostBundleId: frontmostBundleId)

            DispatchQueue.main.async {
                apps = loadedApps
                withAnimation(.easeOut(duration: 0.18)) {
                    isLoading = false
                }
            }
        }
    }
}

private extension AppAppearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

private struct InlineAppPickerRow: View {
    let name: String
    let bundleId: String
    let icon: NSImage?
    let isFrontmost: Bool
    let onAdd: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Image(systemName: "app.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 16, height: 16)

            Text(name)
                .font(.system(size: 11))
                .lineLimit(1)

            if isFrontmost {
                Text(localized("current", value: "Current", comment: "Current app badge"))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.accentColor.opacity(0.86), in: Capsule())
            }

            Spacer()

            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 12))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .foregroundColor(isHovered ? .accentColor : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.16) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

struct TriggerCaptureButton: View {
    @Binding var triggerConfig: TriggerConfig
    @State private var isRecording = false
    @State private var localMonitor: Any?
    @State private var globalMonitor: Any?

    var body: some View {
        Button {
            isRecording ? stopRecording() : startRecording()
        } label: {
            HStack(spacing: 5) {
                if isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)

                    Text(localized("recording", value: "Recording...", comment: "Recording..."))
                        .font(.system(size: 11))
                } else {
                    Text(triggerConfig.displayName)
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(minWidth: 86)
            .background(
                isRecording ? Color.red.opacity(0.14) : Color(nsColor: .controlBackgroundColor).opacity(0.65),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isRecording ? Color.red.opacity(0.42) : Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        isRecording = true
        SettingsManager.shared.isCapturingTrigger = true

        let eventMask: NSEvent.EventTypeMask = [
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown
        ]

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: eventMask) { event in
            handleMouseEvent(event)
            return nil
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { event in
            handleMouseEvent(event)
        }
    }

    private func stopRecording() {
        isRecording = false
        SettingsManager.shared.isCapturingTrigger = false

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }

        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }

    private func handleMouseEvent(_ event: NSEvent) {
        let button = Int(event.buttonNumber)
        let modifiers = event.modifierFlags

        var newConfig = TriggerConfig(
            mouseButton: button,
            requiresCommand: modifiers.contains(.command),
            requiresOption: modifiers.contains(.option),
            requiresControl: modifiers.contains(.control),
            requiresShift: modifiers.contains(.shift)
        )

        if button == 0 && !newConfig.hasModifiers {
            newConfig.requiresCommand = true
        }

        DispatchQueue.main.async {
            triggerConfig = newConfig
            stopRecording()
        }
    }
}
