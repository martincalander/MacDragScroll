//
//  UpdateManager.swift
//  macdragscroll
//
//  Created by OpenAI Codex on 2026-07-08.
//

import AppKit
import Combine
import Foundation

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
            return localized("update_menu_up_to_date", value: "Up to Date")
        case let .available(version, _):
            let format = localized("update_menu_available", value: "Update Available: %@")
            return String(format: format, version)
        case .failed:
            return localized("update_menu_unavailable", value: "Update Check Unavailable")
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
            return localized("update_detail_checking", value: "Contacting GitHub Releases.")
        case .upToDate:
            return localized("update_detail_up_to_date", value: "You are running the newest known version.")
        case let .available(version, _):
            let format = localized("update_detail_available", value: "Version %@ is available from GitHub Releases.")
            return String(format: format, version)
        case let .failed(message):
            return message
        }
    }

    var isMenuActionEnabled: Bool {
        if case .available = self { return true }
        return false
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

final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    static let repositoryURL = URL(string: "https://github.com/martincalander/MacDragScroll")!
    static let websiteURL = URL(string: "https://martincalander.com")!

    private let latestReleaseURL = URL(string: "https://api.github.com/repos/martincalander/MacDragScroll/releases/latest")!
    private let defaults = UserDefaults.standard
    private let autoUpdateEnabledKey = "autoUpdateEnabled"
    private let lastCheckedKey = "lastUpdateCheckDate"
    private let historyKey = "updateHistory"

    @Published var autoUpdateEnabled: Bool {
        didSet {
            defaults.set(autoUpdateEnabled, forKey: autoUpdateEnabledKey)
            if autoUpdateEnabled {
                checkForUpdatesIfNeeded()
            }
        }
    }

    @Published private(set) var status: UpdateStatus = .upToDate
    @Published private(set) var lastChecked: Date?
    @Published private(set) var history: [UpdateHistoryEntry]

    var currentVersion: String {
        AppDelegate.appVersion
    }

    private init() {
        defaults.register(defaults: [autoUpdateEnabledKey: true])
        autoUpdateEnabled = defaults.bool(forKey: autoUpdateEnabledKey)
        lastChecked = defaults.object(forKey: lastCheckedKey) as? Date

        if let data = defaults.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([UpdateHistoryEntry].self, from: data) {
            history = decoded
        } else {
            history = [
                UpdateHistoryEntry(message: "Update history starts with this build.")
            ]
        }
    }

    func checkForUpdatesIfNeeded() {
        guard autoUpdateEnabled else { return }
        checkForUpdates()
    }

    func checkForUpdates() {
        guard !status.isChecking else { return }

        status = .checking

        var request = URLRequest(url: latestReleaseURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
        request.setValue("MacDragScroll/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.finishCheck(data: data, response: response, error: error)
            }
        }.resume()
    }

    func openReleasePage() {
        if case let .available(_, releaseURL) = status, let releaseURL {
            NSWorkspace.shared.open(releaseURL)
        } else {
            NSWorkspace.shared.open(Self.repositoryURL)
        }
    }

    private func finishCheck(data: Data?, response: URLResponse?, error: Error?) {
        lastChecked = Date()
        defaults.set(lastChecked, forKey: lastCheckedKey)

        if let error {
            let message = "Update check failed: \(error.localizedDescription)"
            status = .failed(message: message)
            appendHistory(message)
            return
        }

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
            status = .upToDate
            appendHistory("No public GitHub release was found; keeping the current build.")
            return
        }

        guard let data else {
            let message = "Update check failed: no response data."
            status = .failed(message: message)
            appendHistory(message)
            return
        }

        do {
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latestVersion = Self.normalizedVersion(release.tagName)

            if Self.isVersion(latestVersion, newerThan: currentVersion) {
                status = .available(version: latestVersion, releaseURL: release.htmlURL)
                appendHistory("Found update \(latestVersion).")
            } else {
                status = .upToDate
                appendHistory("Checked GitHub Releases. \(currentVersion) is up to date.")
            }
        } catch {
            let message = "Update check failed: \(error.localizedDescription)"
            status = .failed(message: message)
            appendHistory(message)
        }
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

    private static func normalizedVersion(_ version: String) -> String {
        version.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
    }

    private static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        compareVersions(candidate, current) == .orderedDescending
    }

    private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lhsParts = versionParts(lhs)
        let rhsParts = versionParts(rhs)
        let count = max(lhsParts.count, rhsParts.count)

        for index in 0..<count {
            let left = index < lhsParts.count ? lhsParts[index] : 0
            let right = index < rhsParts.count ? rhsParts[index] : 0
            if left < right { return .orderedAscending }
            if left > right { return .orderedDescending }
        }

        return .orderedSame
    }

    private static func versionParts(_ version: String) -> [Int] {
        normalizedVersion(version)
            .split(separator: ".", omittingEmptySubsequences: false)
            .map { component in
                let digits = component.prefix { $0.isNumber }
                return Int(digits) ?? 0
            }
    }

    private struct GitHubRelease: Decodable {
        let tagName: String
        let htmlURL: URL?

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }
}
