//
//  SettingsWindow.swift
//  macdragscroll
//
//  Created by Martin Calander on 2026-01-16.
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var showingAppPicker = false
    
    private func accelerationLabel(_ value: Double) -> String {
        if value < 1.4 { return "Linear" }
        if value < 1.8 { return "Light" }
        if value < 2.2 { return "Normal" }
        if value < 2.6 { return "Strong" }
        return "Aggressive"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    // General Section
                    SettingsSection(title: "General") {
                        SettingsToggle(
                            title: "Enable Drag Scrolling",
                            subtitle: "Hold middle mouse button to scroll",
                            isOn: $settings.isEnabled
                        )
                    }
                    
                    // Appearance Section
                    SettingsSection(title: "Appearance") {
                        SettingsToggle(
                            title: "Animations",
                            subtitle: "Bouncy animations on the scroll indicator",
                            isOn: $settings.animationsEnabled
                        )
                    }
                    
                    // Scroll Behavior Section
                    SettingsSection(title: "Scroll Behavior") {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Scroll Speed")
                                        .font(.system(size: 13))
                                    Spacer()
                                    Text(String(format: "%.1fx", settings.scrollSpeed))
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Slider(value: $settings.scrollSpeed, in: 0.5...5.0, step: 0.5)
                                    .controlSize(.small)
                            }
                            
                            Divider()
                                .padding(.vertical, 4)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Acceleration")
                                        .font(.system(size: 13))
                                    Spacer()
                                    Text(accelerationLabel(settings.acceleration))
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Slider(value: $settings.acceleration, in: 1.0...3.0, step: 0.2)
                                    .controlSize(.small)
                                Text("How quickly scroll speed increases with distance")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                                .padding(.vertical, 4)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Dead Zone")
                                        .font(.system(size: 13))
                                    Spacer()
                                    Text("\(Int(settings.deadZoneRadius))px")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Slider(value: $settings.deadZoneRadius, in: 5...50, step: 5)
                                    .controlSize(.small)
                                Text("Area around origin where scrolling doesn't activate")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Excluded Apps Section
                    SettingsSection(title: "Excluded Apps") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Scrolling is disabled in these apps")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            
                            if settings.excludedApps.isEmpty {
                                HStack {
                                    Spacer()
                                    Text("No excluded apps")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            } else {
                                VStack(spacing: 4) {
                                    ForEach(settings.excludedApps, id: \.self) { bundleId in
                                        ExcludedAppRow(bundleId: bundleId) {
                                            settings.removeExcludedApp(bundleId)
                                        }
                                    }
                                }
                            }
                            
                            Button(action: {
                                showingAppPicker = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 14))
                                    Text("Add Application")
                                        .font(.system(size: 13))
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 380, height: 560)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView(
                excludedApps: settings.excludedApps,
                onAdd: { bundleId in
                    settings.addExcludedApp(bundleId)
                },
                onDismiss: {
                    showingAppPicker = false
                }
            )
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

struct SettingsToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}

struct ExcludedAppRow: View {
    let bundleId: String
    let onRemove: () -> Void
    
    @State private var appName: String = ""
    @State private var appIcon: NSImage?
    
    var body: some View {
        HStack(spacing: 10) {
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "app.fill")
                    .frame(width: 24, height: 24)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(appName.isEmpty ? bundleId : appName)
                    .font(.system(size: 12))
                    .lineLimit(1)
                if !appName.isEmpty {
                    Text(bundleId)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(NSColor.separatorColor).opacity(0.1))
        .cornerRadius(6)
        .onAppear {
            loadAppInfo()
        }
    }
    
    private func loadAppInfo() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            appIcon = NSWorkspace.shared.icon(forFile: url.path)
            let name = (url.lastPathComponent as NSString).deletingPathExtension
            appName = name
        }
    }
}

struct AppPickerView: View {
    let excludedApps: [String]
    let onAdd: (String) -> Void
    let onDismiss: () -> Void
    
    @State private var apps: [(name: String, bundleId: String, icon: NSImage?)] = []
    @State private var searchText = ""
    @State private var isLoading = true
    
    var filteredApps: [(name: String, bundleId: String, icon: NSImage?)] {
        if searchText.isEmpty {
            return apps.filter { !excludedApps.contains($0.bundleId) }
        }
        return apps.filter { 
            !excludedApps.contains($0.bundleId) &&
            ($0.name.localizedCaseInsensitiveContains(searchText) ||
             $0.bundleId.localizedCaseInsensitiveContains(searchText))
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Application")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
            .padding(16)
            
            Divider()
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search apps...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // App List
            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredApps, id: \.bundleId) { app in
                            AppPickerRow(
                                name: app.name,
                                bundleId: app.bundleId,
                                icon: app.icon
                            ) {
                                onAdd(app.bundleId)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(width: 340, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadApps()
        }
    }
    
    private func loadApps() {
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedApps = SettingsManager.shared.getInstalledApps()
            DispatchQueue.main.async {
                self.apps = loadedApps
                self.isLoading = false
            }
        }
    }
}

struct AppPickerRow: View {
    let name: String
    let bundleId: String
    let icon: NSImage?
    let onAdd: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 10) {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: "app.fill")
                    .frame(width: 28, height: 28)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Text(bundleId)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0.7)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(isHovered ? Color(NSColor.separatorColor).opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// Window controller for settings
class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "MacDragScroll Settings"
        window.center()
        window.contentView = NSHostingView(rootView: SettingsView())
        window.isReleasedWhenClosed = false
        
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func showSettings() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
