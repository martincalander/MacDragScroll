//
//  UpdateManager.swift
//  macdragscroll
//
//  Created by Martin Calander on 2026-07-08.
//

import AppKit
import Combine
import Foundation
import Sparkle

enum UpdateStatus: Equatable {
    case checking
    case upToDate
    case available(version: String, releaseURL: URL?)
    case failed(message: String)

    var isChecking: Bool {
        if case .checking = self { return true }
        return false
    }

    var menuTitle: String {
        switch self {
        case .checking:
            return localized("update_menu_checking", value: "Checking for Updates...")
        case .upToDate:
            return localized("check_for_update", value: "Check For Update")
        case let .available(version, _):
            let format = localized("update_menu_available", value: "Update Available: %@")
            return String(format: format, version)
        case .failed:
            return localized("check_for_update", value: "Check For Update")
        }
    }

    var statusTitle: String {
        switch self {
        case .checking:
            return localized("update_status_checking", value: "Checking...")
        case .upToDate:
            return localized("update_status_up_to_date", value: "Up to Date")
        case let .available(version, _):
            let format = localized("update_status_available", value: "Update Available: %@")
            return String(format: format, version)
        case .failed:
            return localized("update_status_unable", value: "Unable to Check")
        }
    }

    var statusDetail: String {
        switch self {
        case .checking:
            return localized("update_detail_checking", value: "Contacting the Sparkle update feed.")
        case .upToDate:
            return localized("update_detail_up_to_date", value: "You are running the newest known version.")
        case let .available(version, _):
            let format = localized("update_detail_available", value: "Version %@ is available as a verified app update.")
            return String(format: format, version)
        case let .failed(message):
            return message
        }
    }

    var isMenuActionEnabled: Bool {
        !isChecking
    }

    private func localized(_ key: String, value: String) -> String {
        AppLocalization.shared.localizedString(key, value: value, comment: key)
    }
}

struct UpdateHistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let message: String

    init(id: UUID = UUID(), date: Date = Date(), message: String) {
        self.id = id
        self.date = date
        self.message = message
    }
}

struct VersionHistoryEntry: Identifiable, Equatable {
    let version: String
    let build: String
    let releaseDate: String
    let changes: [String]

    var id: String { "\(version)-\(build)" }

    var isCurrent: Bool {
        version == AppDelegate.appVersion && build == AppDelegate.appBuild
    }
}

