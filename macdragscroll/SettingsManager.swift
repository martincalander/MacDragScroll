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

// MARK: - App Language

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system
    case english
    case swedish
    case chineseSimplified
    case chineseTraditional
    case japanese
    case german
    case french
    case spanish
    case portugueseBrazil
    case korean
    case italian
    case dutch
    case russian
    case vietnamese

    var id: String { rawValue }

    var lprojCode: String? {
        switch self {
        case .system:
            return nil
        case .english:
            return "en"
        case .swedish:
            return "sv"
        case .chineseSimplified:
            return "zh-Hans"
        case .chineseTraditional:
            return "zh-Hant"
        case .japanese:
            return "ja"
        case .german:
            return "de"
        case .french:
            return "fr"
        case .spanish:
            return "es"
        case .portugueseBrazil:
            return "pt-BR"
        case .korean:
            return "ko"
        case .italian:
            return "it"
        case .dutch:
            return "nl"
        case .russian:
            return "ru"
        case .vietnamese:
            return "vi"
        }
    }

    var displayName: String {
        switch self {
        case .system:
            return "System Default"
        case .english:
            return "English"
        case .swedish:
            return "Svenska"
        case .chineseSimplified:
            return "简体中文"
        case .chineseTraditional:
            return "繁體中文"
        case .japanese:
            return "日本語"
        case .german:
            return "Deutsch"
        case .french:
            return "Français"
        case .spanish:
            return "Español"
        case .portugueseBrazil:
            return "Português (Brasil)"
        case .korean:
            return "한국어"
        case .italian:
            return "Italiano"
        case .dutch:
            return "Nederlands"
        case .russian:
            return "Русский"
        case .vietnamese:
            return "Tiếng Việt"
        }
    }
}

// MARK: - App Appearance

