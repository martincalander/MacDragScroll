//
//  SettingsManagerTests.swift
//  macdragscrollTests
//
//  Created by Martin Calander on 2026-01-17.
//

import XCTest
@testable import macdragscroll

final class SettingsManagerTests: XCTestCase {
    
    var settings: SettingsManager!
    private var originalHasCompletedWelcome = false
    private var originalAppLanguage: AppLanguage = .system
    
    override func setUp() {
        super.setUp()
        settings = SettingsManager.shared
        originalHasCompletedWelcome = settings.hasCompletedWelcome
        originalAppLanguage = settings.appLanguage
    }
    
    override func tearDown() {
        // Reset excluded apps after each test
        settings.excludedApps = []
        settings.reverseScrollDirection = false
        settings.visualizerSize = 1.0
        settings.visualizerTintStyle = .clear
        settings.liquidGlassIntensity = 1.35
        settings.hasCompletedWelcome = originalHasCompletedWelcome
        settings.appLanguage = originalAppLanguage
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

    func testLanguageSelectionCanBePersisted() {
        settings.appLanguage = .swedish
        XCTAssertEqual(settings.appLanguage, .swedish)

        settings.appLanguage = .system
        XCTAssertEqual(settings.appLanguage, .system)
    }
    
    func testDefaultAccelerationPositive() {
        XCTAssertGreaterThan(settings.acceleration, 0, "Acceleration should be positive")
    }

    func testResetToDefaultsUsesNormalScrollDirection() {
        settings.reverseScrollDirection = true
        settings.visualizerSize = 1.4
        settings.visualizerTintStyle = .aqua
        settings.liquidGlassIntensity = 1.9

        settings.resetToDefaults()

        XCTAssertFalse(settings.reverseScrollDirection, "Default drag scroll direction should not be reversed")
        XCTAssertEqual(settings.visualizerSize, 1.0, accuracy: 0.001)
        XCTAssertEqual(settings.visualizerTintStyle, .clear)
        XCTAssertEqual(settings.liquidGlassIntensity, 1.35, accuracy: 0.001)
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
    
    // MARK: - Settings Persistence Tests
    
    func testExcludedAppsMultipleEntries() {
        let apps = ["com.app1.test", "com.app2.test", "com.app3.test"]
        settings.excludedApps = apps
        
        XCTAssertEqual(settings.excludedApps.count, 3, "Should store all excluded apps")
        for app in apps {
            XCTAssertTrue(settings.isAppExcluded(bundleIdentifier: app), "\(app) should be excluded")
        }
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
