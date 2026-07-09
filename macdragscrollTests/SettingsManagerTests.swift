//
//  SettingsManagerTests.swift
//  macdragscrollTests
//
//  Created by Martin Calander on 2026-01-17.
//

import XCTest
import Sparkle
@testable import macdragscroll

final class SettingsManagerTests: XCTestCase {
    
    var settings: SettingsManager!
    private var originalHasCompletedWelcome = false
    private var originalAppLanguage: AppLanguage = .system
    private var originalAppAppearance: AppAppearance = .system
    private var originalShowIndicator = true
    private var originalVisualizerAnimationsEnabled = true
    private var originalKeepRunningInMenuBar = true
    
    override func setUp() {
        super.setUp()
        settings = SettingsManager.shared
        originalHasCompletedWelcome = settings.hasCompletedWelcome
        originalAppLanguage = settings.appLanguage
        originalAppAppearance = settings.appAppearance
        originalShowIndicator = settings.showIndicator
        originalVisualizerAnimationsEnabled = settings.visualizerAnimationsEnabled
        originalKeepRunningInMenuBar = settings.keepRunningInMenuBar
    }
    
    override func tearDown() {
        // Reset excluded apps after each test
        settings.excludedApps = []
        settings.reverseScrollDirection = false
        settings.horizontalScrollingEnabled = true
        settings.invertHorizontalScroll = false
        settings.visualizerSize = 1.0
        settings.visualizerTintStyle = .clear
        settings.liquidGlassIntensity = 1.35
        settings.hasCompletedWelcome = originalHasCompletedWelcome
        settings.appLanguage = originalAppLanguage
        settings.appAppearance = originalAppAppearance
        settings.showIndicator = originalShowIndicator
        settings.visualizerAnimationsEnabled = originalVisualizerAnimationsEnabled
        settings.keepRunningInMenuBar = originalKeepRunningInMenuBar
        super.tearDown()
    }
    
    // MARK: - App Exclusion Tests
    
    func testIsAppExcludedWithNilBundleId() {
        let result = settings.isAppExcluded(bundleIdentifier: nil)
        XCTAssertFalse(result, "Nil bundle identifier should return false")
    }
    
    func testIsAppExcludedWithNonExcludedApp() {
        settings.excludedApps = []
        let result = settings.isAppExcluded(bundleIdentifier: "com.example.nonexcluded")
        XCTAssertFalse(result, "Non-excluded app should return false")
    }
    
    func testIsAppExcludedWithExcludedApp() {
        let testBundleId = "com.example.testapp"
        settings.excludedApps = [testBundleId]
        
        let result = settings.isAppExcluded(bundleIdentifier: testBundleId)
        XCTAssertTrue(result, "Excluded app should return true")
    }
    
    func testAddExcludedAppNoDuplicates() {
        settings.excludedApps = []
        let testBundleId = "com.example.duplicatetest"
        
        settings.addExcludedApp(testBundleId)
        settings.addExcludedApp(testBundleId)
        settings.addExcludedApp(testBundleId)
        
        let count = settings.excludedApps.filter { $0 == testBundleId }.count
        XCTAssertEqual(count, 1, "Should not create duplicate entries")
    }

    func testAddExcludedAppTrimsCustomBundleIdentifier() {
        settings.excludedApps = []

        settings.addExcludedApp("  com.example.CustomApp\n")

        XCTAssertEqual(settings.excludedApps, ["com.example.CustomApp"])
    }
    
    func testRemoveExcludedApp() {
        let testBundleId = "com.example.removetest"
        settings.excludedApps = [testBundleId, "com.other.app"]
        
        settings.removeExcludedApp(testBundleId)
        
        XCTAssertFalse(settings.excludedApps.contains(testBundleId), "Removed app should not be in list")
        XCTAssertTrue(settings.excludedApps.contains("com.other.app"), "Other apps should remain")
    }
    
    func testRemoveExcludedAppThatDoesNotExist() {
        settings.excludedApps = ["com.existing.app"]
        let initialCount = settings.excludedApps.count
        
        settings.removeExcludedApp("com.nonexistent.app")
        
        XCTAssertEqual(settings.excludedApps.count, initialCount, "Removing non-existent app should not change list")
    }
    
    // MARK: - Default Settings Tests