enum AppAppearance: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            return AppLocalization.shared.localizedString("system_default", value: "System Default", comment: "System default appearance")
        case .light:
            return AppLocalization.shared.localizedString("appearance_light", value: "Light", comment: "Light appearance")
        case .dark:
            return AppLocalization.shared.localizedString("appearance_dark", value: "Dark", comment: "Dark appearance")
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }
}

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
            buttonName = AppLocalization.shared.localizedString("trigger_left_click", value: "Left Click", comment: "Left Click")
        case 1:
            buttonName = AppLocalization.shared.localizedString("trigger_right_click", value: "Right Click", comment: "Right Click")
        case 2:
            buttonName = AppLocalization.shared.localizedString("trigger_middle_click", value: "Middle Click", comment: "Middle Click")
        default:
            let format = AppLocalization.shared.localizedString("trigger_button_n", value: "Button %d", comment: "Button %d")
            buttonName = String(format: format, mouseButton)
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
        
        // Primary and secondary clicks are common trackpad gestures. Require a
        // modifier for them so normal trackpad clicking and dragging stays safe.
        if !hasModifiers && mouseButton <= 1 {
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

// MARK: - Visualizer Appearance

enum VisualizerTintStyle: String, CaseIterable, Identifiable, Codable {
    case clear
    case graphite
    case accent
    case aqua
    case warm

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .clear:
            return localized("visualizer_tint_clear", value: "Clear", comment: "Clear visualizer tint")
        case .graphite:
            return localized("visualizer_tint_graphite", value: "Graphite", comment: "Graphite visualizer tint")
        case .accent:
            return localized("visualizer_tint_accent", value: "Accent", comment: "Accent visualizer tint")
        case .aqua:
            return localized("visualizer_tint_aqua", value: "Aqua", comment: "Aqua visualizer tint")
        case .warm:
            return localized("visualizer_tint_warm", value: "Warm", comment: "Warm visualizer tint")
        }
    }

    var glassTintColor: NSColor? {
        glassTintColor(intensity: 1.0)
    }

    func glassTintColor(intensity: Double) -> NSColor? {
        let multiplier = min(max(intensity, 0.7), 2.0)
        switch self {
        case .clear:
            return nil
        case .graphite:
            return NSColor.labelColor.withAlphaComponent(0.08 + 0.035 * multiplier)
        case .accent:
            return NSColor.controlAccentColor.withAlphaComponent(0.10 + 0.035 * multiplier)
        case .aqua:
            return NSColor.systemCyan.withAlphaComponent(0.10 + 0.035 * multiplier)
        case .warm:
            return NSColor.systemOrange.withAlphaComponent(0.08 + 0.035 * multiplier)
        }
    }

    private func localized(_ key: String, value: String, comment: String) -> String {
        AppLocalization.shared.localizedString(key, value: value, comment: comment)
    }
}

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    static let visualizerSizeRange: ClosedRange<Double> = 0.45...1.5
    static let liquidGlassIntensityRange: ClosedRange<Double> = 0.7...2.0
    
    private let defaults = PersistentPreferences.userDefaults

    @Published var isCapturingTrigger = false
    
    // Keys
    private let isEnabledKey = "isEnabled"
    private let keepRunningInMenuBarKey = "keepRunningInMenuBar"
    private let showIndicatorKey = "animationsEnabled" // Legacy key name, kept to preserve existing preferences.
    private let visualizerAnimationsEnabledKey = "visualizerAnimationsEnabled"
    private let excludedAppsKey = "excludedApps"
    private let scrollSpeedKey = "scrollSpeed"
    private let deadZoneRadiusKey = "deadZoneRadius"
    private let accelerationKey = "acceleration"
    private let overlayOpacityKey = "overlayOpacity"
    private let visualizerSizeKey = "visualizerSize"
    private let visualizerTintStyleKey = "visualizerTintStyle"
    private let liquidGlassIntensityKey = "liquidGlassIntensity"
    private let reverseScrollDirectionKey = "reverseScrollDirection"
    private let horizontalScrollingEnabledKey = "horizontalScrollingEnabled"
    private let invertHorizontalScrollKey = "invertHorizontalScroll"
    private let triggerConfigKey = "triggerConfig"
    private let hasCompletedWelcomeKey = "hasCompletedWelcome"
    private let appLanguageKey = "appLanguage"
    private let appAppearanceKey = "appAppearance"
    
    // Launch at Login using SMAppService (macOS 13+)
    @Published var launchAtLogin: Bool {
        didSet {
            setLaunchAtLogin(launchAtLogin)
        }
    }
    
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: isEnabledKey) }
    }

    @Published var keepRunningInMenuBar: Bool {
        didSet { defaults.set(keepRunningInMenuBar, forKey: keepRunningInMenuBarKey) }
    }
    
    @Published var showIndicator: Bool {
        didSet { defaults.set(showIndicator, forKey: showIndicatorKey) }
    }

    @Published var visualizerAnimationsEnabled: Bool {
        didSet { defaults.set(visualizerAnimationsEnabled, forKey: visualizerAnimationsEnabledKey) }
    }

    @Published var reverseScrollDirection: Bool {
        didSet { defaults.set(reverseScrollDirection, forKey: reverseScrollDirectionKey) }
    }

    @Published var horizontalScrollingEnabled: Bool {
        didSet { defaults.set(horizontalScrollingEnabled, forKey: horizontalScrollingEnabledKey) }
    }

    @Published var invertHorizontalScroll: Bool {
        didSet { defaults.set(invertHorizontalScroll, forKey: invertHorizontalScrollKey) }
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

    @Published var visualizerSize: Double {
        didSet {
            let clamped = min(max(visualizerSize, Self.visualizerSizeRange.lowerBound), Self.visualizerSizeRange.upperBound)
            if clamped != visualizerSize { visualizerSize = clamped }
            defaults.set(visualizerSize, forKey: visualizerSizeKey)
        }
    }

    @Published var visualizerTintStyle: VisualizerTintStyle {
        didSet { defaults.set(visualizerTintStyle.rawValue, forKey: visualizerTintStyleKey) }
    }

    @Published var liquidGlassIntensity: Double {
        didSet {
            let clamped = min(max(liquidGlassIntensity, Self.liquidGlassIntensityRange.lowerBound), Self.liquidGlassIntensityRange.upperBound)
            if clamped != liquidGlassIntensity { liquidGlassIntensity = clamped }
            defaults.set(liquidGlassIntensity, forKey: liquidGlassIntensityKey)
        }
    }

    @Published var hasCompletedWelcome: Bool {
        didSet { defaults.set(hasCompletedWelcome, forKey: hasCompletedWelcomeKey) }
    }

    @Published var appLanguage: AppLanguage {
        didSet { defaults.set(appLanguage.rawValue, forKey: appLanguageKey) }
    }

    @Published var appAppearance: AppAppearance {
        didSet { defaults.set(appAppearance.rawValue, forKey: appAppearanceKey) }
    }
    
    @Published var triggerConfig: TriggerConfig {
        didSet { saveTriggerConfig() }
    }
    
    private init() {
        defaults.register(defaults: [
            isEnabledKey: true,
            keepRunningInMenuBarKey: true,
            showIndicatorKey: true,
            visualizerAnimationsEnabledKey: true,
            excludedAppsKey: [String](),
            scrollSpeedKey: 2.0,
            deadZoneRadiusKey: 20.0,
            accelerationKey: 1.8,
            overlayOpacityKey: 1.0,
            visualizerSizeKey: 1.0,
            visualizerTintStyleKey: VisualizerTintStyle.clear.rawValue,
            liquidGlassIntensityKey: 1.35,
            reverseScrollDirectionKey: false,
            horizontalScrollingEnabledKey: true,
            invertHorizontalScrollKey: false,
            hasCompletedWelcomeKey: false,
            appLanguageKey: AppLanguage.system.rawValue,
            appAppearanceKey: AppAppearance.system.rawValue
        ])
        
        self.isEnabled = defaults.bool(forKey: isEnabledKey)
        self.keepRunningInMenuBar = defaults.bool(forKey: keepRunningInMenuBarKey)
        self.showIndicator = defaults.bool(forKey: showIndicatorKey)
        self.visualizerAnimationsEnabled = defaults.bool(forKey: visualizerAnimationsEnabledKey)
        self.reverseScrollDirection = defaults.bool(forKey: reverseScrollDirectionKey)
        self.horizontalScrollingEnabled = defaults.object(forKey: horizontalScrollingEnabledKey) == nil ? true : defaults.bool(forKey: horizontalScrollingEnabledKey)
        self.invertHorizontalScroll = defaults.bool(forKey: invertHorizontalScrollKey)
        self.hasCompletedWelcome = defaults.bool(forKey: hasCompletedWelcomeKey)
        let appLanguageRawValue = defaults.string(forKey: appLanguageKey) ?? AppLanguage.system.rawValue
        self.appLanguage = AppLanguage(rawValue: appLanguageRawValue) ?? .system
        let appAppearanceRawValue = defaults.string(forKey: appAppearanceKey) ?? AppAppearance.system.rawValue
        self.appAppearance = AppAppearance(rawValue: appAppearanceRawValue) ?? .system
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

        let loadedVisualizerSize = defaults.object(forKey: visualizerSizeKey) as? Double ?? 1.0
        self.visualizerSize = min(max(loadedVisualizerSize, Self.visualizerSizeRange.lowerBound), Self.visualizerSizeRange.upperBound)

        let tintRawValue = defaults.string(forKey: visualizerTintStyleKey) ?? VisualizerTintStyle.clear.rawValue
        self.visualizerTintStyle = VisualizerTintStyle(rawValue: tintRawValue) ?? .clear

        let loadedLiquidGlassIntensity = defaults.object(forKey: liquidGlassIntensityKey) as? Double ?? 1.35
        self.liquidGlassIntensity = min(
            max(loadedLiquidGlassIntensity, Self.liquidGlassIntensityRange.lowerBound),
            Self.liquidGlassIntensityRange.upperBound
        )

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

    func completeWelcome() {
        hasCompletedWelcome = true
        defaults.set(true, forKey: hasCompletedWelcomeKey)
        defaults.synchronize()
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
        let normalizedBundleId = Self.normalizedBundleIdentifier(bundleId)
        guard !normalizedBundleId.isEmpty else { return }

        if !excludedApps.contains(normalizedBundleId) {
            excludedApps.append(normalizedBundleId)
        }
    }
    
    func removeExcludedApp(_ bundleId: String) {
        excludedApps.removeAll { $0 == bundleId }
    }

    static func normalizedBundleIdentifier(_ bundleId: String) -> String {
        bundleId.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Reset to Defaults
    
    func resetToDefaults() {
        isEnabled = true
        keepRunningInMenuBar = true
        showIndicator = true
        visualizerAnimationsEnabled = true
        reverseScrollDirection = false
        horizontalScrollingEnabled = true
        invertHorizontalScroll = false
        scrollSpeed = 2.0
        deadZoneRadius = 20.0
        acceleration = 1.8
        overlayOpacity = 1.0
        visualizerSize = 1.0
        visualizerTintStyle = .clear
        liquidGlassIntensity = 1.35
        appLanguage = .system
        appAppearance = .system
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
