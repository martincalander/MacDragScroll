//
//  CrashHandler.swift
//  macdragscroll
//
//  Created by Martin Calander on 2026-01-17.
//

import Foundation
import AppKit
import Combine

// MARK: - Crash Handler

final class CrashHandler: ObservableObject {
    struct CrashReport: Identifiable, Equatable {
        let url: URL
        let createdAt: Date

        var id: String { url.path }
        var fileName: String { url.lastPathComponent }
    }

    static let shared = CrashHandler()
    
    // Cache version at init time so it's available during crash
    static var appVersion: String = "Unknown"
    static var appBuild: String = "Unknown"
    
    @Published private(set) var crashReports: [CrashReport] = []

    let crashReportDirectory: URL

    private let legacyCrashReportDirectory: URL
    private let legacyCrashLogPaths: [URL]
    private let systemDiagnosticReportsDirectory: URL
    private static let supportedCrashReportExtensions: Set<String> = ["log", "crash", "ips"]
    private static let lastCrashReportClearDateKey = "lastCrashReportClearDate"
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        let appFolder = appSupport.appendingPathComponent("Mac Drag Scroll", isDirectory: true)
        let legacyAppFolder = appSupport.appendingPathComponent("MacDragScroll", isDirectory: true)
        let libraryFolder = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library", isDirectory: true)
        crashReportDirectory = appFolder.appendingPathComponent("Crash Reports", isDirectory: true)
        legacyCrashReportDirectory = legacyAppFolder.appendingPathComponent("Crash Reports", isDirectory: true)
        legacyCrashLogPaths = [
            appFolder.appendingPathComponent("crash.log"),
            legacyAppFolder.appendingPathComponent("crash.log")
        ]
        systemDiagnosticReportsDirectory = libraryFolder
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("DiagnosticReports", isDirectory: true)
        
