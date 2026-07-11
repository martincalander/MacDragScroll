//
//  PersistentPreferences.swift
//  macdragscroll
//
//  Created by Martin Calander on 2026-07-09.
//

import Foundation

nonisolated private func cleanupPersistentPreferencesTestStorage() {
    let domainIdentifier = "com.martincalander.macdragscroll.tests.\(ProcessInfo.processInfo.processIdentifier)"
    UserDefaults.standard.removePersistentDomain(forName: domainIdentifier)
    UserDefaults.standard.synchronize()

    if let testDefaults = UserDefaults(suiteName: domainIdentifier) {
        testDefaults.removePersistentDomain(forName: domainIdentifier)
        testDefaults.synchronize()
    }

    let preferencesFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Preferences/\(domainIdentifier).plist")
    try? FileManager.default.removeItem(at: preferencesFile)
    try? FileManager.default.removeItem(
        at: FileManager.default.temporaryDirectory
            .appendingPathComponent(domainIdentifier, isDirectory: true)
    )
}

enum PersistentPreferences {
    static let domainIdentifier = "com.martincalander.macdragscroll"
    static let storageDomainIdentifier: String = {
        if isRunningUnitTests {
            return "\(domainIdentifier).tests.\(ProcessInfo.processInfo.processIdentifier)"
        }

        #if DEBUG
        return "\(domainIdentifier).development"
        #else
        return domainIdentifier
        #endif
    }()
    static let legacyAppSettingsKey = "MacDragScroll.AppSettings"
    private static let backupSchemaVersionKey = "_MacDragScrollBackupSchemaVersion"
    private static let backupUpdatedAtKey = "_MacDragScrollBackupUpdatedAt"
    private static let backupWriteDelay: TimeInterval = 0.25
    private static var pendingBackupValues: [String: Any] = [:]
    private static var backupWriteTimer: Timer?
    static let legacyDomainIdentifiers = [
        "com.local.MacDragScroll",
        "com.martincalander.MacDragScroll",
        "com.martincalander.Mac-Drag-Scroll",
        "macdragscroll",
        "Mac Drag Scroll"
    ]

    static let userDefaults: UserDefaults = {
        _ = testCleanupRegistration
        return UserDefaults(suiteName: storageDomainIdentifier) ?? .standard
    }()

