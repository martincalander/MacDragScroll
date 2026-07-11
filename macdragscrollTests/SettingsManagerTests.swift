//
//  SettingsManagerTests.swift
//  macdragscrollTests
//
//  Created by Martin Calander on 2026-01-17.
//

import AppKit
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
    private var originalExcludedApps: [String] = []
    private var originalScrollSpeed = 2.0
    private var originalDeadZoneRadius = 20.0
    private var originalAcceleration = 1.8
    private var originalOverlayOpacity = 1.0
    private var originalVisualizerSize = 1.0
    private var originalVisualizerTintStyle: VisualizerTintStyle = .clear
    private var originalLiquidGlassIntensity = 1.35
    private var originalReverseScrollDirection = false
    private var originalHorizontalScrollingEnabled = true
    private var originalInvertHorizontalScroll = false
    private var originalKeepCursorInPlace = false
    private var originalTriggerConfig = TriggerConfig.default
    
    override func setUp() {
        super.setUp()
        settings = SettingsManager.shared
        originalHasCompletedWelcome = settings.hasCompletedWelcome
        originalAppLanguage = settings.appLanguage
        originalAppAppearance = settings.appAppearance
        originalShowIndicator = settings.showIndicator
        originalVisualizerAnimationsEnabled = settings.visualizerAnimationsEnabled
        originalKeepRunningInMenuBar = settings.keepRunningInMenuBar
        originalExcludedApps = settings.excludedApps
        originalScrollSpeed = settings.scrollSpeed
        originalDeadZoneRadius = settings.deadZoneRadius
        originalAcceleration = settings.acceleration
        originalOverlayOpacity = settings.overlayOpacity
        originalVisualizerSize = settings.visualizerSize
        originalVisualizerTintStyle = settings.visualizerTintStyle
        originalLiquidGlassIntensity = settings.liquidGlassIntensity
        originalReverseScrollDirection = settings.reverseScrollDirection
        originalHorizontalScrollingEnabled = settings.horizontalScrollingEnabled
        originalInvertHorizontalScroll = settings.invertHorizontalScroll
        originalKeepCursorInPlace = settings.keepCursorInPlace
        originalTriggerConfig = settings.triggerConfig
    }
    
    override func tearDown() {
        settings.excludedApps = originalExcludedApps
        settings.scrollSpeed = originalScrollSpeed
        settings.deadZoneRadius = originalDeadZoneRadius
        settings.acceleration = originalAcceleration
        settings.overlayOpacity = originalOverlayOpacity
        settings.visualizerSize = originalVisualizerSize
        settings.visualizerTintStyle = originalVisualizerTintStyle
        settings.liquidGlassIntensity = originalLiquidGlassIntensity
        settings.reverseScrollDirection = originalReverseScrollDirection
        settings.horizontalScrollingEnabled = originalHorizontalScrollingEnabled
        settings.invertHorizontalScroll = originalInvertHorizontalScroll
        settings.keepCursorInPlace = originalKeepCursorInPlace
        settings.triggerConfig = originalTriggerConfig
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
                .appendingPathComponent("Library/Preferences/\(PersistentPreferences.storageDomainIdentifier).plist")
                .path
        )
        XCTAssertTrue(PersistentPreferences.storageDomainIdentifier.hasPrefix(PersistentPreferences.domainIdentifier))
        XCTAssertTrue(PersistentPreferences.backupFilePath.hasSuffix("Preferences.plist"))
        let probeKey = "persistentPreferencesTestProbe"
        defer {
            PersistentPreferences.userDefaults.removeObject(forKey: probeKey)
            PersistentPreferences.userDefaults.synchronize()
        }

        PersistentPreferences.userDefaults.set("ok", forKey: probeKey)
        PersistentPreferences.userDefaults.synchronize()

        XCTAssertEqual(
            PersistentPreferences.userDefaults.persistentDomain(forName: PersistentPreferences.storageDomainIdentifier)?[probeKey] as? String,
            "ok"
        )
    }

    func testPreferenceBackupRestoresMissingCanonicalValues() throws {
        let defaults = UserDefaults.standard
        let canonicalDomain = PersistentPreferences.storageDomainIdentifier
        let originalCanonicalDomain = defaults.persistentDomain(forName: canonicalDomain)
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacDragScrollPreferenceRestore-\(UUID().uuidString)", isDirectory: true)
        let backupURL = tempDirectory.appendingPathComponent("Preferences.plist")

        defer {
            if let originalCanonicalDomain {
                defaults.setPersistentDomain(originalCanonicalDomain, forName: canonicalDomain)
            } else {
                defaults.removePersistentDomain(forName: canonicalDomain)
            }
            defaults.synchronize()
            PersistentPreferences.userDefaults.synchronize()
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        defaults.removePersistentDomain(forName: canonicalDomain)
        try writePropertyList([
            "scrollSpeed": 4.25,
            "appAppearance": AppAppearance.dark.rawValue,
            "unrelatedPreference": "ignored"
        ], to: backupURL)

        let restoredCount = PersistentPreferences.restoreBackup(
            from: backupURL,
            allowedKeys: ["scrollSpeed", "appAppearance"]
        )

        let restoredDomain = defaults.persistentDomain(forName: canonicalDomain)
        XCTAssertEqual(restoredCount, 2)
        XCTAssertEqual(numberValue(in: restoredDomain, forKey: "scrollSpeed"), 4.25)
        XCTAssertEqual(restoredDomain?["appAppearance"] as? String, AppAppearance.dark.rawValue)
        XCTAssertNil(restoredDomain?["unrelatedPreference"])
    }

    func testPreferenceBackupRefreshMirrorsCanonicalValues() throws {
        let defaults = UserDefaults.standard
        let canonicalDomain = PersistentPreferences.storageDomainIdentifier
        let originalCanonicalDomain = defaults.persistentDomain(forName: canonicalDomain)
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacDragScrollPreferenceBackup-\(UUID().uuidString)", isDirectory: true)
        let backupURL = tempDirectory.appendingPathComponent("Preferences.plist")

        defer {
            if let originalCanonicalDomain {
                defaults.setPersistentDomain(originalCanonicalDomain, forName: canonicalDomain)
            } else {
                defaults.removePersistentDomain(forName: canonicalDomain)
            }
            defaults.synchronize()
            PersistentPreferences.userDefaults.synchronize()
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        defaults.setPersistentDomain([
            "visualizerSize": 0.55,
            "excludedApps": ["com.example.Editor"],
            "unrelatedPreference": "ignored"
        ], forName: canonicalDomain)

        PersistentPreferences.refreshBackup(
            at: backupURL,
            allowedKeys: ["visualizerSize", "excludedApps"]
        )

        let backup = try readPropertyList(from: backupURL)
        XCTAssertEqual(numberValue(in: backup, forKey: "visualizerSize"), 0.55)
        XCTAssertEqual(backup["excludedApps"] as? [String], ["com.example.Editor"])
        XCTAssertNil(backup["unrelatedPreference"])
    }

    func testPendingPreferenceWritesFlushLatestValueToBackup() throws {
        let originalValue = settings.scrollSpeed
        defer {
            settings.scrollSpeed = originalValue
            PersistentPreferences.flushPendingWrites()
        }

        settings.scrollSpeed = 1.0
        settings.scrollSpeed = 4.5
        PersistentPreferences.flushPendingWrites()

        let backup = try readPropertyList(from: PersistentPreferences.backupFileURL)
        XCTAssertEqual(numberValue(in: backup, forKey: "scrollSpeed"), 4.5)
    }

    func testLegacyPreferenceMigrationCopiesMissingKeysWithoutOverwritingCanonicalValues() {
        let defaults = UserDefaults.standard
        let canonicalDomain = PersistentPreferences.storageDomainIdentifier
        let legacyDomain = "com.martincalander.macdragscroll.legacyMigrationTest.\(UUID().uuidString)"
        let originalCanonicalDomain = defaults.persistentDomain(forName: canonicalDomain)

        defer {
            if let originalCanonicalDomain {
                defaults.setPersistentDomain(originalCanonicalDomain, forName: canonicalDomain)
            } else {
                defaults.removePersistentDomain(forName: canonicalDomain)
            }
            defaults.removePersistentDomain(forName: legacyDomain)
            defaults.synchronize()
            PersistentPreferences.userDefaults.synchronize()
        }

        defaults.setPersistentDomain(["scrollSpeed": 4.0], forName: canonicalDomain)
        defaults.setPersistentDomain([
            "scrollSpeed": 1.0,
            "deadZoneRadius": 35.0,
            "unrelatedPreference": "ignored"
        ], forName: legacyDomain)

        let migratedCount = PersistentPreferences.migrateLegacyDomains(
            [legacyDomain],
            allowedKeys: ["scrollSpeed", "deadZoneRadius"]
        )

        let migratedDomain = defaults.persistentDomain(forName: canonicalDomain)
        XCTAssertEqual(migratedCount, 1)
        XCTAssertEqual(numberValue(in: migratedDomain, forKey: "scrollSpeed"), 4.0)
        XCTAssertEqual(numberValue(in: migratedDomain, forKey: "deadZoneRadius"), 35.0)
        XCTAssertNil(migratedDomain?["unrelatedPreference"])
    }

    func testLegacyAppSettingsBlobMigratesToCurrentPreferenceKeys() throws {
        let defaults = UserDefaults.standard
        let canonicalDomain = PersistentPreferences.storageDomainIdentifier
        let legacyDomain = "com.local.MacDragScroll.legacyBlobTest.\(UUID().uuidString)"
        let originalCanonicalDomain = defaults.persistentDomain(forName: canonicalDomain)
        let legacySettings: [String: Any] = [
            "isEnabled": false,
            "sensitivity": 1.25,
            "invertVertical": true,
            "invertHorizontal": true,
            "excludedBundleIdentifiers": ["com.example.Editor"]
        ]
        let legacyData = try JSONSerialization.data(withJSONObject: legacySettings)

        defer {
            if let originalCanonicalDomain {
                defaults.setPersistentDomain(originalCanonicalDomain, forName: canonicalDomain)
            } else {
                defaults.removePersistentDomain(forName: canonicalDomain)
            }
            defaults.removePersistentDomain(forName: legacyDomain)
            defaults.synchronize()
            PersistentPreferences.userDefaults.synchronize()
        }

        defaults.removePersistentDomain(forName: canonicalDomain)
        defaults.setPersistentDomain([PersistentPreferences.legacyAppSettingsKey: legacyData], forName: legacyDomain)

        let migratedCount = PersistentPreferences.migrateLegacyDomains(
            [legacyDomain],
            allowedKeys: [
                "isEnabled",
                "scrollSpeed",
                "reverseScrollDirection",
                "invertHorizontalScroll",
                "excludedApps"
            ]
        )

        let migratedDomain = defaults.persistentDomain(forName: canonicalDomain)
        XCTAssertEqual(migratedCount, 5)
        XCTAssertEqual(migratedDomain?["isEnabled"] as? Bool, false)
        XCTAssertEqual(numberValue(in: migratedDomain, forKey: "scrollSpeed"), 1.25)
        XCTAssertEqual(migratedDomain?["reverseScrollDirection"] as? Bool, true)
        XCTAssertEqual(migratedDomain?["invertHorizontalScroll"] as? Bool, true)
        XCTAssertEqual(migratedDomain?["excludedApps"] as? [String], ["com.example.Editor"])
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

    func testNumericSettingsReplaceNonFiniteValuesWithSafeDefaults() {
        settings.scrollSpeed = .nan
        settings.deadZoneRadius = .infinity
        settings.acceleration = -.infinity
        settings.overlayOpacity = .nan
        settings.visualizerSize = .infinity
        settings.liquidGlassIntensity = -.infinity

        XCTAssertEqual(settings.scrollSpeed, 2.0, accuracy: 0.001)
        XCTAssertEqual(settings.deadZoneRadius, 20.0, accuracy: 0.001)
        XCTAssertEqual(settings.acceleration, 1.8, accuracy: 0.001)
        XCTAssertEqual(settings.overlayOpacity, 1.0, accuracy: 0.001)
        XCTAssertEqual(settings.visualizerSize, 1.0, accuracy: 0.001)
        XCTAssertEqual(settings.liquidGlassIntensity, 1.35, accuracy: 0.001)
    }

    func testNumericNormalizationRejectsNonFiniteValuesAndClampsFiniteValues() {
        let range = 1.0...5.0

        XCTAssertEqual(SettingsManager.normalizedDouble(.nan, defaultValue: 2.5, range: range), 2.5)
        XCTAssertEqual(SettingsManager.normalizedDouble(.infinity, defaultValue: 2.5, range: range), 2.5)
        XCTAssertEqual(SettingsManager.normalizedDouble(-.infinity, defaultValue: 2.5, range: range), 2.5)
        XCTAssertEqual(SettingsManager.normalizedDouble(-10, defaultValue: 2.5, range: range), 1.0)
        XCTAssertEqual(SettingsManager.normalizedDouble(10, defaultValue: 2.5, range: range), 5.0)
        XCTAssertEqual(SettingsManager.normalizedDouble(3, defaultValue: 2.5, range: range), 3.0)
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

    func testKeepCursorInPlaceIsOffByDefaultAndCanBePersisted() {
        settings.keepCursorInPlace = true
        XCTAssertTrue(settings.keepCursorInPlace)

        settings.resetToDefaults()
        XCTAssertFalse(settings.keepCursorInPlace)
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

    func testAllBundledTranslationsPreserveFormatSpecifiers() {
        guard let englishStrings = localizationStrings(for: "en") else {
            return XCTFail("Expected English localization to be bundled")
        }

        for language in AppLanguage.allCases {
            guard let code = language.lprojCode, code != "en" else { continue }
            guard let translatedStrings = localizationStrings(for: code) else {
                XCTFail("Expected localization bundle for \(code)")
                continue
            }

            for (key, englishValue) in englishStrings {
                guard let translatedValue = translatedStrings[key] else { continue }
                XCTAssertEqual(
                    formatArgumentTypes(in: translatedValue),
                    formatArgumentTypes(in: englishValue),
                    "\(code).lproj key \(key) must preserve its format specifiers"
                )
            }
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
        #if DEBUG
        XCTAssertEqual(appBundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "Mac Drag Scroll Dev")
        XCTAssertEqual(appBundle.bundleIdentifier, "com.martincalander.macdragscroll.development")
        #else
        XCTAssertEqual(appBundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "Mac Drag Scroll")
        XCTAssertEqual(appBundle.bundleIdentifier, "com.martincalander.macdragscroll")
        #endif
    }

    func testAppBundleVersionMetadataUsesStableReleaseValues() {
        let appBundle = Bundle(for: AppDelegate.self)

        XCTAssertEqual(appBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String, "1.2.0")
        XCTAssertEqual(appBundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String, "120")
        XCTAssertEqual(AppDelegate.appVersion, "1.2.0")
        XCTAssertEqual(AppDelegate.appBuild, "120")
    }

    func testAppBundleSupportsMacOS14AndLater() {
        let appBundle = Bundle(for: AppDelegate.self)

        XCTAssertEqual(appBundle.object(forInfoDictionaryKey: "LSMinimumSystemVersion") as? String, "14.0")
    }

    func testBundledIdentityAssetsResolveAndGitHubMarkKeepsOfficialProportions() throws {
        let appBundle = Bundle(for: AppDelegate.self)
        let assetNames = ["BrandMark", "DockIconDark", "DockIconLight", "GitHubMark"]

        for assetName in assetNames {
            XCTAssertNotNil(
                appBundle.image(forResource: NSImage.Name(assetName)),
                "Expected bundled identity asset \(assetName)"
            )
        }

        let githubMark = try XCTUnwrap(
            appBundle.image(forResource: NSImage.Name("GitHubMark"))
        )
        XCTAssertEqual(
            githubMark.size.width / githubMark.size.height,
            98.0 / 96.0,
            accuracy: 0.001
        )
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
        XCTAssertEqual(appBundle.object(forInfoDictionaryKey: "SUAutomaticallyUpdate") as? Bool, true)
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

    func testLaunchUpdateCheckRunsWhenAutomaticChecksAreEnabled() {
        XCTAssertTrue(
            UpdateManager.shouldCheckForUpdatesOnLaunch(
                automaticallyChecksForUpdates: true,
                canCheckForUpdates: true,
                sessionInProgress: false,
                status: .upToDate
            )
        )
    }

    func testLaunchUpdateCheckRespectsAutomaticCheckPreference() {
        XCTAssertFalse(
            UpdateManager.shouldCheckForUpdatesOnLaunch(
                automaticallyChecksForUpdates: false,
                canCheckForUpdates: true,
                sessionInProgress: false,
                status: .upToDate
            )
        )
    }

    func testLaunchUpdateCheckDoesNotOverlapAnotherCheck() {
        XCTAssertFalse(
            UpdateManager.shouldCheckForUpdatesOnLaunch(
                automaticallyChecksForUpdates: true,
                canCheckForUpdates: true,
                sessionInProgress: true,
                status: .upToDate
            )
        )
        XCTAssertFalse(
            UpdateManager.shouldCheckForUpdatesOnLaunch(
                automaticallyChecksForUpdates: true,
                canCheckForUpdates: true,
                sessionInProgress: false,
                status: .checking
            )
        )
    }

    func testLaunchUpdateCheckDoesNotStartWhenSparkleIsUnavailable() {
        XCTAssertFalse(
            UpdateManager.shouldCheckForUpdatesOnLaunch(
                automaticallyChecksForUpdates: true,
                canCheckForUpdates: false,
                sessionInProgress: false,
                status: .upToDate
            )
        )
    }

    func testVersionHistoryStartsWithCurrentRelease() {
        let latest = UpdateManager.versionHistory.first

        XCTAssertEqual(latest?.version, AppDelegate.appVersion)
        XCTAssertEqual(latest?.build, AppDelegate.appBuild)
        XCTAssertEqual(latest?.releaseDate, "2026-07-11")
        XCTAssertEqual(latest?.isCurrent, true)
        XCTAssertFalse(latest?.changes.isEmpty ?? true)
    }

    func testVersionHistoryKeepsInitialReleaseEntry() {
        let initialRelease = UpdateManager.versionHistory.first { $0.version == "1.0.0" }

        XCTAssertEqual(initialRelease?.build, "100")
        XCTAssertFalse(initialRelease?.changes.isEmpty ?? true)
    }

    func testPermissionStateResetsMonitoringWhenAccessibilityIsMissing() {
        let isTrusted = false
        let state = AppDelegate.PermissionState(
            accessibilityPermissionChecker: { isTrusted },
            accessibilityPermissionRequester: { _ in isTrusted }
        )

        state.setEventMonitoringState(.active)
        state.refresh()

        XCTAssertFalse(state.hasAccessibilityPermission)
        XCTAssertFalse(state.hasRequiredPermissions)
        XCTAssertEqual(state.eventMonitoringState, .waiting)
    }

    func testPermissionStateTreatsAccessibilityAsCompleteSetup() {
        let state = AppDelegate.PermissionState(
            accessibilityPermissionChecker: { true },
            accessibilityPermissionRequester: { _ in true }
        )

        state.setEventMonitoringState(.active)
        state.refresh()

        XCTAssertTrue(state.hasAccessibilityPermission)
        XCTAssertTrue(state.hasRequiredPermissions)
        XCTAssertEqual(state.eventMonitoringState, .active)
    }

    func testPermissionStateRequestsAccessibilityWhenMissing() {
        var accessibilityWasRequested = false
        let state = AppDelegate.PermissionState(
            accessibilityPermissionChecker: { false },
            accessibilityPermissionRequester: { shouldPrompt in
                accessibilityWasRequested = shouldPrompt
                // Accessibility prompting is asynchronous and initially returns false.
                return false
            }
        )

        XCTAssertFalse(state.requestAccessibilityPermission())

        XCTAssertTrue(accessibilityWasRequested)
        XCTAssertFalse(state.hasAccessibilityPermission)
        XCTAssertFalse(state.hasRequiredPermissions)
    }

    func testPermissionStateDoesNotRequestAnythingWhenSetupIsComplete() {
        var requestCount = 0
        let state = AppDelegate.PermissionState(
            accessibilityPermissionChecker: { true },
            accessibilityPermissionRequester: { _ in
                requestCount += 1
                return true
            }
        )

        XCTAssertTrue(state.requestAccessibilityPermission())
        XCTAssertEqual(requestCount, 0)
    }

    func testPermissionStatePreservesFailedMonitoringStateWhileTrusted() {
        let state = AppDelegate.PermissionState(
            accessibilityPermissionChecker: { true },
            accessibilityPermissionRequester: { _ in true }
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
        settings.keepCursorInPlace = true
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
        XCTAssertFalse(settings.keepCursorInPlace, "Cursor holding should be opt-in")
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

    func testSettingsTabTransitionDirectionFollowsSidebarOrder() {
        XCTAssertEqual(SettingsTab.transitionVerticalDirection(from: .general, to: .visualizer), -1)
        XCTAssertEqual(SettingsTab.transitionVerticalDirection(from: .updates, to: .apps), 1)
        XCTAssertEqual(SettingsTab.transitionVerticalDirection(from: .about, to: .general), 1)
        XCTAssertEqual(SettingsTab.transitionVerticalDirection(from: .scrolling, to: .scrolling), 0)
    }

    func testCrashReportFileNameIsStableAndSanitized() {
        let date = Date(timeIntervalSince1970: 1_767_817_200)

        let fileName = CrashHandler.crashReportFileName(kind: "SIG/SEGV:Bad Value", date: date, processID: 42)

        XCTAssertTrue(fileName.hasPrefix("MacDragScroll-Crash-"))
        XCTAssertTrue(fileName.hasSuffix("-SIG-SEGV-Bad-Value-42.log"))
        XCTAssertFalse(fileName.contains("/"))
        XCTAssertFalse(fileName.contains(":"))
    }

    func testCrashReportDiscoveryReturnsNewestSupportedFilesFirst() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let older = directory.appendingPathComponent("older.log")
        let newer = directory.appendingPathComponent("newer.ips")
        let crash = directory.appendingPathComponent("middle.crash")
        let ignored = directory.appendingPathComponent("ignored.txt")

        try "older".write(to: older, atomically: true, encoding: .utf8)
        try "newer".write(to: newer, atomically: true, encoding: .utf8)
        try "middle".write(to: crash, atomically: true, encoding: .utf8)
        try "ignored".write(to: ignored, atomically: true, encoding: .utf8)

        let olderDate = Date(timeIntervalSince1970: 100)
        let crashDate = Date(timeIntervalSince1970: 150)
        let newerDate = Date(timeIntervalSince1970: 200)
        try FileManager.default.setAttributes([.creationDate: olderDate, .modificationDate: olderDate], ofItemAtPath: older.path)
        try FileManager.default.setAttributes([.creationDate: crashDate, .modificationDate: crashDate], ofItemAtPath: crash.path)
        try FileManager.default.setAttributes([.creationDate: newerDate, .modificationDate: newerDate], ofItemAtPath: newer.path)

        let reports = CrashHandler.crashReports(in: directory)

        XCTAssertEqual(reports.map(\.fileName), ["newer.ips", "middle.crash", "older.log"])
    }

    func testSystemDiagnosticReportImportCopiesOnlyMacDragScrollReports() throws {
        let sourceDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let destinationDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: sourceDirectory)
            try? FileManager.default.removeItem(at: destinationDirectory)
        }

        let macCrash = sourceDirectory.appendingPathComponent("Mac Drag Scroll_2026-07-09-010101_Mac.crash")
        let macIps = sourceDirectory.appendingPathComponent("MacDragScroll-2026-07-09.ips")
        let unrelated = sourceDirectory.appendingPathComponent("OtherApp_2026-07-09.crash")
        let unsupported = sourceDirectory.appendingPathComponent("Mac Drag Scroll_2026-07-09.txt")

        try "crash".write(to: macCrash, atomically: true, encoding: .utf8)
        try "ips".write(to: macIps, atomically: true, encoding: .utf8)
        try "other".write(to: unrelated, atomically: true, encoding: .utf8)
        try "text".write(to: unsupported, atomically: true, encoding: .utf8)

        let importedCount = CrashHandler.importSystemDiagnosticReports(
            from: sourceDirectory,
            to: destinationDirectory
        )

        let importedNames = try FileManager.default.contentsOfDirectory(atPath: destinationDirectory.path).sorted()
        XCTAssertEqual(importedCount, 2)
        XCTAssertEqual(importedNames, [
            "Mac Drag Scroll_2026-07-09-010101_Mac.crash",
            "MacDragScroll-2026-07-09.ips"
        ])
    }

    func testSystemDiagnosticReportImportRespectsClearCutoff() throws {
        let sourceDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let destinationDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: sourceDirectory)
            try? FileManager.default.removeItem(at: destinationDirectory)
        }

        let oldReport = sourceDirectory.appendingPathComponent("MacDragScroll-old.ips")
        let newReport = sourceDirectory.appendingPathComponent("MacDragScroll-new.ips")
        try "old".write(to: oldReport, atomically: true, encoding: .utf8)
        try "new".write(to: newReport, atomically: true, encoding: .utf8)

        let oldDate = Date(timeIntervalSince1970: 100)
        let cutoffDate = Date(timeIntervalSince1970: 150)
        let newDate = Date(timeIntervalSince1970: 200)
        try FileManager.default.setAttributes(
            [.creationDate: oldDate, .modificationDate: oldDate],
            ofItemAtPath: oldReport.path
        )
        try FileManager.default.setAttributes(
            [.creationDate: newDate, .modificationDate: newDate],
            ofItemAtPath: newReport.path
        )

        let importedCount = CrashHandler.importSystemDiagnosticReports(
            from: sourceDirectory,
            to: destinationDirectory,
            newerThan: cutoffDate
        )

        XCTAssertEqual(importedCount, 1)
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: destinationDirectory.path),
            ["MacDragScroll-new.ips"]
        )
    }

    func testLegacyCrashReportMigrationMovesOnlySupportedFilesWithoutOverwriting() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourceDirectory = root.appendingPathComponent("MacDragScroll/Crash Reports", isDirectory: true)
        let destinationDirectory = root.appendingPathComponent("Mac Drag Scroll/Crash Reports", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try "legacy".write(
            to: sourceDirectory.appendingPathComponent("legacy.crash"),
            atomically: true,
            encoding: .utf8
        )
        try "keep".write(
            to: sourceDirectory.appendingPathComponent("notes.txt"),
            atomically: true,
            encoding: .utf8
        )
        try "source".write(
            to: sourceDirectory.appendingPathComponent("duplicate.log"),
            atomically: true,
            encoding: .utf8
        )
        try "destination".write(
            to: destinationDirectory.appendingPathComponent("duplicate.log"),
            atomically: true,
            encoding: .utf8
        )

        let migratedCount = CrashHandler.migrateCrashReports(
            from: sourceDirectory,
            to: destinationDirectory
        )

        XCTAssertEqual(migratedCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: destinationDirectory.appendingPathComponent("legacy.crash").path
        ))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: sourceDirectory.appendingPathComponent("notes.txt").path
        ))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: sourceDirectory.appendingPathComponent("duplicate.log").path
        ))
        XCTAssertEqual(
            try String(
                contentsOf: destinationDirectory.appendingPathComponent("duplicate.log"),
                encoding: .utf8
            ),
            "destination"
        )
    }

    func testLegacyCrashReportMigrationRemovesEmptySourceDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourceDirectory = root.appendingPathComponent("legacy", isDirectory: true)
        let destinationDirectory = root.appendingPathComponent("current", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try "report".write(
            to: sourceDirectory.appendingPathComponent("report.ips"),
            atomically: true,
            encoding: .utf8
        )

        XCTAssertEqual(
            CrashHandler.migrateCrashReports(from: sourceDirectory, to: destinationDirectory),
            1
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceDirectory.path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: destinationDirectory.appendingPathComponent("report.ips").path
        ))
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
        localizationStrings(for: lprojCode).map { Set($0.keys) }
    }

    private func localizationStrings(for lprojCode: String) -> [String: String]? {
        guard let path = Bundle.main.path(forResource: lprojCode, ofType: "lproj") else {
            return nil
        }

        return NSDictionary(
            contentsOfFile: (path as NSString).appendingPathComponent("Localizable.strings")
        ) as? [String: String]
    }

    private func formatArgumentTypes(in value: String) -> [String] {
        let pattern = #"%(?:\d+\$)?[-+ #0]*(?:\d+|\*)?(?:\.\d+|\.\*)?(?:hh|h|ll|l|q|z|t|j)?[@diuoxXfFeEgGaAcCsSp]"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(value.startIndex..., in: value)

        return expression.matches(in: value, range: range).compactMap { match in
            Range(match.range, in: value).flatMap { value[$0].last.map(String.init) }
        }.sorted()
    }

    private func numberValue(in domain: [String: Any]?, forKey key: String) -> Double? {
        if let number = domain?[key] as? NSNumber {
            return number.doubleValue
        }
        if let double = domain?[key] as? Double {
            return double
        }
        return nil
    }

    private func writePropertyList(_ propertyList: [String: Any], to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data = try PropertyListSerialization.data(
            fromPropertyList: propertyList,
            format: .xml,
            options: 0
        )
        try data.write(to: url, options: .atomic)
    }

    private func readPropertyList(from url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let propertyList = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try XCTUnwrap(propertyList as? [String: Any])
    }
}

