//
//  AppDelegate.swift
//  macdragscroll
//
//  Created by Martin Calander on 2026-01-16.
//

import AppKit
import SwiftUI
import Combine
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private static let showWelcomeNotification = Notification.Name("MacDragScrollShowWelcomeWindow")
    private static let requestAccessibilityPermissionNotification = Notification.Name("MacDragScrollRequestAccessibilityPermission")
    private static let refreshAccessibilityPermissionNotification = Notification.Name("MacDragScrollRefreshAccessibilityPermission")
    private static let revealApplicationNotification = Notification.Name("MacDragScrollRevealApplication")
    private static let restartApplicationNotification = Notification.Name("MacDragScrollRestartApplication")

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    static var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "100"
    }

    static var appName: String {
        AppLocalization.shared.localizedString("app_name", value: "Mac Drag Scroll", comment: "App name")
    }

    static func requestWelcomeWindow() {
        NotificationCenter.default.post(name: showWelcomeNotification, object: nil)
    }

    static func requestAccessibilityPermission() {
        NotificationCenter.default.post(name: requestAccessibilityPermissionNotification, object: nil)
    }

    static func refreshAccessibilityPermission() {
        NotificationCenter.default.post(name: refreshAccessibilityPermissionNotification, object: nil)
    }

    static var applicationBundlePath: String {
        Bundle.main.bundleURL.path
    }

    static func revealApplication() {
        NotificationCenter.default.post(name: revealApplicationNotification, object: nil)
    }

    static func restartApplication() {
        NotificationCenter.default.post(name: restartApplicationNotification, object: nil)
    }

    private var statusItem: NSStatusItem!
    private var mouseMonitor: MouseMonitor!
    private var settingsWindow: NSWindow?
    private var welcomeWindow: NSWindow?
    private weak var activeMenuItem: NSMenuItem?
    private weak var updateMenuItem: NSMenuItem?
    private weak var ignoreCurrentAppMenuItem: NSMenuItem?
    private var duplicateInstanceMenuItem: NSMenuItem?
    private var permissionCheckTimer: Timer?
    private var hadPermissionPreviously = false
    private var hasPresentedWelcomeThisLaunch = false
    private var allowsImmediateTermination = false
    private var cancellables = Set<AnyCancellable>()

    // Observable permission state for SwiftUI
    static let permissionState = PermissionState()

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
        permissionCheckTimer?.invalidate()
    }
    
    enum EventMonitoringState: Equatable {
        case waiting
        case active
        case failed
    }

    class PermissionState: ObservableObject {
        private let accessibilityPermissionChecker: () -> Bool
        private let accessibilityPermissionRequester: (Bool) -> Bool
        private let inputMonitoringPermissionChecker: () -> Bool
        private let inputMonitoringPermissionRequester: () -> Bool

        @Published private(set) var hasAccessibilityPermission: Bool
        @Published private(set) var hasInputMonitoringPermission: Bool
        @Published private(set) var eventMonitoringState: EventMonitoringState = .waiting

        var hasRequiredPermissions: Bool {
            hasAccessibilityPermission && hasInputMonitoringPermission
        }

        init(
            accessibilityPermissionChecker: @escaping () -> Bool = AXIsProcessTrusted,
            accessibilityPermissionRequester: @escaping (Bool) -> Bool = AppDelegate.checkAccessibilityPermission(prompt:),
            inputMonitoringPermissionChecker: @escaping () -> Bool = AppDelegate.checkInputMonitoringPermission,
            inputMonitoringPermissionRequester: @escaping () -> Bool = AppDelegate.requestInputMonitoringPermission
        ) {
            self.accessibilityPermissionChecker = accessibilityPermissionChecker
            self.accessibilityPermissionRequester = accessibilityPermissionRequester
            self.inputMonitoringPermissionChecker = inputMonitoringPermissionChecker
            self.inputMonitoringPermissionRequester = inputMonitoringPermissionRequester
            self.hasAccessibilityPermission = accessibilityPermissionChecker()
            self.hasInputMonitoringPermission = inputMonitoringPermissionChecker()
        }
        
        @discardableResult
        func refresh() -> Bool {
            hasAccessibilityPermission = accessibilityPermissionChecker()
            hasInputMonitoringPermission = inputMonitoringPermissionChecker()
            if !hasRequiredPermissions {
                eventMonitoringState = .waiting
            }
            return hasRequiredPermissions
        }

        @discardableResult
        func request() -> Bool {
            hasAccessibilityPermission = hasAccessibilityPermission || accessibilityPermissionRequester(true)
            hasInputMonitoringPermission = hasInputMonitoringPermission || inputMonitoringPermissionRequester()
            if !hasRequiredPermissions {
                eventMonitoringState = .waiting
            }
            return hasRequiredPermissions
        }

        func setEventMonitoringState(_ state: EventMonitoringState) {
            eventMonitoringState = state
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.processName = Self.appName

        guard AppInstanceMonitor.shared.claimPrimaryInstance() else {
            allowsImmediateTermination = true
            NSApp.terminate(nil)
            return
        }

        // Setup crash handling first
        CrashHandler.appVersion = AppDelegate.appVersion
        CrashHandler.appBuild = AppDelegate.appBuild
        CrashHandler.shared.setup()
        
        setupMenuBar()
        observeSettings()
        observePrimaryInstanceActivationRequests()
        AppInstanceMonitor.shared.startMonitoring()
        observeSystemAppearance()
        applyAppearanceMode()
        updateDockIcon()
        
        NSApp.setActivationPolicy(.accessory)
        
        // Check accessibility permissions
        synchronizeAccessibilityState()
        UpdateManager.shared.checkForUpdatesIfNeeded()

        DispatchQueue.main.async { [weak self] in
            self?.presentWelcomeIfNeeded()
        }
    }
    
    private nonisolated static func checkAccessibilityPermission(prompt: Bool) -> Bool {
        guard prompt else {
            return AXIsProcessTrusted()
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private nonisolated static func checkInputMonitoringPermission() -> Bool {
        CGPreflightListenEventAccess()
    }

    private nonisolated static func requestInputMonitoringPermission() -> Bool {
        CGRequestListenEventAccess()
    }

    private func synchronizeAccessibilityState(showMissingPermissionDialog: Bool = true) {
        let hasPermission = AppDelegate.permissionState.refresh()

        if hasPermission {
            hadPermissionPreviously = true
            startMouseMonitor()
        } else {
            hadPermissionPreviously = false
            stopMouseMonitor(eventMonitoringState: .waiting)
            NSLog("[MacDragScroll] Accessibility permission is missing; event monitoring is waiting.")

            if showMissingPermissionDialog && SettingsManager.shared.hasCompletedWelcome {
                showPermissionDialog()
            }
        }

        startPermissionMonitoring()
    }
    
    private func startPermissionMonitoring() {
        // Continuously monitor permission status (every 1 second)
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let currentPermission = AppDelegate.permissionState.refresh()
            
            if currentPermission && !self.hadPermissionPreviously {
                // Permission was just granted
                self.hadPermissionPreviously = true
                self.startMouseMonitor()
            } else if !currentPermission && self.hadPermissionPreviously {
                // Permission was revoked while app was running
                self.hadPermissionPreviously = false
                self.stopMouseMonitor(eventMonitoringState: .waiting)
                self.showPermissionRevokedDialog()
            } else if currentPermission, self.mouseMonitor?.isRunning != true {
                self.startMouseMonitor()
            }
        }

        if let permissionCheckTimer {
            RunLoop.main.add(permissionCheckTimer, forMode: .common)
        }
    }
    
    private func showPermissionDialog() {
        let alert = NSAlert()
            alert.messageText = localized("permissions_required_title", value: "Permissions Required", comment: "Permission required alert title")
            alert.informativeText = localized("permissions_required_message", value: "Mac Drag Scroll needs Accessibility and Input Monitoring to listen for the mouse trigger.", comment: "Permission required alert message")
            alert.alertStyle = .warning
            alert.addButton(withTitle: localized("grant_permissions", value: "Grant Permissions", comment: "Grant permissions button"))
            alert.addButton(withTitle: localized("later", value: "Later", comment: "Later button"))
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            requestAccessibilityPermissionFromUser()
        }
    }
    
    private func showPermissionRevokedDialog() {
        let alert = NSAlert()
        alert.messageText = localized("permission_lost_title", value: "Accessibility Permission Lost", comment: "Permission lost alert title")
        alert.informativeText = localized("permission_lost_message", value: "Mac Drag Scroll can no longer monitor mouse events. Re-enable Accessibility permission to keep using drag scrolling.", comment: "Permission lost alert message")
        alert.alertStyle = .warning
        alert.addButton(withTitle: localized("open_system_settings", value: "Open System Settings", comment: "Open System Settings button"))
        alert.addButton(withTitle: localized("ok", value: "OK", comment: "OK button"))
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            requestAccessibilityPermissionFromUser()
        }
    }
    
    @discardableResult
    private func startMouseMonitor() -> Bool {
        if mouseMonitor == nil {
            mouseMonitor = MouseMonitor()
        }

        let wasRunning = mouseMonitor.isRunning
        guard mouseMonitor.start() else {
            if AppDelegate.permissionState.eventMonitoringState != .failed {
                NSLog("[MacDragScroll] Event monitoring failed to start.")
            }
            AppDelegate.permissionState.setEventMonitoringState(.failed)
            return false
        }

        if !wasRunning {
            NSLog("[MacDragScroll] Event monitoring started.")
        }
        AppDelegate.permissionState.setEventMonitoringState(.active)
        return true
    }

    private func stopMouseMonitor(eventMonitoringState: EventMonitoringState) {
        mouseMonitor?.stop()
        AppDelegate.permissionState.setEventMonitoringState(eventMonitoringState)
    }

    private func requestAccessibilityPermissionFromUser() {
        let hasPermission = AppDelegate.permissionState.request()

        if hasPermission {
            hadPermissionPreviously = true
            startMouseMonitor()
        } else {
            stopMouseMonitor(eventMonitoringState: .waiting)
            AppDelegate.openPrivacySettingsForMissingPermission()
        }
    }

    private func revealApplicationInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    private func restartRunningApplication() {
        allowsImmediateTermination = true
        let appPath = Bundle.main.bundleURL.path
        let escapedPath = appPath.replacingOccurrences(of: "'", with: "'\\''")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 0.35; /usr/bin/open '\(escapedPath)'"]

        do {
            try process.run()
        } catch {
            NSLog("[MacDragScroll] Failed to schedule application restart: \(error.localizedDescription)")
        }

        NSApplication.shared.terminate(nil)
    }
    
    static func openAccessibilitySettings() {
        openPrivacySettings(anchor: "Privacy_Accessibility")
    }

    static func openInputMonitoringSettings() {
        openPrivacySettings(anchor: "Privacy_ListenEvent")
    }

    static func openPrivacySettingsForMissingPermission() {
        if !permissionState.hasAccessibilityPermission {
            openAccessibilitySettings()
        } else {
            openInputMonitoringSettings()
        }
    }

    private static func openPrivacySettings(anchor: String) {
        let settingsURLStrings: [String]
        if #available(macOS 13.0, *) {
            settingsURLStrings = [
                "x-apple.systempreferences:com.apple.preference.security?\(anchor)",
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(anchor)"
            ]
        } else {
            settingsURLStrings = [
                "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
            ]
        }

        for urlString in settingsURLStrings {
            guard let url = URL(string: urlString), NSWorkspace.shared.open(url) else {
                continue
            }
            return
        }
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.toolTip = AppDelegate.appName
            button.setAccessibilityLabel(AppDelegate.appName)
            button.image = statusBarImage(isEnabled: SettingsManager.shared.isEnabled)
        }

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        let activeItem = NSMenuItem(
            title: activeMenuTitle(isEnabled: SettingsManager.shared.isEnabled),
            action: #selector(toggleActiveState(_:)),
            keyEquivalent: ""
        )
        activeItem.target = self
        activeItem.state = .off
        menu.addItem(activeItem)
        activeMenuItem = activeItem

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: localized("menu_settings", value: "Settings...", comment: "Settings menu item"),
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let updateItem = NSMenuItem(
            title: UpdateManager.shared.status.menuTitle,
            action: #selector(openUpdates(_:)),
            keyEquivalent: ""
        )
        updateItem.target = self
        menu.addItem(updateItem)
        updateMenuItem = updateItem
        refreshUpdateMenuItem()

        let ignoreItem = NSMenuItem(
            title: localized("menu_ignore_current_app", value: "Ignore Current App", comment: "Ignore current app menu item"),
            action: #selector(ignoreCurrentApp(_:)),
            keyEquivalent: ""
        )
        ignoreItem.target = self
        menu.addItem(ignoreItem)
        ignoreCurrentAppMenuItem = ignoreItem

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: localized("quit", value: "Quit", comment: "Quit menu item"),
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        refreshStatusItem()
    }

    private func observeSettings() {
        SettingsManager.shared.$isEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshStatusItem() }
            .store(in: &cancellables)

        UpdateManager.shared.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshUpdateMenuItem() }
            .store(in: &cancellables)

        SettingsManager.shared.$appLanguage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshLocalizedChrome() }
            .store(in: &cancellables)

        SettingsManager.shared.$appAppearance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyAppearanceMode() }
            .store(in: &cancellables)

        AppInstanceMonitor.shared.$duplicateInstanceCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshDuplicateInstanceMenuItem() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: Self.showWelcomeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.showWelcomeWindow() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: Self.requestAccessibilityPermissionNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.requestAccessibilityPermissionFromUser() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: Self.refreshAccessibilityPermissionNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.synchronizeAccessibilityState(showMissingPermissionDialog: false) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: Self.revealApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.revealApplicationInFinder() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: Self.restartApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.restartRunningApplication() }
            .store(in: &cancellables)
    }

    private func observePrimaryInstanceActivationRequests() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(primaryInstanceActivationRequested(_:)),
            name: AppInstanceMonitor.activationRequestNotification,
            object: AppInstanceMonitor.notificationObject
        )
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshStatusItem()
        AppInstanceMonitor.shared.refreshDuplicateInstances()
        refreshDuplicateInstanceMenuItem()
        refreshUpdateMenuItem()
        refreshIgnoreCurrentAppMenuItem()
    }

    @objc private func primaryInstanceActivationRequested(_ notification: Notification) {
        AppInstanceMonitor.shared.refreshDuplicateInstances()
        showSettingsWindow(selectedTab: .visualizer)
    }

    @objc private func toggleActiveState(_ sender: Any?) {
        SettingsManager.shared.isEnabled.toggle()
    }

    @objc private func openSettings(_ sender: Any?) {
        showSettingsWindow(selectedTab: .general)
    }

    @objc private func openUpdates(_ sender: Any?) {
        UpdateManager.shared.checkForUpdates()
    }

    @objc private func ignoreCurrentApp(_ sender: Any?) {
        guard let bundleId = SettingsManager.shared.getFrontmostAppBundleId(),
              !SettingsManager.shared.isAppExcluded(bundleIdentifier: bundleId) else {
            return
        }

        SettingsManager.shared.addExcludedApp(bundleId)
        refreshIgnoreCurrentAppMenuItem()
    }

    @objc private func quit(_ sender: Any?) {
        allowsImmediateTermination = true
        NSApplication.shared.terminate(nil)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !allowsImmediateTermination else {
            return .terminateNow
        }

        guard settingsWindow?.isVisible == true || welcomeWindow?.isVisible == true else {
            return .terminateNow
        }

        if SettingsManager.shared.keepRunningInMenuBar {
            keepRunningInMenuBar()
            return .terminateCancel
        }

        switch confirmQuitOrKeepRunning() {
        case .keepRunning:
            SettingsManager.shared.keepRunningInMenuBar = true
            keepRunningInMenuBar()
            return .terminateCancel
        case .quit:
            return .terminateNow
        case .cancel:
            return .terminateCancel
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func showSettingsWindow(selectedTab: SettingsTab = .visualizer) {
        SettingsWindowNavigation.shared.select(selectedTab)

        if settingsWindow == nil {
            let hostingController = NSHostingController(rootView: SettingsWindowView())
            let window = NSWindow(contentViewController: hostingController)
            window.title = AppDelegate.appName
            window.setContentSize(NSSize(width: 820, height: 620))
            window.minSize = NSSize(width: 760, height: 560)
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }

        NSApp.setActivationPolicy(.regular)
        updateDockIcon()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func presentWelcomeIfNeeded() {
        guard !SettingsManager.shared.hasCompletedWelcome, !hasPresentedWelcomeThisLaunch else { return }
        hasPresentedWelcomeThisLaunch = true
        showWelcomeWindow()
    }

    private func showWelcomeWindow() {
        if welcomeWindow == nil {
            let hostingController = NSHostingController(
                rootView: WelcomeWindowView(
                    onGetStarted: { [weak self] in
                        self?.finishWelcome(openSettings: true)
                    }
                )
            )
            let window = NSWindow(contentViewController: hostingController)
            window.title = localized("welcome_window_title", value: "Welcome to Mac Drag Scroll", comment: "Welcome window title")
            window.setContentSize(NSSize(width: 700, height: 570))
            window.minSize = NSSize(width: 660, height: 520)
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            welcomeWindow = window
        }

        NSApp.setActivationPolicy(.regular)
        updateDockIcon()
        NSApp.activate(ignoringOtherApps: true)
        welcomeWindow?.makeKeyAndOrderFront(nil)
    }

    private func finishWelcome(openSettings: Bool) {
        SettingsManager.shared.completeWelcome()
        welcomeWindow?.close()

        if openSettings {
            showSettingsWindow(selectedTab: .visualizer)
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        if window === settingsWindow {
            settingsWindow = nil
        } else if window === welcomeWindow {
            welcomeWindow = nil
        } else {
            return
        }

        DispatchQueue.main.async {
            self.hideDockIconIfNoAppWindowsAreVisible()
        }
    }

    private func hideDockIconIfNoAppWindowsAreVisible() {
        guard settingsWindow?.isVisible == true || welcomeWindow?.isVisible == true else {
            NSApp.setActivationPolicy(.accessory)
            return
        }
    }

    private enum QuitConfirmationChoice {
        case keepRunning
        case quit
        case cancel
    }

    private func keepRunningInMenuBar() {
        settingsWindow?.close()
        welcomeWindow?.close()

        DispatchQueue.main.async {
            self.hideDockIconIfNoAppWindowsAreVisible()
        }
    }

    private func confirmQuitOrKeepRunning() -> QuitConfirmationChoice {
        let alert = NSAlert()
        alert.messageText = localized("quit_keep_running_title", value: "Keep Mac Drag Scroll running?", comment: "Quit confirmation title")
        alert.informativeText = localized(
            "quit_keep_running_message",
            value: "Mac Drag Scroll can stay active in the menu bar after Settings closes. Use Quit from the menu bar icon when you want to stop it completely.",
            comment: "Quit confirmation message"
        )
        alert.alertStyle = .informational
        alert.addButton(withTitle: localized("keep_running", value: "Keep Running", comment: "Keep running button"))
        alert.addButton(withTitle: localized("quit_app", value: "Quit Mac Drag Scroll", comment: "Quit app button"))
        alert.addButton(withTitle: localized("cancel", value: "Cancel", comment: "Cancel button"))

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .keepRunning
        case .alertSecondButtonReturn:
            return .quit
        default:
            return .cancel
        }
    }

    private func refreshStatusItem() {
        let isEnabled = SettingsManager.shared.isEnabled
        activeMenuItem?.title = activeMenuTitle(isEnabled: isEnabled)
        activeMenuItem?.state = .off
        statusItem.button?.image = statusBarImage(isEnabled: isEnabled)
    }

    private func activeMenuTitle(isEnabled: Bool) -> String {
        if isEnabled {
            return localized("menu_disable", value: "Pause Drag Scrolling", comment: "Pause drag scrolling menu item")
        }

        return localized("menu_enable", value: "Resume Drag Scrolling", comment: "Resume drag scrolling menu item")
    }

    private func refreshDuplicateInstanceMenuItem() {
        guard let menu = statusItem?.menu else { return }

        if AppInstanceMonitor.shared.hasDuplicateInstances {
            let item: NSMenuItem
            if let existingItem = duplicateInstanceMenuItem {
                item = existingItem
            } else {
                item = NSMenuItem(
                    title: "",
                    action: #selector(openSettings(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.image = NSImage(
                    systemSymbolName: "exclamationmark.triangle.fill",
                    accessibilityDescription: localized("multiple_instances_warning", value: "Multiple Copies Running", comment: "Multiple instances warning")
                )

                let activeIndex = activeMenuItem.map { menu.index(of: $0) } ?? -1
                let insertionIndex = activeIndex >= 0 ? activeIndex + 1 : 0
                menu.insertItem(item, at: insertionIndex)
                duplicateInstanceMenuItem = item
            }

            item.title = localized("menu_multiple_instances_warning", value: "Multiple Copies Running", comment: "Multiple instances warning menu item")
            item.toolTip = localized("multiple_instances_warning_detail", value: "Quit the extra copy so only one Mac Drag Scroll monitor is active.", comment: "Multiple instances warning detail")
            item.isEnabled = true
        } else if let item = duplicateInstanceMenuItem {
            menu.removeItem(item)
            duplicateInstanceMenuItem = nil
        }
    }

    private func observeSystemAppearance() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(systemAppearanceDidChange(_:)),
            name: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
    }

    @objc private func systemAppearanceDidChange(_ notification: Notification) {
        guard SettingsManager.shared.appAppearance == .system else { return }
        updateDockIcon()
        refreshStatusItem()
    }

    private func applyAppearanceMode() {
        NSApp.appearance = SettingsManager.shared.appAppearance.nsAppearance
        updateDockIcon()
        refreshStatusItem()
    }

    private func updateDockIcon() {
        let iconName = usesDarkAppearance ? "DockIconDark" : "DockIconLight"
        if let image = NSImage(named: iconName) {
            NSApp.applicationIconImage = image
        }
    }

    private var usesDarkAppearance: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private func refreshUpdateMenuItem() {
        let status = UpdateManager.shared.status
        updateMenuItem?.title = status.menuTitle
        updateMenuItem?.isEnabled = UpdateManager.shared.canCheckForUpdates
        updateMenuItem?.action = #selector(openUpdates(_:))
    }

    private func refreshIgnoreCurrentAppMenuItem() {
        guard let item = ignoreCurrentAppMenuItem else { return }
        guard let bundleId = SettingsManager.shared.getFrontmostAppBundleId() else {
            item.title = localized("menu_ignore_current_app", value: "Ignore Current App", comment: "Ignore current app menu item")
            item.isEnabled = false
            return
        }

        let appName = displayName(forBundleIdentifier: bundleId) ?? localized("current_app", value: "Current App", comment: "Current app fallback")
        if SettingsManager.shared.isAppExcluded(bundleIdentifier: bundleId) {
            item.title = String(format: localized("menu_ignored_app", value: "%@ Ignored", comment: "Ignored app menu item"), appName)
            item.isEnabled = false
        } else {
            item.title = String(format: localized("menu_ignore_app", value: "Ignore %@", comment: "Ignore app menu item"), appName)
            item.isEnabled = true
        }
    }

    private func displayName(forBundleIdentifier bundleId: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }

        return (url.lastPathComponent as NSString).deletingPathExtension
    }

    private func localized(_ key: String, value: String, comment: String) -> String {
        AppLocalization.shared.localizedString(key, value: value, comment: comment)
    }

    private func refreshLocalizedChrome() {
        statusItem.button?.toolTip = AppDelegate.appName
        statusItem.button?.setAccessibilityLabel(AppDelegate.appName)
        settingsWindow?.title = AppDelegate.appName
        welcomeWindow?.title = localized("welcome_window_title", value: "Welcome to Mac Drag Scroll", comment: "Welcome window title")
        refreshStatusItem()
        refreshDuplicateInstanceMenuItem()
        refreshUpdateMenuItem()
        refreshIgnoreCurrentAppMenuItem()
    }

    private func statusBarImage(isEnabled: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()
        defer {
            image.unlockFocus()
            image.isTemplate = true
        }

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        func drawTrail(y: CGFloat, alpha: CGFloat, width: CGFloat, endX: CGFloat) {
            let path = NSBezierPath()
            path.lineWidth = width
            path.lineCapStyle = .round
            path.move(to: NSPoint(x: 2.0, y: y))
            path.curve(
                to: NSPoint(x: endX, y: y - 0.2),
                controlPoint1: NSPoint(x: 4.2, y: y + 1.0),
                controlPoint2: NSPoint(x: endX - 2.0, y: y - 1.0)
            )
            NSColor.black.withAlphaComponent(alpha).setStroke()
            path.stroke()
        }

        drawTrail(y: 12.2, alpha: 0.72, width: 1.28, endX: 10.4)
        drawTrail(y: 9.0, alpha: 0.56, width: 1.12, endX: 10.0)
        drawTrail(y: 5.9, alpha: 0.40, width: 1.0, endX: 9.6)

        let mouseTop = NSBezierPath()
        mouseTop.move(to: NSPoint(x: 13.0, y: 15.0))
        mouseTop.curve(
            to: NSPoint(x: 16.0, y: 12.7),
            controlPoint1: NSPoint(x: 14.5, y: 15.0),
            controlPoint2: NSPoint(x: 15.6, y: 14.2)
        )
        mouseTop.curve(
            to: NSPoint(x: 16.2, y: 6.2),
            controlPoint1: NSPoint(x: 16.3, y: 10.4),
            controlPoint2: NSPoint(x: 16.4, y: 8.1)
        )
        mouseTop.curve(
            to: NSPoint(x: 13.0, y: 3.2),
            controlPoint1: NSPoint(x: 16.0, y: 4.1),
            controlPoint2: NSPoint(x: 14.8, y: 3.2)
        )
        mouseTop.curve(
            to: NSPoint(x: 9.8, y: 6.2),
            controlPoint1: NSPoint(x: 11.2, y: 3.2),
            controlPoint2: NSPoint(x: 10.0, y: 4.1)
        )
        mouseTop.curve(
            to: NSPoint(x: 10.0, y: 12.7),
            controlPoint1: NSPoint(x: 9.6, y: 8.1),
            controlPoint2: NSPoint(x: 9.7, y: 10.4)
        )
        mouseTop.curve(
            to: NSPoint(x: 13.0, y: 15.0),
            controlPoint1: NSPoint(x: 10.4, y: 14.2),
            controlPoint2: NSPoint(x: 11.5, y: 15.0)
        )
        mouseTop.close()
        NSColor.black.withAlphaComponent(0.78).setFill()
        mouseTop.fill()

        NSColor.black.withAlphaComponent(0.22).setStroke()
        mouseTop.lineWidth = 0.65
        mouseTop.stroke()

        let split = NSBezierPath()
        split.lineWidth = 0.55
        split.lineCapStyle = .round
        split.move(to: NSPoint(x: 13.0, y: 14.0))
        split.line(to: NSPoint(x: 13.0, y: 11.5))
        split.move(to: NSPoint(x: 13.0, y: 8.8))
        split.line(to: NSPoint(x: 13.0, y: 7.2))
        NSColor.black.withAlphaComponent(0.32).setStroke()
        split.stroke()

        let wheel = NSBezierPath(roundedRect: NSRect(x: 12.35, y: 8.7, width: 1.3, height: 2.8), xRadius: 0.65, yRadius: 0.65)
        NSColor.black.withAlphaComponent(0.34).setFill()
        wheel.fill()

        let buttonCurve = NSBezierPath()
        buttonCurve.lineWidth = 0.55
        buttonCurve.lineCapStyle = .round
        buttonCurve.move(to: NSPoint(x: 10.8, y: 8.0))
        buttonCurve.curve(
            to: NSPoint(x: 15.2, y: 8.0),
            controlPoint1: NSPoint(x: 11.8, y: 8.8),
            controlPoint2: NSPoint(x: 14.2, y: 8.8)
        )
        NSColor.black.withAlphaComponent(0.24).setStroke()
        buttonCurve.stroke()

        if !isEnabled {
            let slash = NSBezierPath()
            slash.lineWidth = 2.0
            slash.lineCapStyle = .round
            slash.move(to: NSPoint(x: 3.0, y: 15.0))
            slash.line(to: NSPoint(x: 15.0, y: 3.0))
            NSColor.black.withAlphaComponent(0.88).setStroke()
            slash.stroke()
        }

        return image
    }
}
