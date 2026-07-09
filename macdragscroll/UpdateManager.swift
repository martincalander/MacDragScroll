//
//  UpdateManager.swift
//  macdragscroll
//
//  Created by OpenAI Codex on 2026-07-08.
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

final class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = UpdateManager()

    static let repositoryURL = URL(string: "https://github.com/martincalander/MacDragScroll")!
    static let websiteURL = URL(string: "https://martincalander.com")!

    private let defaults = PersistentPreferences.userDefaults
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
            guard !isSyncingSparklePreferences, autoUpdateEnabled != oldValue else { return }
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
        autoUpdateEnabled = true
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

        syncPreferencesFromSparkle()
    }

    func checkForUpdatesIfNeeded() {
        syncPreferencesFromSparkle()
    }

    func checkForUpdates() {
        guard !status.isChecking else { return }
        guard updaterController.updater.canCheckForUpdates else {
            let message = "Sparkle cannot start an update check right now."
            status = .failed(message: message)
            appendHistory(message)
            return
        }

        status = .checking
        lastChecked = Date()
        defaults.set(lastChecked, forKey: lastCheckedKey)
        appendHistory("Started update check.")
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
        lastChecked = Date()
        defaults.set(lastChecked, forKey: lastCheckedKey)

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

    private func markUpToDate() {
        lastChecked = Date()
        defaults.set(lastChecked, forKey: lastCheckedKey)
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
            defaults.set(data, forKey: historyKey)
        }
    }

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
