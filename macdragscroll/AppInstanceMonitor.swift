//
//  AppInstanceMonitor.swift
//  macdragscroll
//
//  Created by OpenAI Codex on 2026-07-09.
//

import AppKit
import Combine
import Darwin
import Foundation

final class AppInstanceMonitor: ObservableObject {
    static let shared = AppInstanceMonitor()
    static let activationRequestNotification = Notification.Name("com.martincalander.macdragscroll.activatePrimaryInstance")
    static let notificationObject = Bundle.main.bundleIdentifier ?? "com.martincalander.macdragscroll"

    @Published private(set) var duplicateInstanceCount = 0

    private let processIdentifier = ProcessInfo.processInfo.processIdentifier
    private let launchDate = Date()
    private let lockPath: String
    private var lockFileDescriptor: Int32 = -1
    private var refreshTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []

    var hasDuplicateInstances: Bool {
        duplicateInstanceCount > 0
    }

    var totalInstanceCount: Int {
        duplicateInstanceCount + 1
    }

    private init() {
        let lockName = "\(Self.notificationObject).instance.lock"
        lockPath = FileManager.default.temporaryDirectory.appendingPathComponent(lockName).path
    }

    deinit {
        stopMonitoring()
        releasePrimaryInstanceLock()
    }

    @discardableResult
    func claimPrimaryInstance() -> Bool {
        guard !isRunningUnderUnitTests else { return true }

        guard acquirePrimaryInstanceLock() else {
            activateExistingInstanceIfPossible()
            requestPrimaryInstanceActivation()
            return false
        }

        let existingInstances = runningSiblingApplications()
            .filter { app in
                guard let appLaunchDate = app.launchDate else { return true }
                return appLaunchDate < launchDate.addingTimeInterval(-2)
            }

        guard existingInstances.isEmpty else {
            activate(existingInstances[0])
            requestPrimaryInstanceActivation()
            releasePrimaryInstanceLock()
            return false
        }

        return true
    }

    func requestPrimaryInstanceActivation() {
        DistributedNotificationCenter.default().post(
            name: Self.activationRequestNotification,
            object: Self.notificationObject,
            userInfo: nil
        )
    }

    func startMonitoring() {
        guard !isRunningUnderUnitTests else { return }

        refreshDuplicateInstances()

        if refreshTimer == nil {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.refreshDuplicateInstances()
            }
        }

        guard workspaceObservers.isEmpty else { return }

        let notificationCenter = NSWorkspace.shared.notificationCenter
        let launchObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshDuplicateInstances()
        }
        let terminateObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshDuplicateInstances()
        }
        workspaceObservers = [launchObserver, terminateObserver]
    }

    func stopMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil

        let notificationCenter = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers {
            notificationCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()
    }

    func refreshDuplicateInstances() {
        let count = runningSiblingApplications().count
        guard duplicateInstanceCount != count else { return }
        duplicateInstanceCount = count
    }

    private func acquirePrimaryInstanceLock() -> Bool {
        if lockFileDescriptor >= 0 { return true }

        let descriptor = Darwin.open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            NSLog("[MacDragScroll] Could not open instance lock at \(lockPath).")
            return false
        }

        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            Darwin.close(descriptor)
            return false
        }

        lockFileDescriptor = descriptor
        return true
    }

    private func releasePrimaryInstanceLock() {
        guard lockFileDescriptor >= 0 else { return }
        flock(lockFileDescriptor, LOCK_UN)
        Darwin.close(lockFileDescriptor)
        lockFileDescriptor = -1
    }

    @discardableResult
    private func activateExistingInstanceIfPossible() -> Bool {
        guard let app = runningSiblingApplications().first else { return false }
        activate(app)
        return true
    }

    private func activate(_ app: NSRunningApplication) {
        if #available(macOS 14.0, *) {
            app.activate()
        } else {
            app.activate(options: [.activateIgnoringOtherApps])
        }
    }

    private func runningSiblingApplications() -> [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: Self.notificationObject)
            .filter { app in
                app.processIdentifier != processIdentifier && !app.isTerminated
            }
            .sorted { lhs, rhs in
                let lhsDate = lhs.launchDate ?? .distantPast
                let rhsDate = rhs.launchDate ?? .distantPast
                return lhsDate < rhsDate
            }
    }

    private var isRunningUnderUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
