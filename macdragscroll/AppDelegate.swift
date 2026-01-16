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

class AppDelegate: NSObject, NSApplicationDelegate {
    static let appVersion = "1.18.0"
    static var appName: String {
        NSLocalizedString("app_name", comment: "App name")
    }
    
    private var statusItem: NSStatusItem!
    private var mouseMonitor: MouseMonitor!
    private var popover: NSPopover!
    private var permissionCheckTimer: Timer?
    private var eventMonitor: Any?
    private var hadPermissionPreviously = false
    
    // Observable permission state for SwiftUI
    static let permissionState = PermissionState()
    
    class PermissionState: ObservableObject {
        @Published var hasAccessibilityPermission: Bool = AXIsProcessTrusted()
        
        func refresh() {
            hasAccessibilityPermission = AXIsProcessTrusted()
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupPopover()
        
        NSApp.setActivationPolicy(.accessory)
        
        // Check accessibility permissions
        checkAccessibilityPermissions()
    }
    
    private func checkAccessibilityPermissions() {
        // Initial check
        AppDelegate.permissionState.refresh()
        let hasPermission = AXIsProcessTrusted()
        
        if !hasPermission {
            // Show permission dialog on first launch without permission
            showPermissionDialog()
            startPermissionMonitoring()
        } else {
            hadPermissionPreviously = true
            startMouseMonitor()
            // Continue monitoring in case permission is revoked
            startPermissionMonitoring()
        }
    }
    
    private func startPermissionMonitoring() {
        // Continuously monitor permission status (every 1 second)
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let currentPermission = AXIsProcessTrusted()
            AppDelegate.permissionState.refresh()
            
            if currentPermission && !self.hadPermissionPreviously {
                // Permission was just granted
                self.hadPermissionPreviously = true
                self.startMouseMonitor()
            } else if !currentPermission && self.hadPermissionPreviously {
                // Permission was revoked while app was running
                self.hadPermissionPreviously = false
                self.mouseMonitor?.stop()
                self.showPermissionRevokedDialog()
            }
        }
    }
    
    private func showPermissionDialog() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("permission_required_title", comment: "Permission required alert title")
        alert.informativeText = NSLocalizedString("permission_required_message", comment: "Permission required alert message")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("open_system_settings", comment: "Open System Settings button"))
        alert.addButton(withTitle: NSLocalizedString("later", comment: "Later button"))
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            AppDelegate.openAccessibilitySettings()
        }
    }
    
    private func showPermissionRevokedDialog() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("permission_lost_title", comment: "Permission lost alert title")
        alert.informativeText = NSLocalizedString("permission_lost_message", comment: "Permission lost alert message")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("open_system_settings", comment: "Open System Settings button"))
        alert.addButton(withTitle: NSLocalizedString("ok", comment: "OK button"))
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            AppDelegate.openAccessibilitySettings()
        }
    }
    
    private func startMouseMonitor() {
        if mouseMonitor == nil {
            mouseMonitor = MouseMonitor()
        }
        mouseMonitor.start()
    }
    
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "arrow.up.and.down.and.arrow.left.and.right", accessibilityDescription: AppDelegate.appName)
            button.action = #selector(togglePopover(_:))
            button.target = self
            // Enable right-click to also open the popover
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        // Popover size is controlled by the SwiftUI view's .frame() modifier
        // See kPopoverWidth/kPopoverHeight constants in SettingsWindow.swift
        popover.contentSize = NSSize(width: 380, height: 440)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MenuBarSettingsView())
    }
    
    @objc private func togglePopover(_ sender: Any?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                
                // Start monitoring for clicks outside the popover
                eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                    self?.closePopover()
                }
            }
        }
    }
    
    private func closePopover() {
        popover.performClose(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
