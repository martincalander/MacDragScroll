//
//  SettingsManager.swift
//  macdragscroll
//
//  Created by Martin Calander on 2026-01-16.
//

import Foundation
import Combine
import AppKit
import ServiceManagement

// MARK: - Scroll Trigger Configuration

struct TriggerConfig: Codable, Equatable {
    var mouseButton: Int  // 0 = left, 1 = right, 2 = middle, 3+ = other buttons
    var requiresCommand: Bool
    var requiresOption: Bool
    var requiresControl: Bool
    var requiresShift: Bool
    
    // Default: middle click
    static let `default` = TriggerConfig(
        mouseButton: 2,
        requiresCommand: false,
        requiresOption: false,
        requiresControl: false,
        requiresShift: false
    )
    
    var hasModifiers: Bool {
        requiresCommand || requiresOption || requiresControl || requiresShift
    }
    
    var modifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if requiresCommand { flags.insert(.command) }
        if requiresOption { flags.insert(.option) }
        if requiresControl { flags.insert(.control) }
        if requiresShift { flags.insert(.shift) }
        return flags
    }
    
    var displayName: String {
        var parts: [String] = []
        
        // Add modifier symbols
        if requiresControl { parts.append("⌃") }
        if requiresOption { parts.append("⌥") }
        if requiresShift { parts.append("⇧") }
        if requiresCommand { parts.append("⌘") }
        
        // Add mouse button name
        let buttonName: String
        switch mouseButton {
        case 0:
            buttonName = NSLocalizedString("trigger_left_click", comment: "Left Click")
        case 1:
            buttonName = NSLocalizedString("trigger_right_click", comment: "Right Click")
        case 2:
            buttonName = NSLocalizedString("trigger_middle_click", comment: "Middle Click")
        default:
            buttonName = String(format: NSLocalizedString("trigger_button_n", comment: "Button %d"), mouseButton)
        }
        
        if parts.isEmpty {
            return buttonName
        } else {
            parts.append(buttonName)
            return parts.joined(separator: " + ")
        }
    }
    
    func matches(button: Int, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard button == mouseButton else { return false }
        
        // Check each required modifier
        if requiresCommand && !modifiers.contains(.command) { return false }
        if requiresOption && !modifiers.contains(.option) { return false }
        if requiresControl && !modifiers.contains(.control) { return false }
        if requiresShift && !modifiers.contains(.shift) { return false }
        
        // If trigger requires no modifiers, make sure none are pressed
        // (except for middle/right click which can be pressed with modifiers)
        if !hasModifiers && mouseButton == 0 {
            // Left click without modifiers is too easy to trigger accidentally
            // so we require at least one modifier for left click
            return false
        }
        
        return true
    }
    
    func modifiersStillHeld(_ modifiers: NSEvent.ModifierFlags) -> Bool {
        if requiresCommand && !modifiers.contains(.command) { return false }
        if requiresOption && !modifiers.contains(.option) { return false }
        if requiresControl && !modifiers.contains(.control) { return false }
        if requiresShift && !modifiers.contains(.shift) { return false }
        return true
    }
}

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    // Keys
    private let isEnabledKey = "isEnabled"
    private let animationsEnabledKey = "animationsEnabled"
    private let excludedAppsKey = "excludedApps"
    private let scrollSpeedKey = "scrollSpeed"
    private let deadZoneRadiusKey = "deadZoneRadius"
    private let accelerationKey = "acceleration"
    private let overlayOpacityKey = "overlayOpacity"
    private let triggerConfigKey = "triggerConfig"
    
    // Launch at Login using SMAppService (macOS 13+)
    @Published var launchAtLogin: Bool {
        didSet {
            setLaunchAtLogin(launchAtLogin)
        }
    }
    
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: isEnabledKey) }
    }
    
    @Published var animationsEnabled: Bool {
        didSet { defaults.set(animationsEnabled, forKey: animationsEnabledKey) }
    }
    
    @Published var excludedApps: [String] {
        didSet { defaults.set(excludedApps, forKey: excludedAppsKey) }
    }
    
    @Published var scrollSpeed: Double {
        didSet {
            let clamped = min(max(scrollSpeed, 0.5), 5.0)
            if clamped != scrollSpeed { scrollSpeed = clamped }
            defaults.set(scrollSpeed, forKey: scrollSpeedKey)
        }
    }

    @Published var deadZoneRadius: Double {
        didSet {
            let clamped = min(max(deadZoneRadius, 5.0), 50.0)
            if clamped != deadZoneRadius { deadZoneRadius = clamped }
            defaults.set(deadZoneRadius, forKey: deadZoneRadiusKey)
        }
    }

    @Published var acceleration: Double {
        didSet {
            let clamped = min(max(acceleration, 1.0), 3.0)
            if clamped != acceleration { acceleration = clamped }
            defaults.set(acceleration, forKey: accelerationKey)
        }
    }

    @Published var overlayOpacity: Double {
        didSet {
            let clamped = min(max(overlayOpacity, 0.2), 1.0)
            if clamped != overlayOpacity { overlayOpacity = clamped }
            defaults.set(overlayOpacity, forKey: overlayOpacityKey)
        }
    }
    
    @Published var triggerConfig: TriggerConfig {
        didSet { saveTriggerConfig() }
    }
    
    private init() {
        defaults.register(defaults: [
            isEnabledKey: true,
            animationsEnabledKey: true,
            excludedAppsKey: [String](),
            scrollSpeedKey: 2.0,
            deadZoneRadiusKey: 20.0,
            accelerationKey: 1.8,
            overlayOpacityKey: 1.0
        ])
        
        self.isEnabled = defaults.bool(forKey: isEnabledKey)
        self.animationsEnabled = defaults.bool(forKey: animationsEnabledKey)
        self.excludedApps = defaults.stringArray(forKey: excludedAppsKey) ?? []

        // Load and clamp values to valid ranges (protects against corrupted UserDefaults)
        let loadedSpeed = defaults.double(forKey: scrollSpeedKey)
        self.scrollSpeed = min(max(loadedSpeed, 0.5), 5.0)

        let loadedDeadZone = defaults.double(forKey: deadZoneRadiusKey)
        self.deadZoneRadius = min(max(loadedDeadZone, 5.0), 50.0)

        let loadedAcceleration = defaults.double(forKey: accelerationKey)
        self.acceleration = min(max(loadedAcceleration, 1.0), 3.0)

        let loadedOpacity = defaults.object(forKey: overlayOpacityKey) as? Double ?? 1.0
        self.overlayOpacity = min(max(loadedOpacity, 0.2), 1.0)

        self.triggerConfig = Self.loadTriggerConfig(from: defaults)
        
        // Check actual launch at login status from system
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }
    
    // MARK: - Trigger Config Persistence
    
    private static func loadTriggerConfig(from defaults: UserDefaults) -> TriggerConfig {
        guard let data = defaults.data(forKey: "triggerConfig"),
              let config = try? JSONDecoder().decode(TriggerConfig.self, from: data) else {
            return .default
        }
        return config
    }
    
    private func saveTriggerConfig() {
        if let data = try? JSONEncoder().encode(triggerConfig) {
            defaults.set(data, forKey: triggerConfigKey)
        }
    }
    
    // Check if app is excluded by bundle identifier
    func isAppExcluded(bundleIdentifier: String?) -> Bool {
        guard let bundleId = bundleIdentifier else { return false }
        return excludedApps.contains(bundleId)
    }
    
    // Get currently running applications (excluding system apps)
    func getRunningApps() -> [(name: String, bundleId: String)] {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .compactMap { app -> (name: String, bundleId: String)? in
                guard let bundleId = app.bundleIdentifier,
                      let name = app.localizedName else { return nil }
                return (name: name, bundleId: bundleId)
            }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    // Get the bundle identifier of the currently frontmost app (excluding our own app)
    func getFrontmostAppBundleId() -> String? {
        // Get the frontmost app that isn't our own app
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           let bundleId = frontmost.bundleIdentifier,
           bundleId != Bundle.main.bundleIdentifier {
            return bundleId
        }
        
        // If frontmost is our app, try to find the most recently active app
        // by looking at running apps with windows (menuBarOwningApplication is another option)
        if let menuBarApp = NSWorkspace.shared.menuBarOwningApplication,
           let bundleId = menuBarApp.bundleIdentifier,
           bundleId != Bundle.main.bundleIdentifier {
            return bundleId
        }
        
        // Fallback: find any regular app that isn't ours
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            if app.activationPolicy == .regular,
               let bundleId = app.bundleIdentifier,
               bundleId != Bundle.main.bundleIdentifier,
               app.isActive || app.ownsMenuBar {
                return bundleId
            }
        }
        
        return nil
    }
    
    // Get all installed applications, with optional frontmost app bundle ID to prioritize
    func getInstalledApps(frontmostBundleId: String? = nil) -> [(name: String, bundleId: String, icon: NSImage?)] {
        var apps: [(name: String, bundleId: String, icon: NSImage?)] = []
        
        let appDirectories = [
            "/Applications",
            "/System/Applications",
            NSHomeDirectory() + "/Applications"
        ]
        
        let fileManager = FileManager.default
        
        for directory in appDirectories {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else { continue }
            
            for item in contents where item.hasSuffix(".app") {
                let appPath = (directory as NSString).appendingPathComponent(item)
                let plistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
                
                if let plist = NSDictionary(contentsOfFile: plistPath),
                   let bundleId = plist["CFBundleIdentifier"] as? String {
                    let name = (item as NSString).deletingPathExtension
                    let icon = NSWorkspace.shared.icon(forFile: appPath)
                    apps.append((name: name, bundleId: bundleId, icon: icon))
                }
            }
        }
        
        // Sort alphabetically
        apps.sort { $0.name.lowercased() < $1.name.lowercased() }
        
        // If we have a frontmost app, move it to the top
        if let frontmost = frontmostBundleId,
           let index = apps.firstIndex(where: { $0.bundleId == frontmost }) {
            let frontmostApp = apps.remove(at: index)
            apps.insert(frontmostApp, at: 0)
        }
        
        return apps
    }
    
    func addExcludedApp(_ bundleId: String) {
        if !excludedApps.contains(bundleId) {
            excludedApps.append(bundleId)
        }
    }
    
    func removeExcludedApp(_ bundleId: String) {
        excludedApps.removeAll { $0 == bundleId }
    }
    
    // MARK: - Reset to Defaults
    
    func resetToDefaults() {
        isEnabled = true
        animationsEnabled = true
        scrollSpeed = 2.0
        deadZoneRadius = 20.0
        acceleration = 1.8
        overlayOpacity = 1.0
        triggerConfig = .default
        excludedApps = []
        // Note: launchAtLogin is not reset as it's a system preference
    }
    
    // MARK: - Launch at Login
    
    private func getLaunchAtLoginStatus() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            // Revert the published value if operation failed
            DispatchQueue.main.async {
                self.launchAtLogin = self.getLaunchAtLoginStatus()
            }
        }
    }
}

