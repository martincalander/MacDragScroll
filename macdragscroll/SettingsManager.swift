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
        didSet { defaults.set(scrollSpeed, forKey: scrollSpeedKey) }
    }
    
    @Published var deadZoneRadius: Double {
        didSet { defaults.set(deadZoneRadius, forKey: deadZoneRadiusKey) }
    }
    
    @Published var acceleration: Double {
        didSet { defaults.set(acceleration, forKey: accelerationKey) }
    }
    
    @Published var overlayOpacity: Double {
        didSet { defaults.set(overlayOpacity, forKey: overlayOpacityKey) }
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
        self.scrollSpeed = defaults.double(forKey: scrollSpeedKey)
        self.deadZoneRadius = defaults.double(forKey: deadZoneRadiusKey)
        self.acceleration = defaults.double(forKey: accelerationKey)
        self.overlayOpacity = defaults.object(forKey: overlayOpacityKey) as? Double ?? 1.0
        
        // Check actual launch at login status from system
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
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
        // If frontmost is our app, try to get the previously active app
        // by looking at running apps
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