final class TriggerConfigTests: XCTestCase {

    func testDefaultTriggerMatchesMiddleClickWithoutModifiers() {
        let config = TriggerConfig.default

        XCTAssertTrue(config.matches(button: 2, modifiers: []))
        XCTAssertFalse(config.matches(button: 1, modifiers: []))
        XCTAssertFalse(config.matches(button: 2, modifiers: [.shift]))
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

    func testCapturedPrimaryAndSecondaryButtonsReceiveSafeModifier() {
        let leftClick = TriggerConfig.captured(button: 0, modifiers: [])
        let rightClick = TriggerConfig.captured(button: 1, modifiers: [])
        let middleClick = TriggerConfig.captured(button: 2, modifiers: [])

        XCTAssertTrue(leftClick.requiresCommand)
        XCTAssertTrue(rightClick.requiresCommand)
        XCTAssertFalse(middleClick.hasModifiers)
        XCTAssertTrue(leftClick.matches(button: 0, modifiers: [.command]))
        XCTAssertTrue(rightClick.matches(button: 1, modifiers: [.command]))
        XCTAssertTrue(middleClick.matches(button: 2, modifiers: []))
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
        XCTAssertFalse(config.matches(button: 2, modifiers: [.command, .option, .shift]))
        XCTAssertTrue(config.modifiersStillHeld([.command, .option, .shift]))
        XCTAssertFalse(config.modifiersStillHeld([.option]))
    }
}

final class InstalledAppDiscoveryTests: XCTestCase {
    func testDiscoveryDeduplicatesBundleIdentifiersAndPrioritizesFrontmostApp() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacDragScrollInstalledApps-\(UUID().uuidString)", isDirectory: true)
        let firstDirectory = root.appendingPathComponent("First", isDirectory: true)
        let secondDirectory = root.appendingPathComponent("Second", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try createApp(named: "Alpha.app", bundleId: "com.example.alpha", in: firstDirectory)
        try createApp(named: "Duplicate.app", bundleId: "com.example.duplicate", in: firstDirectory)
        try createApp(named: "Duplicate Copy.app", bundleId: "com.example.duplicate", in: secondDirectory)
        try createApp(named: "Beta.APP", bundleId: "com.example.beta", in: secondDirectory)

        let apps = InstalledAppDiscovery.load(
            frontmostBundleId: "com.example.beta",
            directories: [firstDirectory.path, secondDirectory.path]
        )

        XCTAssertEqual(apps.map(\.bundleId), [
            "com.example.beta",
            "com.example.alpha",
            "com.example.duplicate"
        ])
        XCTAssertEqual(apps.filter { $0.bundleId == "com.example.duplicate" }.count, 1)
        XCTAssertTrue(
            apps.first(where: { $0.bundleId == "com.example.duplicate" })?.path
                .hasPrefix(firstDirectory.path) == true
        )
    }

    private func createApp(named name: String, bundleId: String, in directory: URL) throws {
        let contentsDirectory = directory
            .appendingPathComponent(name, isDirectory: true)
            .appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contentsDirectory, withIntermediateDirectories: true)

        let data = try PropertyListSerialization.data(
            fromPropertyList: ["CFBundleIdentifier": bundleId],
            format: .xml,
            options: 0
        )
        try data.write(to: contentsDirectory.appendingPathComponent("Info.plist"), options: .atomic)
    }
}
