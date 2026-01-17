//
//  SettingsWindow.swift
//  macdragscroll
//
//  Created by Martin Calander on 2026-01-16.
//

import SwiftUI
import AppKit
import ApplicationServices

// MARK: - Layout Configuration
// Adjust these values to change the popover dimensions
private let kPopoverWidth: CGFloat = 380          // Width of the settings popover
private let kPopoverHeightWithPermission: CGFloat = 440   // Height when permission granted
private let kPopoverHeightNoPermission: CGFloat = 220     // Height when permission required
private let kAppPickerWidth: CGFloat = 340        // Width of the app picker sheet
private let kAppPickerHeight: CGFloat = 380       // Height of the app picker sheet

// MARK: - Menu Bar Settings View (Popover)

struct MenuBarSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var permissionState = AppDelegate.permissionState
    @State private var showingAppPicker = false
    @State private var capturedFrontmostBundleId: String? = nil
    
    private var hasPermission: Bool {
        permissionState.hasAccessibilityPermission
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if hasPermission {
                // Header - only shown when permission is granted
                HStack {
                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(AppDelegate.appName)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Toggle("", isOn: $settings.isEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                
                // Normal settings view
                settingsContent
            } else {
                // Permission required view (no header)
                permissionRequiredView
            }
            
            Divider()
            
            // Footer
            HStack(spacing: 4) {
                Text("v\(AppDelegate.appVersion)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text("•")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("\(NSLocalizedString("made_by", comment: "Made by")) ©")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                            .font(.system(size: 10))
                        Text(NSLocalizedString("quit", comment: "Quit button"))
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: kPopoverWidth, height: hasPermission ? kPopoverHeightWithPermission : kPopoverHeightNoPermission)
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView(
                excludedApps: settings.excludedApps,
                frontmostBundleId: capturedFrontmostBundleId,
                onAdd: { settings.addExcludedApp($0) },
                onDismiss: { showingAppPicker = false }
            )
        }
    }
    
    // MARK: - Permission Required View
    
    private var permissionRequiredView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "hand.raised.circle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text(NSLocalizedString("accessibility_permissions_required", comment: "Permission required title"))
                    .font(.system(size: 14, weight: .semibold))
                Text(NSLocalizedString("app_needs_permission", comment: "App needs permission message"))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                AppDelegate.openAccessibilitySettings()
            }) {
                Text(NSLocalizedString("open_system_settings", comment: "Open System Settings button"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Settings Content
    
    private var settingsContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Sliders Section
                VStack(spacing: 12) {
                    SliderRow(
                        icon: "gauge.with.dots.needle.50percent",
                        title: NSLocalizedString("speed", comment: "Speed setting"),
                        value: $settings.scrollSpeed,
                        range: 0.5...5.0,
                        step: 0.5,
                        format: "%.1fx"
                    )
                    
                    SliderRow(
                        icon: "arrow.up.right",
                        title: NSLocalizedString("acceleration", comment: "Acceleration setting"),
                        value: $settings.acceleration,
                        range: 1.0...3.0,
                        step: 0.2,
                        format: { v in
                            switch v {
                            case ..<1.4: return NSLocalizedString("acceleration_low", comment: "Low")
                            case ..<2.0: return NSLocalizedString("acceleration_med", comment: "Med")
                            case ..<2.6: return NSLocalizedString("acceleration_high", comment: "High")
                            default: return NSLocalizedString("acceleration_max", comment: "Max")
                            }
                        }
                    )
                    
                    SliderRow(
                        icon: "circle.dashed",
                        title: NSLocalizedString("dead_zone", comment: "Dead Zone setting"),
                        value: $settings.deadZoneRadius,
                        range: 5...50,
                        step: 5,
                        format: "%.0fpx"
                    )
                    
                    SliderRow(
                        icon: "circle.lefthalf.filled",
                        title: NSLocalizedString("opacity", comment: "Opacity setting"),
                        value: $settings.overlayOpacity,
                        range: 0.2...1.0,
                        step: 0.05,
                        format: { v in
                            let pct = Int((v * 100).rounded())
                            return "\(pct)%"
                        }
                    )
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
                
                // Toggles Section
                VStack(spacing: 8) {
                    // Show Indicator Toggle
                    HStack {
                        Image(systemName: "dot.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 18)
                        Text(NSLocalizedString("show_indicator", comment: "Show Indicator toggle"))
                            .font(.system(size: 12))
                        Spacer()
                        Toggle("", isOn: $settings.animationsEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                    }
                    
                    Divider()
                    
                    // Launch at Login Toggle
                    HStack {
                        Image(systemName: "power")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 18)
                        Text(NSLocalizedString("launch_at_login", comment: "Launch at Login toggle"))
                            .font(.system(size: 12))
                        Spacer()
                        Toggle("", isOn: $settings.launchAtLogin)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
                
                // Excluded Apps
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "app.badge.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 18)
                        Text(NSLocalizedString("excluded_apps", comment: "Excluded Apps section"))
                            .font(.system(size: 12))
                        Spacer()
                        Button(action: {
                            // Capture frontmost app BEFORE opening the picker
                            capturedFrontmostBundleId = SettingsManager.shared.getFrontmostAppBundleId()
                            showingAppPicker = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
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
                    }
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            }
            .padding(12)
        }
    }
}

// MARK: - Slider Row

struct SliderRow: View {
    let icon: String
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let formatString: String?
    let formatFunc: ((Double) -> String)?
    
    init(icon: String, title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, format: String) {
        self.icon = icon
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.formatString = format
        self.formatFunc = nil
    }
    
    init(icon: String, title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, format: @escaping (Double) -> String) {
        self.icon = icon
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.formatString = nil
        self.formatFunc = format
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 16)
            
            Text(title)
                .font(.system(size: 11))
                .frame(width: 70, alignment: .leading)
            
            Slider(value: $value, in: range, step: step)
                .controlSize(.small)
            
            Text(formattedValue)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
    
    private var formattedValue: String {
        if let formatFunc = formatFunc {
            return formatFunc(value)
        } else if let formatString = formatString {
            return String(format: formatString, value)
        }
        return "\(value)"
    }
}

// MARK: - Compact App Row

struct CompactAppRow: View {
    let bundleId: String
    let onRemove: () -> Void
    
    @State private var appName: String = ""
    @State private var appIcon: NSImage?
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let icon = appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Image(systemName: "app.fill")
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 16, height: 16)
            
            Text(appName.isEmpty ? bundleId : appName)
                .font(.system(size: 11))
                .lineLimit(1)
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(isHovered ? .red : .secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onAppear { loadAppInfo() }
    }
    
    private func loadAppInfo() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            appIcon = NSWorkspace.shared.icon(forFile: url.path)
            appName = (url.lastPathComponent as NSString).deletingPathExtension
        }
    }
}

// MARK: - Skeleton Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.white.opacity(0.4),
                            Color.clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: -geometry.size.width * 0.3 + (geometry.size.width * 1.6) * phase)
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.2)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Row