    func testPreferencesUseStableUserDefaultsDomain() {
        XCTAssertEqual(PersistentPreferences.domainIdentifier, "com.martincalander.macdragscroll")
        XCTAssertEqual(
            PersistentPreferences.preferencesFilePath,
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Preferences/com.martincalander.macdragscroll.plist")
                .path
        )
        let probeKey = "persistentPreferencesTestProbe"
        defer {
            PersistentPreferences.userDefaults.removeObject(forKey: probeKey)
            PersistentPreferences.userDefaults.synchronize()
        }

        PersistentPreferences.userDefaults.set("ok", forKey: probeKey)
        PersistentPreferences.userDefaults.synchronize()

        XCTAssertEqual(
            PersistentPreferences.userDefaults.persistentDomain(forName: PersistentPreferences.domainIdentifier)?[probeKey] as? String,
            "ok"
        )
    }
    
    func testDefaultScrollSpeedRange() {
        XCTAssertGreaterThanOrEqual(settings.scrollSpeed, 0.5, "Scroll speed should be >= 0.5")
        XCTAssertLessThanOrEqual(settings.scrollSpeed, 5.0, "Scroll speed should be <= 5.0")
    }
    
    func testDefaultDeadZoneRange() {
        XCTAssertGreaterThanOrEqual(settings.deadZoneRadius, 5.0, "Dead zone radius should be >= 5")
        XCTAssertLessThanOrEqual(settings.deadZoneRadius, 50.0, "Dead zone radius should be <= 50")
    }
    
    func testDefaultOverlayOpacityRange() {
        XCTAssertGreaterThanOrEqual(settings.overlayOpacity, 0.0, "Overlay opacity should be >= 0")
        XCTAssertLessThanOrEqual(settings.overlayOpacity, 1.0, "Overlay opacity should be <= 1")
    }

    func testDefaultVisualizerSizeRange() {
        XCTAssertGreaterThanOrEqual(settings.visualizerSize, SettingsManager.visualizerSizeRange.lowerBound)
        XCTAssertLessThanOrEqual(settings.visualizerSize, SettingsManager.visualizerSizeRange.upperBound)
    }

    func testDefaultLiquidGlassIntensityRange() {
        XCTAssertGreaterThanOrEqual(settings.liquidGlassIntensity, SettingsManager.liquidGlassIntensityRange.lowerBound)
        XCTAssertLessThanOrEqual(settings.liquidGlassIntensity, SettingsManager.liquidGlassIntensityRange.upperBound)
    }

    func testVisualizerAppearanceSettingsClampToSupportedRanges() {
        settings.visualizerSize = 0.1
        settings.liquidGlassIntensity = 9.0

        XCTAssertEqual(settings.visualizerSize, SettingsManager.visualizerSizeRange.lowerBound, accuracy: 0.001)
        XCTAssertEqual(settings.liquidGlassIntensity, SettingsManager.liquidGlassIntensityRange.upperBound, accuracy: 0.001)
    }

    func testWelcomeCompletionCanBePersisted() {
        settings.hasCompletedWelcome = false
        XCTAssertFalse(settings.hasCompletedWelcome)

        settings.hasCompletedWelcome = true
        XCTAssertTrue(settings.hasCompletedWelcome)
    }

    func testCompleteWelcomeMarksOnboardingDone() {
        settings.hasCompletedWelcome = false

        settings.completeWelcome()

        XCTAssertTrue(settings.hasCompletedWelcome)
    }

    func testDefaultLanguageUsesSystemDefault() {
        settings.resetToDefaults()

        XCTAssertEqual(settings.appLanguage, .system)
    }

    func testDefaultAppearanceUsesSystemDefault() {
        settings.resetToDefaults()

        XCTAssertEqual(settings.appAppearance, .system)
    }

    func testDefaultVisualizerControlsShowAndAnimateIndicator() {
        settings.resetToDefaults()

        XCTAssertTrue(settings.showIndicator)
        XCTAssertTrue(settings.visualizerAnimationsEnabled)
    }

    func testDefaultKeepsAppRunningInMenuBar() {
        settings.keepRunningInMenuBar = false

        settings.resetToDefaults()

        XCTAssertTrue(settings.keepRunningInMenuBar)
    }

    func testKeepRunningInMenuBarCanBePersisted() {
        settings.keepRunningInMenuBar = false
        XCTAssertFalse(settings.keepRunningInMenuBar)

        settings.keepRunningInMenuBar = true
        XCTAssertTrue(settings.keepRunningInMenuBar)
    }

    func testLanguageSelectionCanBePersisted() {
        settings.appLanguage = .swedish
        XCTAssertEqual(settings.appLanguage, .swedish)

        settings.appLanguage = .system
        XCTAssertEqual(settings.appLanguage, .system)
    }

