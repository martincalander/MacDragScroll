//
//  AppDelegate.swift
//  macdragscroll
//
//  Created by Martin Calander on 2026-01-16.
//

import AppKit
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    static let appVersion = "1.4.0"
    
    private var statusItem: NSStatusItem!
    private var mouseMonitor: MouseMonitor!
    private var enabledMenuItem: NSMenuItem!
    private var permissionCheckTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        
        NSApp.setActivationPolicy(.accessory)
        
        // Check accessibility permissions
        checkAccessibilityPermissions()
    }
    
    private func checkAccessibilityPermissions() {
        if !AXIsProcessTrusted() {
            showAccessibilityAlert()
            
            // Keep checking until permission is granted
            permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    self?.permissionCheckTimer = nil
                    self?.startMouseMonitor()
                }
            }
        } else {
            startMouseMonitor()
        }
    }
    
    private func startMouseMonitor() {
        if mouseMonitor == nil {
            mouseMonitor = MouseMonitor()
        }
        mouseMonitor.start()
    }
    
    private func showAccessibilityAlert() {
        NSApp.activate(ignoringOtherApps: true)
        
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "MacDragScroll needs Accessibility permission to detect mouse events and simulate scrolling.\n\nPlease go to:\nSystem Settings → Privacy & Security → Accessibility\n\nThen enable MacDragScroll in the list."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }
    
    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "arrow.up.and.down.and.arrow.left.and.right", accessibilityDescription: "MacDragScroll")
        }
        
        let menu = NSMenu()
        
        // Version header (disabled/readonly)
        let versionItem = NSMenuItem(title: "MacDragScroll v\(AppDelegate.appVersion)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        
        menu.addItem(NSMenuItem.separator())
        
        enabledMenuItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledMenuItem.state = SettingsManager.shared.isEnabled ? .on : .off
        menu.addItem(enabledMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit MacDragScroll", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        SettingsManager.shared.isEnabled.toggle()
        sender.state = SettingsManager.shared.isEnabled ? .on : .off
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
