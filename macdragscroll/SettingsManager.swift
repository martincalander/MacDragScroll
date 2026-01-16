//
//  SettingsManager.swift
//  macdragscroll
//
//  Created by Martin Calander on 2026-01-16.
//

import Foundation
import Combine
import AppKit

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
    
    private init() {
        defaults.register(defaults: [
            isEnabledKey: true,
            animationsEnabledKey: true,
            excludedAppsKey: [String](),
            scrollSpeedKey: 2.0,
            deadZoneRadiusKey: 20.0,
            accelerationKey: 1.8
        ])
        
        self.isEnabled = defaults.bool(forKey: isEnabledKey)
        self.animationsEnabled = defaults.bool(forKey: animationsEnabledKey)
        self.excludedApps = defaults.stringArray(forKey: excludedAppsKey) ?? []
        self.scrollSpeed = defaults.double(forKey: scrollSpeedKey)
        self.deadZoneRadius = defaults.double(forKey: deadZoneRadiusKey)
        self.acceleration = defaults.double(forKey: accelerationKey)
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
    
    // Get all installed applications
    func getInstalledApps() -> [(name: String, bundleId: String, icon: NSImage?)] {
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
        
        return apps.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    func addExcludedApp(_ bundleId: String) {
        if !excludedApps.contains(bundleId) {
            excludedApps.append(bundleId)
        }
    }
    
    func removeExcludedApp(_ bundleId: String) {
        excludedApps.removeAll { $0 == bundleId }
    }
}