    func testSelectedLanguageLoadsBundledTranslation() {
        settings.appLanguage = .swedish

        let translated = AppLocalization.shared.localizedString("appearance", value: "Appearance", comment: "Appearance setting")

        XCTAssertEqual(translated, "Utseende")
    }

    func testAllBundledLanguageFilesHaveSameLocalizationKeys() {
        guard let englishKeys = localizationKeys(for: "en") else {
            return XCTFail("Expected English localization to be bundled")
        }

        for language in AppLanguage.allCases {
            guard let code = language.lprojCode else { continue }
            guard let keys = localizationKeys(for: code) else {
                XCTFail("Expected localization bundle for \(code)")
                continue
            }

            XCTAssertEqual(keys, englishKeys, "\(code) should contain the same localization keys as English")
        }
    }

    func testAppearanceSelectionCanBePersisted() {
        settings.appAppearance = .dark
        XCTAssertEqual(settings.appAppearance, .dark)

        settings.appAppearance = .system
        XCTAssertEqual(settings.appAppearance, .system)
    }

    func testSystemDefaultsUseSystemLanguageAndAppearance() {
        XCTAssertNil(AppLanguage.system.lprojCode)
        XCTAssertNil(AppAppearance.system.nsAppearance)
    }

    func testAppBundleTitleMetadataUsesDisplayName() {
        let appBundle = Bundle(for: AppDelegate.self)

        XCTAssertEqual(appBundle.object(forInfoDictionaryKey: "CFBundleName") as? String, "Mac Drag Scroll")
        XCTAssertEqual(appBundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "Mac Drag Scroll")
    }

    func testAppBundleVersionMetadataUsesStableReleaseValues() {
        let appBundle = Bundle(for: AppDelegate.self)

        XCTAssertEqual(appBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String, "1.0.1")
        XCTAssertEqual(appBundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String, "101")
        XCTAssertEqual(AppDelegate.appVersion, "1.0.1")
        XCTAssertEqual(AppDelegate.appBuild, "101")
    }

    func testSparkleUpdateConfigurationIsPresent() {
        let appBundle = Bundle(for: AppDelegate.self)

        XCTAssertEqual(
            appBundle.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            "https://github.com/martincalander/MacDragScroll/releases/latest/download/appcast.xml"
        )
        XCTAssertEqual(
            appBundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
            "IRTPmGbPo3tpWiuGZIjzn99mFwiCjaCCPw6Kz62hkvQ="
        )
        XCTAssertEqual(appBundle.object(forInfoDictionaryKey: "SUEnableAutomaticChecks") as? Bool, true)
    }

    func testSparkleNoUpdateErrorIsTreatedAsUpToDate() {
        settings.appLanguage = .english

        let noUpdateError = NSError(
            domain: SUSparkleErrorDomain,
            code: Int(SUError.noUpdateError.rawValue)
        )

        XCTAssertTrue(UpdateManager.isNoUpdateError(noUpdateError))
        XCTAssertEqual(UpdateStatus.upToDate.statusTitle, "Up to Date")
        XCTAssertEqual(UpdateStatus.upToDate.statusDetail, "You are running the newest known version.")
    }

    func testSparkleRealFailureIsNotTreatedAsUpToDate() {
        let downloadError = NSError(
            domain: SUSparkleErrorDomain,
            code: Int(SUError.downloadError.rawValue)
        )

        XCTAssertFalse(UpdateManager.isNoUpdateError(downloadError))
    }

    func testPermissionStateResetsMonitoringWhenAccessibilityIsMissing() {
        let isTrusted = false
        let state = AppDelegate.PermissionState(
            accessibilityPermissionChecker: { isTrusted },
            accessibilityPermissionRequester: { _ in isTrusted },
            inputMonitoringPermissionChecker: { true },
            inputMonitoringPermissionRequester: { true }
        )

        state.setEventMonitoringState(.active)
        state.refresh()

        XCTAssertFalse(state.hasAccessibilityPermission)
        XCTAssertTrue(state.hasInputMonitoringPermission)
        XCTAssertFalse(state.hasRequiredPermissions)
        XCTAssertEqual(state.eventMonitoringState, .waiting)
    }