    fileprivate static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static var preferencesFilePath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/\(storageDomainIdentifier).plist")
            .path
    }

    static var backupFileURL: URL {
        applicationSupportDirectory
            .appendingPathComponent("Preferences.plist")
    }

    static var backupFilePath: String {
        backupFileURL.path
    }

    static var migrationDomainIdentifiers: [String] {
        var domains = legacyDomainIdentifiers

        if storageDomainIdentifier != domainIdentifier {
            domains.insert(domainIdentifier, at: 0)
        }

        if let bundleIdentifier = Bundle.main.bundleIdentifier,
           bundleIdentifier != storageDomainIdentifier {
            domains.insert(bundleIdentifier, at: 0)
        }

        return domains.reduce(into: [String]()) { result, domain in
            guard domain != storageDomainIdentifier, !result.contains(domain) else { return }
            result.append(domain)
        }
    }

    @discardableResult
    static func migrateLegacyDomains(allowedKeys: Set<String>) -> Int {
        migrateLegacyDomains(migrationDomainIdentifiers, allowedKeys: allowedKeys)
    }

    @discardableResult
    static func migrateLegacyDomains(_ legacyDomains: [String], allowedKeys: Set<String>) -> Int {
        let domainDefaults = UserDefaults.standard
        var canonicalDomain = domainDefaults.persistentDomain(forName: storageDomainIdentifier) ?? [:]
        var migratedCount = 0

        for legacyDomainIdentifier in legacyDomains where legacyDomainIdentifier != storageDomainIdentifier {
            guard let legacyDomain = domainDefaults.persistentDomain(forName: legacyDomainIdentifier) else {
                continue
            }

            let values = migratableValues(from: legacyDomain, allowedKeys: allowedKeys)
            for (key, value) in values where canonicalDomain[key] == nil {
                canonicalDomain[key] = value
                migratedCount += 1
            }
        }

        guard migratedCount > 0 else { return 0 }

        domainDefaults.setPersistentDomain(canonicalDomain, forName: storageDomainIdentifier)
        domainDefaults.synchronize()
        userDefaults.synchronize()
        refreshBackup(allowedKeys: allowedKeys)
        return migratedCount
    }

    @discardableResult
    static func restoreBackup(allowedKeys: Set<String>) -> Int {
        restoreBackup(from: backupFileURL, allowedKeys: allowedKeys)
    }

    @discardableResult
    static func restoreBackup(from backupFileURL: URL, allowedKeys: Set<String>) -> Int {
        guard let backup = loadBackup(from: backupFileURL) else { return 0 }

        let domainDefaults = UserDefaults.standard
        var canonicalDomain = domainDefaults.persistentDomain(forName: storageDomainIdentifier) ?? [:]
        var restoredCount = 0

        for key in allowedKeys where canonicalDomain[key] == nil {
            guard let value = backup[key],
                  let propertyListValue = normalizedPropertyListValue(value) else {
                continue
            }

            canonicalDomain[key] = propertyListValue
            restoredCount += 1
        }

        guard restoredCount > 0 else { return 0 }

        domainDefaults.setPersistentDomain(canonicalDomain, forName: storageDomainIdentifier)
        domainDefaults.synchronize()
        userDefaults.synchronize()
        return restoredCount
    }

    static func refreshBackup(allowedKeys: Set<String>) {
        refreshBackup(at: backupFileURL, allowedKeys: allowedKeys)
    }

    static func refreshBackup(at backupFileURL: URL, allowedKeys: Set<String>) {
        let canonicalDomain = UserDefaults.standard.persistentDomain(forName: storageDomainIdentifier) ?? [:]
        guard !canonicalDomain.isEmpty else { return }

        var backup = loadBackup(from: backupFileURL) ?? [:]
        var didChange = false

        for key in allowedKeys {
            guard let value = canonicalDomain[key],
                  let propertyListValue = normalizedPropertyListValue(value) else {
                continue
            }

            backup[key] = propertyListValue
            didChange = true
        }

        guard didChange else { return }
        writeBackup(backup, to: backupFileURL)
    }

    static func persist(_ value: Any, forKey key: String) {
        userDefaults.set(value, forKey: key)

        guard let propertyListValue = normalizedPropertyListValue(value) else { return }
        pendingBackupValues[key] = propertyListValue
        scheduleBackupWrite()
    }

    static func flushPendingWrites() {
        backupWriteTimer?.invalidate()
        backupWriteTimer = nil
        userDefaults.synchronize()

        guard !pendingBackupValues.isEmpty else { return }

        var backup = loadBackup(from: backupFileURL) ?? [:]
        for (key, value) in pendingBackupValues {
            backup[key] = value
        }
        if writeBackup(backup, to: backupFileURL) {
            pendingBackupValues.removeAll()
        }
    }

    private static var applicationSupportDirectory: URL {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)

        if isRunningUnitTests {
            return FileManager.default.temporaryDirectory
                .appendingPathComponent(storageDomainIdentifier, isDirectory: true)
        }

        #if DEBUG
        return baseDirectory
            .appendingPathComponent("Mac Drag Scroll Development", isDirectory: true)
        #else
        return baseDirectory
            .appendingPathComponent("Mac Drag Scroll", isDirectory: true)
        #endif
    }

    private static func scheduleBackupWrite() {
        backupWriteTimer?.invalidate()

        let timer = Timer(timeInterval: backupWriteDelay, repeats: false) { _ in
            MainActor.assumeIsolated {
                flushPendingWrites()
            }
        }
        timer.tolerance = 0.05
        backupWriteTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private static func loadBackup(from backupFileURL: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: backupFileURL),
              let propertyList = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let backup = propertyList as? [String: Any] else {
            return nil
        }

        return backup
    }

    @discardableResult
    private static func writeBackup(_ backup: [String: Any], to backupFileURL: URL) -> Bool {
        var writableBackup = backup
        writableBackup[backupSchemaVersionKey] = 1
        writableBackup[backupUpdatedAtKey] = Date()

        do {
            try FileManager.default.createDirectory(
                at: backupFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let data = try PropertyListSerialization.data(
                fromPropertyList: writableBackup,
                format: .xml,
                options: 0
            )
            try data.write(to: backupFileURL, options: .atomic)
            return true
        } catch {
            NSLog("[MacDragScroll] Failed to write preferences backup: \(error.localizedDescription)")
            return false
        }
    }

    private static func normalizedPropertyListValue(_ value: Any) -> Any? {
        switch value {
        case let value as Bool:
            return value
        case let value as Int:
            return value
        case let value as Double:
            return value
        case let value as Float:
            return Double(value)
        case let value as String:
            return value
        case let value as Data:
            return value
        case let value as Date:
            return value
        case let value as [String]:
            return value
        case let value as NSNumber:
            return value
        default:
            return nil
        }
    }

    private static func migratableValues(from domain: [String: Any], allowedKeys: Set<String>) -> [String: Any] {
        var values = domain.filter { allowedKeys.contains($0.key) }

        guard let legacySettings = legacyAppSettings(from: domain) else {
            return values
        }

        mergeLegacyValue("isEnabled", from: legacySettings, into: &values, allowedKeys: allowedKeys)
        mergeLegacyValue("sensitivity", from: legacySettings, into: &values, allowedKeys: allowedKeys, destinationKey: "scrollSpeed")
        mergeLegacyValue("invertVertical", from: legacySettings, into: &values, allowedKeys: allowedKeys, destinationKey: "reverseScrollDirection")
        mergeLegacyValue("invertHorizontal", from: legacySettings, into: &values, allowedKeys: allowedKeys, destinationKey: "invertHorizontalScroll")
        mergeLegacyValue("excludedBundleIdentifiers", from: legacySettings, into: &values, allowedKeys: allowedKeys, destinationKey: "excludedApps")
        return values
    }

    private static func legacyAppSettings(from domain: [String: Any]) -> [String: Any]? {
        guard let data = domain[legacyAppSettingsKey] as? Data else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func mergeLegacyValue(
        _ sourceKey: String,
        from legacySettings: [String: Any],
        into values: inout [String: Any],
        allowedKeys: Set<String>,
        destinationKey: String? = nil
    ) {
        let key = destinationKey ?? sourceKey
        guard allowedKeys.contains(key), values[key] == nil, let value = legacySettings[sourceKey] else {
            return
        }

        values[key] = value
    }

    private static let testCleanupRegistration: Void = {
        guard isRunningUnitTests else { return }
        atexit(cleanupPersistentPreferencesTestStorage)
    }()
}