final class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = UpdateManager()

    static let repositoryURL = URL(string: "https://github.com/martincalander/MacDragScroll")!
    static let websiteURL = URL(string: "https://martincalander.com")!
    static let versionHistory: [VersionHistoryEntry] = [
        VersionHistoryEntry(
            version: "1.0.6",
            build: "106",
            releaseDate: "2026-07-10",
            changes: [
                "Drag scrolling now activates only for the exact configured modifier chord, preserving modified mouse shortcuts."
            ]
        ),
        VersionHistoryEntry(
            version: "1.0.5",
            build: "105",
            releaseDate: "2026-07-10",
            changes: [
                "Crash reports now use the documented Application Support folder and migrate safely from the legacy path."
            ]
        ),
        VersionHistoryEntry(
            version: "1.0.4",
            build: "104",
            releaseDate: "2026-07-09",
            changes: [
                "Mac Drag Scroll now checks quietly for updates whenever it launches and Auto Update is enabled."
            ]
        ),
        VersionHistoryEntry(
            version: "1.0.3",
            build: "103",
            releaseDate: "2026-07-09",
            changes: [
                "Added directional Settings tab transitions with subtle vertical movement.",
                "Changed the About logo into an in-place squishy interaction instead of a draggable export item.",
                "Fixed closing Settings with the red window button leaving Mac Drag Scroll visible in the Dock."
            ]
        ),
        VersionHistoryEntry(
            version: "1.0.2",
            build: "102",
            releaseDate: "2026-07-09",
            changes: [
                "Added a proper Version History view in Updates so releases are easier to scan.",
                "Moved diagnostic Sparkle update events behind a Show Update Log control.",
                "Added tests to keep the bundled version history aligned with the current app build."
            ]
        ),
        VersionHistoryEntry(
            version: "1.0.1",
            build: "101",
            releaseDate: "2026-07-09",
            changes: [
                "Added a General setting to keep Mac Drag Scroll running in the menu bar after closing Settings.",
                "Made Accessibility and Input Monitoring setup clearer, including app reveal and restart repair actions.",
                "Fixed up-to-date Sparkle checks being shown as update failures."
            ]
        ),
        VersionHistoryEntry(
            version: "1.0.0",
            build: "100",
            releaseDate: "2026-07-09",
            changes: [
                "Initial public release with Windows-style middle-mouse drag scrolling for external mice.",
                "Added the Liquid Glass visualizer, menu bar controls, ignored apps, permissions, updates, and About sections.",
                "Added Sparkle-based updates backed by GitHub Releases."
            ]
        )
    ]

    private static let migratablePreferenceKeys: Set<String> = [
        "autoUpdateEnabled",
        "lastUpdateCheckDate",
        "updateHistory",
        "SUEnableAutomaticChecks",
        "SUAutomaticallyUpdate",
        "SUHasLaunchedBefore",
        "SULastCheckTime"
    ]

    private let defaults = PersistentPreferences.userDefaults
    private let autoUpdateEnabledKey = "autoUpdateEnabled"
    private let lastCheckedKey = "lastUpdateCheckDate"
    private let historyKey = "updateHistory"
    private var isSyncingSparklePreferences = false

    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: !Self.isRunningUnitTests,
        updaterDelegate: self,
        userDriverDelegate: nil
    )

    @Published var autoUpdateEnabled: Bool {
        didSet {
            guard autoUpdateEnabled != oldValue else { return }
            persist(autoUpdateEnabled, forKey: autoUpdateEnabledKey)
            guard !isSyncingSparklePreferences else { return }
            updaterController.updater.automaticallyChecksForUpdates = autoUpdateEnabled
            appendHistory(autoUpdateEnabled ? "Automatic update checks enabled." : "Automatic update checks disabled.")
        }
    }

    @Published private(set) var status: UpdateStatus = .upToDate
    @Published private(set) var lastChecked: Date?
    @Published private(set) var history: [UpdateHistoryEntry]

    var currentVersion: String {
        AppDelegate.appVersion
    }

    var currentBuild: String {
        AppDelegate.appBuild
    }

    var currentVersionDisplay: String {
        "\(currentVersion) (\(currentBuild))"
    }

    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates && !status.isChecking
    }

    override private init() {
        PersistentPreferences.restoreBackup(allowedKeys: Self.migratablePreferenceKeys)
        PersistentPreferences.migrateLegacyDomains(allowedKeys: Self.migratablePreferenceKeys)
        PersistentPreferences.refreshBackup(allowedKeys: Self.migratablePreferenceKeys)

        autoUpdateEnabled = Self.autoUpdatePreference(from: defaults)
        lastChecked = defaults.object(forKey: lastCheckedKey) as? Date

        if let data = defaults.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([UpdateHistoryEntry].self, from: data) {
            history = decoded
        } else {
            history = [
                UpdateHistoryEntry(message: "Update history starts with this build.")
            ]
        }

        super.init()

        updaterController.updater.automaticallyChecksForUpdates = autoUpdateEnabled
        persist(autoUpdateEnabled, forKey: autoUpdateEnabledKey)
        syncPreferencesFromSparkle()
    }

    func checkForUpdatesOnLaunch() {
        syncPreferencesFromSparkle()

        let updater = updaterController.updater
        guard Self.shouldCheckForUpdatesOnLaunch(
            automaticallyChecksForUpdates: updater.automaticallyChecksForUpdates,
            canCheckForUpdates: updater.canCheckForUpdates,
            sessionInProgress: updater.sessionInProgress,
            status: status
        ) else { return }

        beginUpdateCheck(historyMessage: "Started automatic update check.")
        updater.checkForUpdatesInBackground()
    }

    func checkForUpdates() {
        guard !status.isChecking else { return }
        guard updaterController.updater.canCheckForUpdates else {
            let message = "Sparkle cannot start an update check right now."
            status = .failed(message: message)
            appendHistory(message)
            return
        }

        beginUpdateCheck(historyMessage: "Started manual update check.")
        updaterController.checkForUpdates(nil)
    }

    func openReleasePage() {
        if case let .available(_, releaseURL) = status, let releaseURL {
            NSWorkspace.shared.open(releaseURL)
        } else {
            NSWorkspace.shared.open(Self.repositoryURL)
        }
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let now = Date()
        lastChecked = now
        persist(now, forKey: lastCheckedKey)

        let version = item.displayVersionString
        status = .available(version: version, releaseURL: item.infoURL ?? item.fileURL)
        appendHistory("Found update \(version).")
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        markUpToDate()
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        appendHistory("Installing update \(item.displayVersionString).")
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        if Self.isNoUpdateError(error) {
            markUpToDate()
            return
        }

        let message = "Update failed: \(error.localizedDescription)"
        status = .failed(message: message)
        appendHistory(message)
    }

    static func isNoUpdateError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == SUSparkleErrorDomain && nsError.code == Int(SUError.noUpdateError.rawValue)
    }

    static func shouldCheckForUpdatesOnLaunch(
        automaticallyChecksForUpdates: Bool,
        canCheckForUpdates: Bool,
        sessionInProgress: Bool,
        status: UpdateStatus
    ) -> Bool {
        automaticallyChecksForUpdates && canCheckForUpdates && !sessionInProgress && !status.isChecking
    }

    private func beginUpdateCheck(historyMessage: String) {
        status = .checking
        let now = Date()
        lastChecked = now
        persist(now, forKey: lastCheckedKey)
        appendHistory(historyMessage)
    }

    private func markUpToDate() {
        let now = Date()
        lastChecked = now
        persist(now, forKey: lastCheckedKey)
        status = .upToDate
        appendHistory("Checked for updates. \(currentVersionDisplay) is up to date.")
    }

    private func syncPreferencesFromSparkle() {
        isSyncingSparklePreferences = true
        autoUpdateEnabled = updaterController.updater.automaticallyChecksForUpdates
        isSyncingSparklePreferences = false
    }

    private func appendHistory(_ message: String) {
        history.insert(UpdateHistoryEntry(message: message), at: 0)
        if history.count > 8 {
            history = Array(history.prefix(8))
        }

        if let data = try? JSONEncoder().encode(history) {
            persist(data, forKey: historyKey)
        }
    }

    private static func autoUpdatePreference(from defaults: UserDefaults) -> Bool {
        if let appPreference = boolValue(from: defaults, forKey: "autoUpdateEnabled") {
            return appPreference
        }
        if let sparklePreference = boolValue(from: defaults, forKey: "SUEnableAutomaticChecks") {
            return sparklePreference
        }
        if let sparklePreference = boolValue(from: defaults, forKey: "SUAutomaticallyUpdate") {
            return sparklePreference
        }
        return true
    }

    private static func boolValue(from defaults: UserDefaults, forKey key: String) -> Bool? {
        let value = defaults.object(forKey: key)
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        return nil
    }

    private func persist(_ value: Any, forKey key: String) {
        PersistentPreferences.persist(value, forKey: key)
    }

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