    func testPermissionStateResetsMonitoringWhenInputMonitoringIsMissing() {
        let state = AppDelegate.PermissionState(
            accessibilityPermissionChecker: { true },
            accessibilityPermissionRequester: { _ in true },
            inputMonitoringPermissionChecker: { false },
            inputMonitoringPermissionRequester: { false }
        )

        state.setEventMonitoringState(.active)
        state.refresh()

        XCTAssertTrue(state.hasAccessibilityPermission)
        XCTAssertFalse(state.hasInputMonitoringPermission)
        XCTAssertFalse(state.hasRequiredPermissions)
        XCTAssertEqual(state.eventMonitoringState, .waiting)
    }

    func testPermissionStateCanRequestAccessibilityPermission() {
        var promptWasRequested = false
        var inputMonitoringWasRequested = false
        let state = AppDelegate.PermissionState(
            accessibilityPermissionChecker: { false },
            accessibilityPermissionRequester: { shouldPrompt in
                promptWasRequested = shouldPrompt
                return true
            },
            inputMonitoringPermissionChecker: { false },
            inputMonitoringPermissionRequester: {
                inputMonitoringWasRequested = true
                return true
            }
        )

        XCTAssertTrue(state.request())

        XCTAssertTrue(promptWasRequested)
        XCTAssertTrue(inputMonitoringWasRequested)
        XCTAssertTrue(state.hasAccessibilityPermission)
        XCTAssertTrue(state.hasInputMonitoringPermission)
        XCTAssertTrue(state.hasRequiredPermissions)
    }

    func testPermissionStatePreservesFailedMonitoringStateWhileTrusted() {
        let state = AppDelegate.PermissionState(
            accessibilityPermissionChecker: { true },
            accessibilityPermissionRequester: { _ in true },
            inputMonitoringPermissionChecker: { true },
            inputMonitoringPermissionRequester: { true }
        )

        state.setEventMonitoringState(.failed)
        state.refresh()

        XCTAssertTrue(state.hasAccessibilityPermission)
        XCTAssertEqual(state.eventMonitoringState, .failed)
    }

    func testVisualizerVisibilityAndAnimationCanBeConfiguredIndependently() {
        settings.showIndicator = false
        settings.visualizerAnimationsEnabled = true

        XCTAssertFalse(settings.showIndicator)
        XCTAssertTrue(settings.visualizerAnimationsEnabled)

        settings.showIndicator = true
        settings.visualizerAnimationsEnabled = false

        XCTAssertTrue(settings.showIndicator)
        XCTAssertFalse(settings.visualizerAnimationsEnabled)
    }
    
    func testDefaultAccelerationPositive() {
        XCTAssertGreaterThan(settings.acceleration, 0, "Acceleration should be positive")
    }

    func testResetToDefaultsUsesNormalScrollDirection() {
        settings.reverseScrollDirection = true
        settings.horizontalScrollingEnabled = false
        settings.invertHorizontalScroll = true
        settings.visualizerSize = 1.4
        settings.visualizerTintStyle = .aqua
        settings.liquidGlassIntensity = 1.9
        settings.appAppearance = .dark
        settings.showIndicator = false
        settings.visualizerAnimationsEnabled = false
        settings.keepRunningInMenuBar = false

        settings.resetToDefaults()

        XCTAssertFalse(settings.reverseScrollDirection, "Default drag scroll direction should not be reversed")
        XCTAssertTrue(settings.horizontalScrollingEnabled, "Horizontal scrolling should be enabled by default")
        XCTAssertFalse(settings.invertHorizontalScroll, "Horizontal scrolling should not be inverted by default")
        XCTAssertEqual(settings.visualizerSize, 1.0, accuracy: 0.001)
        XCTAssertEqual(settings.visualizerTintStyle, .clear)
        XCTAssertEqual(settings.liquidGlassIntensity, 1.35, accuracy: 0.001)
        XCTAssertEqual(settings.appAppearance, .system)
        XCTAssertTrue(settings.showIndicator)
        XCTAssertTrue(settings.visualizerAnimationsEnabled)
        XCTAssertTrue(settings.keepRunningInMenuBar)
    }

    func testSettingsTabKeyboardShortcutsMatchSidebarOrder() {
        XCTAssertEqual(SettingsTab.tab(forShortcut: "1"), .general)
        XCTAssertEqual(SettingsTab.tab(forShortcut: "2"), .visualizer)
        XCTAssertEqual(SettingsTab.tab(forShortcut: "3"), .scrolling)
        XCTAssertEqual(SettingsTab.tab(forShortcut: "4"), .apps)
        XCTAssertEqual(SettingsTab.tab(forShortcut: "5"), .permissions)
        XCTAssertEqual(SettingsTab.tab(forShortcut: "6"), .updates)
        XCTAssertEqual(SettingsTab.tab(forShortcut: "7"), .about)
        XCTAssertNil(SettingsTab.tab(forShortcut: "8"))
    }