struct SkeletonAppRow: View {
    var body: some View {
        HStack(spacing: 10) {
            // Icon placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .separatorColor).opacity(0.3))
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                // Name placeholder
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(nsColor: .separatorColor).opacity(0.3))
                    .frame(width: CGFloat.random(in: 80...140), height: 12)
            }
            
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .shimmer()
    }
}

// MARK: - App Picker View

struct AppPickerView: View {
    let excludedApps: [String]
    let frontmostBundleId: String?
    let onAdd: (String) -> Void
    let onDismiss: () -> Void
    
    @State private var apps: [(name: String, bundleId: String, icon: NSImage?)] = []
    @State private var searchText = ""
    @State private var isLoading = true
    
    var filteredApps: [(name: String, bundleId: String, icon: NSImage?)] {
        let available = apps.filter { !excludedApps.contains($0.bundleId) }
        guard !searchText.isEmpty else { return available }
        return available.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleId.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                
                TextField(NSLocalizedString("search", comment: "Search placeholder"), text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .padding(12)
            
            Divider()
            
            // App List
            if isLoading {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(0..<10, id: \.self) { _ in
                            SkeletonAppRow()
                        }
                    }
                    .padding(8)
                }
            } else if filteredApps.isEmpty {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "app.badge.questionmark")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("no_apps_found", comment: "No apps found"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredApps, id: \.bundleId) { app in
                            AppPickerRow(
                                name: app.name,
                                bundleId: app.bundleId,
                                icon: app.icon,
                                isFrontmost: app.bundleId == frontmostBundleId,
                                onAdd: { onAdd(app.bundleId) }
                            )
                        }
                    }
                    .padding(8)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            
            Divider()
            
            // Done button
            HStack {
                Spacer()
                Button(NSLocalizedString("done", comment: "Done button")) { onDismiss() }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.small)
            }
            .padding(10)
        }
        .frame(width: kAppPickerWidth, height: kAppPickerHeight)
        .onAppear { loadApps() }
    }
    
    private func loadApps() {
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedApps = SettingsManager.shared.getInstalledApps(frontmostBundleId: frontmostBundleId)
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.25)) {
                    apps = loadedApps
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - App Picker Row

struct AppPickerRow: View {
    let name: String
    let bundleId: String
    let icon: NSImage?
    let isFrontmost: Bool
    let onAdd: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let icon = icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Image(systemName: "app.fill")
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(name)
                        .font(.system(size: 12))
                        .lineLimit(1)
                    
                    if isFrontmost {
                        Text(NSLocalizedString("current", comment: "Current app badge"))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.8))
                            .cornerRadius(3)
                    }
                }
            }
            
            Spacer()
            
            if isHovered {
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isHovered ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) { isHovered = hovering }
        }
    }
}
