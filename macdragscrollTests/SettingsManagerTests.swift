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
    
    override func setUp() {
        super.setUp()
        settings = SettingsManager.shared
    }
    
    override func tearDown() {
        // Reset excluded apps after each test
        settings.excludedApps = []
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
    
    func testDefaultAccelerationPositive() {
        XCTAssertGreaterThan(settings.acceleration, 0, "Acceleration should be positive")
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