        ensureCrashReportDirectory()
    }

    var hasCrashReports: Bool {
        !crashReports.isEmpty
    }

    var crashReportCount: Int {
        crashReports.count
    }

    var latestCrashReport: CrashReport? {
        crashReports.first
    }
    
    // MARK: - Setup
    
    func setup() {
        setupExceptionHandler()
        migrateLegacyCrashReportsIfNeeded()
        migrateLegacyCrashLogIfNeeded()
        importSystemDiagnosticReportsIfNeeded()
        refreshCrashReports()
    }
    
    // MARK: - Exception Handler
    
    private func setupExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            CrashHandler.shared.handleException(exception)
        }
    }
    
    private func handleException(_ exception: NSException) {
        let crashInfo = """
        Mac Drag Scroll Crash Report
        ============================
        Date: \(Date())
        Version: \(CrashHandler.appVersion)
        Build: \(CrashHandler.appBuild)
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Process: \(ProcessInfo.processInfo.processName) (\(ProcessInfo.processInfo.processIdentifier))
        Exception: \(exception.name.rawValue)
        Reason: \(exception.reason ?? "Unknown")
        
        User Info:
        \(exception.userInfo?.description ?? "None")
        
        Stack Trace:
        \(exception.callStackSymbols.joined(separator: "\n"))
        """
        
        // Write crash log
        writeCrashReport(crashInfo, kind: exception.name.rawValue)
        refreshCrashReports()
    }
    
    // MARK: - Crash Reports

    @discardableResult
    func refreshCrashReports() -> [CrashReport] {
        let reports = Self.crashReports(in: crashReportDirectory)

        if Thread.isMainThread {
            crashReports = reports
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.crashReports = reports
            }
        }

        return reports
    }

    func openCrashReportsFolder() {
        ensureCrashReportDirectory()
        NSWorkspace.shared.open(crashReportDirectory)
    }

    func revealLatestCrashReport() {
        guard let latestCrashReport = refreshCrashReports().first else {
            openCrashReportsFolder()
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([latestCrashReport.url])
    }

    @discardableResult
    func copyLatestCrashReportToClipboard() -> Bool {
        guard let latestCrashReport = refreshCrashReports().first,
              let report = try? String(contentsOf: latestCrashReport.url, encoding: .utf8) else {
            return false
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(report, forType: .string)
        return true
    }

    func clearCrashReports() {
        Self.crashReports(in: crashReportDirectory).forEach { report in
            try? FileManager.default.removeItem(at: report.url)
        }
        PersistentPreferences.userDefaults.set(Date(), forKey: Self.lastCrashReportClearDateKey)
        PersistentPreferences.userDefaults.synchronize()
        refreshCrashReports()
    }

    static func crashReports(in directory: URL, fileManager: FileManager = .default) -> [CrashReport] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls
            .filter { supportedCrashReportExtensions.contains($0.pathExtension.lowercased()) }
            .compactMap { url -> CrashReport? in
                guard isRegularFile(url: url, fileManager: fileManager) else { return nil }
                return CrashReport(url: url, createdAt: fileDate(url: url, fileManager: fileManager))
            }
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.fileName > rhs.fileName
                }
                return lhs.createdAt > rhs.createdAt
            }
    }

    static func crashReportFileName(kind: String, date: Date, processID: Int32 = ProcessInfo.processInfo.processIdentifier) -> String {
        let timestamp = ISO8601DateFormatter()
            .string(from: date)
            .replacingOccurrences(of: ":", with: "-")
        let safeKind = sanitizedCrashReportKind(kind)

        return "MacDragScroll-Crash-\(timestamp)-\(safeKind)-\(processID).log"
    }

    private func writeCrashReport(_ crashInfo: String, kind: String) {
        ensureCrashReportDirectory()

        let url = crashReportDirectory.appendingPathComponent(Self.crashReportFileName(kind: kind, date: Date()))
        try? crashInfo.write(to: url, atomically: true, encoding: .utf8)
    }

    private func migrateLegacyCrashReportsIfNeeded() {
        ensureCrashReportDirectory()
        Self.migrateCrashReports(
            from: legacyCrashReportDirectory,
            to: crashReportDirectory
        )
    }

    private func migrateLegacyCrashLogIfNeeded() {
        ensureCrashReportDirectory()

        for (index, legacyCrashLogPath) in legacyCrashLogPaths.enumerated() {
            guard FileManager.default.fileExists(atPath: legacyCrashLogPath.path) else { continue }

            let kind = index == 0 ? "Migrated" : "Migrated-Legacy"
            let migratedURL = crashReportDirectory.appendingPathComponent(
                Self.crashReportFileName(kind: kind, date: Date())
            )

            do {
                try FileManager.default.moveItem(at: legacyCrashLogPath, to: migratedURL)
            } catch {
                guard !FileManager.default.fileExists(atPath: migratedURL.path),
                      let legacyLog = try? String(contentsOf: legacyCrashLogPath, encoding: .utf8) else {
                    continue
                }

                do {
                    try legacyLog.write(to: migratedURL, atomically: true, encoding: .utf8)
                    try FileManager.default.removeItem(at: legacyCrashLogPath)
                } catch {
                    continue
                }
            }
        }
    }

    @discardableResult
    static func migrateCrashReports(
        from sourceDirectory: URL,
        to destinationDirectory: URL,
        fileManager: FileManager = .default
    ) -> Int {
        guard sourceDirectory.standardizedFileURL != destinationDirectory.standardizedFileURL,
              let urls = try? fileManager.contentsOfDirectory(
                at: sourceDirectory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
              ) else {
            return 0
        }

        try? fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        var migratedCount = 0
        for url in urls where supportedCrashReportExtensions.contains(url.pathExtension.lowercased())
            && isRegularFile(url: url, fileManager: fileManager) {
            let destinationURL = destinationDirectory.appendingPathComponent(url.lastPathComponent)
            guard !fileManager.fileExists(atPath: destinationURL.path) else { continue }

            do {
                try fileManager.moveItem(at: url, to: destinationURL)
                migratedCount += 1
            } catch {
                do {
                    try fileManager.copyItem(at: url, to: destinationURL)
                    try fileManager.removeItem(at: url)
                    migratedCount += 1
                } catch {
                    continue
                }
            }
        }

        if (try? fileManager.contentsOfDirectory(atPath: sourceDirectory.path).isEmpty) == true {
            try? fileManager.removeItem(at: sourceDirectory)
        }

        return migratedCount
    }

    private func importSystemDiagnosticReportsIfNeeded() {
        ensureCrashReportDirectory()
        Self.importSystemDiagnosticReports(
            from: systemDiagnosticReportsDirectory,
            to: crashReportDirectory,
            newerThan: PersistentPreferences.userDefaults.object(
                forKey: Self.lastCrashReportClearDateKey
            ) as? Date
        )
    }

    @discardableResult
    static func importSystemDiagnosticReports(
        from sourceDirectory: URL,
        to destinationDirectory: URL,
        newerThan cutoffDate: Date? = nil,
        fileManager: FileManager = .default
    ) -> Int {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: sourceDirectory,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        try? fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        var importedCount = 0
        for url in urls where isMacDragScrollDiagnosticReport(url)
            && isRegularFile(url: url, fileManager: fileManager)
            && cutoffDate.map({ fileDate(url: url, fileManager: fileManager) > $0 }) != false {
            let destinationURL = destinationDirectory.appendingPathComponent(url.lastPathComponent)
            guard !fileManager.fileExists(atPath: destinationURL.path) else { continue }

            do {
                try fileManager.copyItem(at: url, to: destinationURL)
                importedCount += 1
            } catch {
                continue
            }
        }

        return importedCount
    }

    private func ensureCrashReportDirectory() {
        try? FileManager.default.createDirectory(at: crashReportDirectory, withIntermediateDirectories: true)
    }

    private static func isMacDragScrollDiagnosticReport(_ url: URL) -> Bool {
        guard supportedCrashReportExtensions.contains(url.pathExtension.lowercased()) else {
            return false
        }

        let fileName = url.deletingPathExtension().lastPathComponent.lowercased()
        return fileName.hasPrefix("mac drag scroll")
            || fileName.hasPrefix("macdragscroll")
            || fileName.hasPrefix("mac-drag-scroll")
    }

    private static func sanitizedCrashReportKind(_ kind: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = kind.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let sanitized = String(scalars)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")

        return sanitized.isEmpty ? "Unknown" : sanitized
    }

    private static func isRegularFile(url: URL, fileManager: FileManager) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey]) else {
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && !isDirectory.boolValue
        }

        return values.isRegularFile == true
    }

    private static func fileDate(url: URL, fileManager: FileManager) -> Date {
        if let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey]) {
            return values.creationDate ?? values.contentModificationDate ?? .distantPast
        }

        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        return attributes?[.creationDate] as? Date
            ?? attributes?[.modificationDate] as? Date
            ?? .distantPast
    }
}
