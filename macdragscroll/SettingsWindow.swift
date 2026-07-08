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
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var permissionState = AppDelegate.permissionState
    @ObservedObject private var updateManager = UpdateManager.shared
    @ObservedObject private var navigation = SettingsWindowNavigation.shared

    @State private var showingAppPicker = false
    @State private var capturedFrontmostBundleId: String?
    @State private var showingResetConfirmation = false
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
                            if !permissionState.hasAccessibilityPermission {
                                permissionBanner
                            }

	                            contentHeader
	                            selectedContent
	                                .id(navigation.selectedTab)
	                                .transition(.opacity.combined(with: .move(edge: .trailing)))
	                        }
	                        .padding(22)
	                        .frame(maxWidth: .infinity, alignment: .topLeading)
	                        .animation(.smooth(duration: 0.22), value: navigation.selectedTab)
                    }
                }

                Divider()
                bottomBar
            }
        }
        .frame(minWidth: 760, minHeight: 560)
        .background {
            SettingsKeyboardMonitor { command in
                handleKeyboardCommand(command)
            }
            .frame(width: 0, height: 0)
        }
        .onAppear {
            focusedSidebarTab = navigation.selectedTab
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
            navigation.selectedTab = tab
        }
    }

    private var contentHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(navigation.selectedTab.title, systemImage: navigation.selectedTab.icon)
                .font(.system(size: 20, weight: .semibold))
                .labelStyle(.titleAndIcon)

            Text(navigation.selectedTab.subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
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

                SettingRow(
                    icon: "computermouse",
                    title: localized("trigger_button", value: "Trigger Button", comment: "Trigger Button setting"),
                    tooltip: localized("tooltip_trigger", value: "Click to capture a new mouse trigger.", comment: "Trigger button tooltip")
                ) {
                    TriggerCaptureButton(triggerConfig: $settings.triggerConfig)
                }

                Divider()

                ToggleRow(
                    icon: "arrow.up.arrow.down",
                    title: localized("reverse_direction", value: "Reverse Direction", comment: "Reverse Direction toggle"),
                    isOn: $settings.reverseScrollDirection,
                    tooltip: localized("tooltip_reverse_direction", value: "Flip drag scrolling if the direction feels backwards.", comment: "Reverse direction tooltip")
                )
            }

            GlassSection {
                ToggleRow(
                    icon: "rectangle.on.rectangle",
                    title: localized("launch_at_login", value: "Launch at Login", comment: "Launch at Login toggle"),
                    isOn: $settings.launchAtLogin,
                    tooltip: localized("tooltip_launch_at_login", value: "Automatically start Mac Drag Scroll when you log in.", comment: "Launch at login tooltip")
                )

                Divider()

                LanguagePickerRow(selection: $settings.appLanguage)
            }
        }
    }

    private var visualizerSettings: some View {
        VStack(spacing: 14) {
            VisualizerPreviewCard(settings: settings)

            GlassSection {
                ToggleRow(
                    icon: "dot.circle",
                    title: localized("show_indicator", value: "Show Indicator", comment: "Show Indicator toggle"),
                    isOn: $settings.animationsEnabled,
                    tooltip: localized("tooltip_show_indicator", value: "Show the visual indicator while drag scrolling.", comment: "Show indicator tooltip")
                )

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
        }
    }

    private var appSettings: some View {
        GlassSection {
            HStack(spacing: 8) {
                Image(systemName: "app.badge")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                Text(localized("excluded_apps", value: "Ignored Apps", comment: "Excluded Apps section"))
                    .font(.system(size: 12, weight: .medium))

                Spacer()

                Button {
                    if !showingAppPicker {
                        capturedFrontmostBundleId = SettingsManager.shared.getFrontmostAppBundleId()
                    }
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showingAppPicker.toggle()
                    }
                } label: {
                    Label(
                        showingAppPicker ? localized("cancel", value: "Cancel", comment: "Cancel button") : localized("add_app", value: "Add App", comment: "Add app button"),
                        systemImage: showingAppPicker ? "xmark.circle.fill" : "plus.circle.fill"
                    )
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

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
            } else if !showingAppPicker {
                Text(localized("no_excluded_apps", value: "No ignored apps yet.", comment: "No excluded apps message"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 26)
            }

            if showingAppPicker {
                InlineAppPickerView(
                    excludedApps: settings.excludedApps,
                    frontmostBundleId: capturedFrontmostBundleId,
                    onAdd: { bundleId in
                        withAnimation(.easeOut(duration: 0.15)) {
                            settings.addExcludedApp(bundleId)
                        }
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var permissionsSettings: some View {
        VStack(spacing: 14) {
            GlassSection {
                HStack(spacing: 12) {
                    Image(systemName: permissionState.hasAccessibilityPermission ? "checkmark.shield.fill" : "hand.raised.circle.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(permissionState.hasAccessibilityPermission ? .green : .orange)
                        .frame(width: 34)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(localized("permission_accessibility", value: "Accessibility Permission", comment: "Accessibility permission title"))
                            .font(.system(size: 13, weight: .semibold))
                        Text(permissionState.hasAccessibilityPermission
                             ? localized("permission_accessibility_granted_detail", value: "Mac Drag Scroll can monitor the configured mouse trigger and send scroll events.", comment: "Accessibility granted detail")
                             : localized("permission_accessibility_missing_detail", value: "Grant Accessibility permission so the app can detect mouse drags globally.", comment: "Accessibility missing detail"))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    StatusBadge(
                        title: permissionState.hasAccessibilityPermission
                            ? localized("permission_granted", value: "Granted", comment: "Permission granted")
                            : localized("permission_needed", value: "Needed", comment: "Permission needed"),
                        color: permissionState.hasAccessibilityPermission ? .green : .orange
                    )
                }

                Divider()

                HStack(spacing: 8) {
                    Button {
                        AppDelegate.openAccessibilitySettings()
                    } label: {
                        Label(localized("open_system_settings", value: "Open System Settings", comment: "Open System Settings button"), systemImage: "gearshape")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button {
                        permissionState.refresh()
                    } label: {
                        Label(localized("refresh", value: "Refresh", comment: "Refresh button"), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()
                }
            }

            GlassSection {
                InfoRow(
                    icon: "cursorarrow.motionlines",
                    title: localized("event_monitoring", value: "Event Monitoring", comment: "Event monitoring label"),
                    value: permissionState.hasAccessibilityPermission && settings.isEnabled
                        ? localized("status_active", value: "Active", comment: "Active state")
                        : localized("status_waiting", value: "Waiting", comment: "Waiting state")
                )

                Divider()

                InfoRow(
                    icon: "power",
                    title: localized("app_state", value: "App State", comment: "App state label"),
                    value: settings.isEnabled
                        ? localized("status_enabled", value: "Enabled", comment: "Enabled state")
                        : localized("status_disabled", value: "Disabled", comment: "Disabled state")
                )
            }
        }
    }

    private var updateSettings: some View {
        VStack(spacing: 14) {
            GlassSection {
                ToggleRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: localized("auto_update", value: "Auto Update", comment: "Auto update toggle"),
                    isOn: $updateManager.autoUpdateEnabled,
                    tooltip: localized("tooltip_auto_update", value: "Automatically check GitHub Releases for newer versions.", comment: "Auto update tooltip")
                )

                Divider()

                InfoRow(
                    icon: "shippingbox",
                    title: localized("current_version", value: "Current Version", comment: "Current version label"),
                    value: updateManager.currentVersion
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

            GlassSection {
                VStack(alignment: .leading, spacing: 8) {
                    Label(localized("update_history", value: "Update History", comment: "Update history title"), systemImage: "list.bullet.rectangle")
                        .font(.system(size: 12, weight: .semibold))

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
    }

    private var aboutSettings: some View {
        VStack(spacing: 14) {
            GlassSection {
                HStack(spacing: 16) {
                    Image("BrandMark")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 92, height: 92)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 6)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(AppDelegate.appName)
                            .font(.system(size: 28, weight: .semibold))
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
                Text(localized("accessibility_permissions_required", value: "Accessibility Permission Required", comment: "Permission required title"))
                    .font(.system(size: 12, weight: .semibold))
                Text(localized("app_needs_permission", value: "Mac Drag Scroll needs permission to monitor mouse input globally.", comment: "App needs permission message"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(localized("open_system_settings", value: "Open System Settings", comment: "Open System Settings button")) {
                AppDelegate.openAccessibilitySettings()
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
            Label(
                settings.isEnabled
                    ? localized("status_enabled", value: "Active", comment: "Enabled status")
                    : localized("status_disabled", value: "Disabled", comment: "Disabled status"),
                systemImage: settings.isEnabled ? "checkmark.circle.fill" : "pause.circle.fill"
	            )
	            .font(.system(size: 11, weight: .medium))
	            .foregroundStyle(settings.isEnabled ? .primary : .secondary)

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
            return localized("settings_updates_subtitle", value: "Check releases, auto update status, and update history.", comment: "Updates settings subtitle")
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

    @Published var selectedTab: SettingsTab = .visualizer

    private init() {}
}

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
        let opacity = settings.overlayOpacity
        let glassIntensity = CGFloat(settings.liquidGlassIntensity)
        let distance = sqrt(previewDrag.width * previewDrag.width + previewDrag.height * previewDrag.height)
        let unitX = distance > 0 ? previewDrag.width / distance : 0
        let unitY = distance > 0 ? previewDrag.height / distance : 0
        let effectiveDistance = max(distance - settings.deadZoneRadius, 0)
        let travel = min(effectiveDistance * (0.55 + glassIntensity * 0.07), side * 0.25)
        let dotRadius = min(max(side * 0.074, 4.0), 10.0)
        let tint = settings.visualizerTintStyle.glassTintColor(intensity: settings.liquidGlassIntensity).map(Color.init(nsColor:)) ?? .clear

        return ZStack {
            Circle()
                .fill(Color.white.opacity(0.01))
                .glassEffect(.regular.tint(tint), in: Circle())
                .overlay {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(min((0.14 + min(effectiveDistance / 42, 1) * 0.07) * opacity * (0.80 + glassIntensity * 0.22), 0.34)),
                                    .white.opacity(min(0.030 * opacity * (0.9 + glassIntensity * 0.18), 0.12)),
                                    .black.opacity(min(0.020 * opacity * (0.9 + glassIntensity * 0.10), 0.08))
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                }
                .overlay {
                    Circle()
                        .stroke(.black.opacity(0.12 * opacity), lineWidth: 1)
                }

            Circle()
                .fill(.white.opacity(min(0.52 * opacity * (0.92 + glassIntensity * 0.08), 0.72)))
                .frame(width: dotRadius * 2, height: dotRadius * 2)
                .shadow(color: .black.opacity(min(0.16 * opacity * (0.9 + glassIntensity * 0.16), 0.30)), radius: 7 + glassIntensity * 2, x: 0, y: 1.5)
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

private struct TintStyleRow: View {
    @Binding var selection: VisualizerTintStyle

    var body: some View {
        SettingRow(
            icon: "paintpalette",
            title: localized("visualizer_tint", value: "Tint", comment: "Visualizer tint setting"),
            tooltip: localized("tooltip_visualizer_tint", value: "Controls the subtle tint of the glass visualizer.", comment: "Visualizer tint tooltip")
        ) {
            Picker("", selection: $selection) {
                ForEach(VisualizerTintStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.menu)
            .controlSize(.small)
            .frame(width: 126)
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
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(title)
                .font(.system(size: 12))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 8)
            trailing
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
            Picker("", selection: $selection) {
                ForEach(AppLanguage.allCases) { language in
                    Text(displayName(for: language)).tag(language)
                }
            }
            .pickerStyle(.menu)
            .controlSize(.small)
            .frame(width: 176)
        }
    }

    private func displayName(for language: AppLanguage) -> String {
        language == .system
            ? localized("system_default", value: "System Default", comment: "System default language")
            : language.displayName
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
                .frame(width: 18)

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

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 18)

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
                .frame(width: 18)

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
                .frame(width: 18)

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
            .help("Remove")
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

    var body: some View {
        VStack(spacing: 7) {
            searchField

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