    func testSettingsTabKeyboardNavigationWraps() {
        XCTAssertEqual(SettingsTab.previous(before: .general), .about)
        XCTAssertEqual(SettingsTab.next(after: .about), .general)
        XCTAssertEqual(SettingsTab.previous(before: .visualizer), .general)
        XCTAssertEqual(SettingsTab.next(after: .visualizer), .scrolling)
    }

    func testCrashReportFileNameIsStableAndSanitized() {
        let date = Date(timeIntervalSince1970: 1_767_817_200)

        let fileName = CrashHandler.crashReportFileName(kind: "SIG/SEGV:Bad Value", date: date, processID: 42)

        XCTAssertTrue(fileName.hasPrefix("MacDragScroll-Crash-"))
        XCTAssertTrue(fileName.hasSuffix("-SIG-SEGV-Bad-Value-42.log"))
        XCTAssertFalse(fileName.contains("/"))
        XCTAssertFalse(fileName.contains(":"))
    }

    func testCrashReportDiscoveryReturnsNewestLogFilesFirst() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let older = directory.appendingPathComponent("older.log")
        let newer = directory.appendingPathComponent("newer.log")
        let ignored = directory.appendingPathComponent("ignored.txt")

        try "older".write(to: older, atomically: true, encoding: .utf8)
        try "newer".write(to: newer, atomically: true, encoding: .utf8)
        try "ignored".write(to: ignored, atomically: true, encoding: .utf8)

        let olderDate = Date(timeIntervalSince1970: 100)
        let newerDate = Date(timeIntervalSince1970: 200)
        try FileManager.default.setAttributes([.creationDate: olderDate, .modificationDate: olderDate], ofItemAtPath: older.path)
        try FileManager.default.setAttributes([.creationDate: newerDate, .modificationDate: newerDate], ofItemAtPath: newer.path)

        let reports = CrashHandler.crashReports(in: directory)

        XCTAssertEqual(reports.map(\.fileName), ["newer.log", "older.log"])
    }
    
    // MARK: - Settings Persistence Tests
    
    func testExcludedAppsMultipleEntries() {
        let apps = ["com.app1.test", "com.app2.test", "com.app3.test"]
        settings.excludedApps = apps
        
        XCTAssertEqual(settings.excludedApps.count, 3, "Should store all excluded apps")
        for app in apps {
            XCTAssertTrue(settings.isAppExcluded(bundleIdentifier: app), "\(app) should be excluded")
        }
    }

    private func localizationKeys(for lprojCode: String) -> Set<String>? {
        guard let path = Bundle.main.path(forResource: lprojCode, ofType: "lproj"),
              let strings = NSDictionary(contentsOfFile: (path as NSString).appendingPathComponent("Localizable.strings")) as? [String: String] else {
            return nil
        }

        return Set(strings.keys)
    }
}

final class TriggerConfigTests: XCTestCase {

    func testDefaultTriggerMatchesMiddleClickWithoutModifiers() {
        let config = TriggerConfig.default

        XCTAssertTrue(config.matches(button: 2, modifiers: []))
        XCTAssertFalse(config.matches(button: 1, modifiers: []))
    }

    func testLeftClickRequiresModifierForSafety() {
        let unsafeLeftClick = TriggerConfig(
            mouseButton: 0,
            requiresCommand: false,
            requiresOption: false,
            requiresControl: false,
            requiresShift: false
        )

        XCTAssertFalse(unsafeLeftClick.matches(button: 0, modifiers: []))
    }

    func testRightClickRequiresModifierForTrackpadSafety() {
        let unsafeRightClick = TriggerConfig(
            mouseButton: 1,
            requiresCommand: false,
            requiresOption: false,
            requiresControl: false,
            requiresShift: false
        )

        XCTAssertFalse(unsafeRightClick.matches(button: 1, modifiers: []))
    }

    func testRequiredModifiersMustRemainHeld() {
        let config = TriggerConfig(
            mouseButton: 2,
            requiresCommand: true,
            requiresOption: true,
            requiresControl: false,
            requiresShift: false
        )

        XCTAssertTrue(config.matches(button: 2, modifiers: [.command, .option]))
        XCTAssertFalse(config.matches(button: 2, modifiers: [.command]))
        XCTAssertTrue(config.modifiersStillHeld([.command, .option, .shift]))
        XCTAssertFalse(config.modifiersStillHeld([.option]))
    }
}
