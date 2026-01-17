//
//  MouseMonitor.swift
//  macdragscroll
//
//  Created by Martin Calander on 2026-01-16.
//

import AppKit
import CoreGraphics

class MouseMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var scrollTimer: Timer?
    private var overlayWindow: ScrollOverlayWindow?
    private var overlayShowTimer: Timer?  // Delay before showing overlay
    
    private var isTriggerActive = false
    private var originPoint: CGPoint = .zero
    private var currentPoint: CGPoint = .zero
    private var isActivated = false
    private var isOverlayVisible = false  // Track if overlay is actually shown
    private var hasMovedOutsideDeadZone = false  // Track if moved outside dead zone
    
    // Window tracking - pause scroll when cursor leaves original window
    private var originWindowNumber: Int?  // The window where drag started
    private var isCursorInOriginWindow = true  // Track if cursor is in original window
    
    // Track current modifier state
    private var currentModifiers: NSEvent.ModifierFlags = []
    
    // Quick click threshold - if released before this, don't show overlay
    private let overlayShowDelay: TimeInterval = 0.15  // 150ms
    
    // Get settings from SettingsManager
    private var scrollSpeed: Double { SettingsManager.shared.scrollSpeed }
    private var deadZoneRadius: Double { SettingsManager.shared.deadZoneRadius }
    private var acceleration: Double { SettingsManager.shared.acceleration }
    private var triggerConfig: TriggerConfig { SettingsManager.shared.triggerConfig }
    
    func start() {
        // Monitor all mouse events we might need
        let eventMask: NSEvent.EventTypeMask = [
            .otherMouseDown, .otherMouseUp, .otherMouseDragged,  // Middle/other buttons
            .rightMouseDown, .rightMouseUp, .rightMouseDragged,  // Right button
            .leftMouseDown, .leftMouseUp, .leftMouseDragged,     // Left button (with modifiers)
            .mouseMoved,
            .flagsChanged  // For tracking modifier keys
        ]
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] event in
            self?.handleMouseEvent(event)
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: eventMask) { [weak self] event in
            self?.handleMouseEvent(event)
            return event
        }
    }
    
    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        stopScrolling()
    }
    
    private func handleMouseEvent(_ event: NSEvent) {
        guard SettingsManager.shared.isEnabled else { return }
        
        // Check if current app is excluded
        if isCurrentAppExcluded() { return }
        
        // Track modifier changes
        if event.type == .flagsChanged {
            currentModifiers = event.modifierFlags
            // If trigger is active and required modifiers are no longer held, stop
            if isTriggerActive && triggerConfig.hasModifiers {
                if !triggerConfig.modifiersStillHeld(currentModifiers) {
                    handleTriggerRelease()
                }
            }
            return
        }
        
        let config = triggerConfig
        
        // Handle mouse down events
        switch event.type {
        case .leftMouseDown:
            if config.mouseButton == 0 && config.matches(button: 0, modifiers: event.modifierFlags) {
                handleTriggerPress(at: NSEvent.mouseLocation)
            }
        case .rightMouseDown:
            if config.mouseButton == 1 && config.matches(button: 1, modifiers: event.modifierFlags) {
                handleTriggerPress(at: NSEvent.mouseLocation)
            }
        case .otherMouseDown:
            if event.buttonNumber == config.mouseButton && config.matches(button: event.buttonNumber, modifiers: event.modifierFlags) {
                handleTriggerPress(at: NSEvent.mouseLocation)
            }
            
        // Handle mouse up events
        case .leftMouseUp:
            if isTriggerActive && config.mouseButton == 0 {
                handleTriggerRelease()
            }
        case .rightMouseUp:
            if isTriggerActive && config.mouseButton == 1 {
                handleTriggerRelease()
            }
        case .otherMouseUp:
            if isTriggerActive && event.buttonNumber == config.mouseButton {
                handleTriggerRelease()
            }
            
        // Handle mouse drag/move events
        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .mouseMoved:
            if isTriggerActive {
                handleMouseMoved(at: NSEvent.mouseLocation)
            }
            
        default:
            break
        }
    }
    
    private func isCurrentAppExcluded() -> Bool {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontmostApp.bundleIdentifier else {
            return false
        }
        return SettingsManager.shared.isAppExcluded(bundleIdentifier: bundleId)
    }
    
    // MARK: - Core Logic
    
    private func handleTriggerPress(at point: CGPoint) {
        isTriggerActive = true
        hasMovedOutsideDeadZone = false
        isOverlayVisible = false
        originPoint = point
        currentPoint = point
        
        // Capture the window under the cursor when drag starts
        originWindowNumber = getWindowNumberAtPoint(point)
        isCursorInOriginWindow = true
        
        // Activate scroll mode immediately (logic runs), but delay showing the overlay
        activateScrollMode()
        
        // Schedule overlay to appear after a short delay
        overlayShowTimer = Timer.scheduledTimer(withTimeInterval: overlayShowDelay, repeats: false) { [weak self] _ in
            guard let self = self, self.isTriggerActive, self.isActivated else { return }
            self.showOverlay()
        }
    }
    
    private func handleTriggerRelease() {
        isTriggerActive = false
        
        // Cancel the overlay show timer if it hasn't fired yet
        overlayShowTimer?.invalidate()
        overlayShowTimer = nil
        
        stopScrolling()
    }
    
    private func handleMouseMoved(at point: CGPoint) {
        currentPoint = point
        
        // Check if cursor is still in the original window
        let wasInOriginWindow = isCursorInOriginWindow
        isCursorInOriginWindow = isCursorOverOriginWindow(at: point)
        
        // Update overlay opacity when entering/leaving origin window
        if wasInOriginWindow != isCursorInOriginWindow && isOverlayVisible {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.overlayWindow?.setPaused(!self.isCursorInOriginWindow)
            }
        }
        
        let deltaX = currentPoint.x - originPoint.x
        let deltaY = currentPoint.y - originPoint.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        
        // Track if moved outside dead zone
        if !hasMovedOutsideDeadZone && distance > deadZoneRadius {
            hasMovedOutsideDeadZone = true
            
            // Trigger click bounce when starting to scroll (if overlay is visible)
            if isOverlayVisible && isCursorInOriginWindow {
                DispatchQueue.main.async { [weak self] in
                    self?.overlayWindow?.animateClickBounce()
                }
            }
        }
        
        // Only update overlay if activated and visible
        guard isActivated, isOverlayVisible else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.overlayWindow?.updateArrow(to: self.currentPoint)
        }
    }
    
    // MARK: - Window Tracking
    
    private func getWindowNumberAtPoint(_ point: CGPoint) -> Int? {
        let windowListOptions: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(windowListOptions, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        
        for windowInfo in windowInfoList {
            guard let bounds = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let windowNumber = windowInfo[kCGWindowNumber as String] as? Int,
                  let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int32 else {
                continue
            }
            
            // Skip our own app's windows
            if ownerPID == ProcessInfo.processInfo.processIdentifier {
                continue
            }
            
            let windowFrame = CGRect(
                x: bounds["X"] ?? 0,
                y: bounds["Y"] ?? 0,
                width: bounds["Width"] ?? 0,
                height: bounds["Height"] ?? 0
            )
            
            // CGWindowListCopyWindowInfo uses top-left origin, NSEvent uses bottom-left
            let screenHeight = NSScreen.main?.frame.height ?? 0
            let flippedY = screenHeight - point.y
            let checkPoint = CGPoint(x: point.x, y: flippedY)
            
            if windowFrame.contains(checkPoint) {
                return windowNumber
            }
        }
        
        return nil
    }
    
    private func isCursorOverOriginWindow(at point: CGPoint) -> Bool {
        guard let originWindow = originWindowNumber else { return true }
        let currentWindow = getWindowNumberAtPoint(point)
        return currentWindow == originWindow
    }
    
    // MARK: - Overlay & Scrolling
    
    private func showOverlay() {
        guard SettingsManager.shared.animationsEnabled else { return }
        guard isActivated, !isOverlayVisible else { return }
        isOverlayVisible = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.overlayWindow = ScrollOverlayWindow(origin: self.originPoint)
            self.overlayWindow?.show()
        }
    }
    
    private func activateScrollMode() {
        guard isTriggerActive else { return }
        isActivated = true
        
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.performScroll()
        }
        RunLoop.main.add(scrollTimer!, forMode: .common)
    }
    
    private func stopScrolling() {
        isActivated = false
        isOverlayVisible = false
        scrollTimer?.invalidate()
        scrollTimer = nil
        
        // Reset window tracking
        originWindowNumber = nil
        isCursorInOriginWindow = true
        
        DispatchQueue.main.async { [weak self] in
            self?.overlayWindow?.hide()
            self?.overlayWindow = nil
        }
    }
    
    private func performScroll() {
        guard isActivated, isCursorInOriginWindow else { return }
        
        let deltaX = currentPoint.x - originPoint.x
        let deltaY = currentPoint.y - originPoint.y
        
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        
        guard distance > deadZoneRadius else { return }
        
        let effectiveDistance = distance - deadZoneRadius
        let acceleratedDistance = pow(effectiveDistance / 30.0, acceleration)
        let intensity = min(acceleratedDistance, 50.0) * scrollSpeed
        
        let normalizedX = deltaX / distance
        let normalizedY = deltaY / distance
        
        let scrollDeltaY = Int32(round(normalizedY * intensity))
        let scrollDeltaX = Int32(round(normalizedX * intensity))
        
        guard scrollDeltaX != 0 || scrollDeltaY != 0 else { return }

        guard let event = CGEvent(scrollWheelEvent2Source: nil,
                                  units: .pixel,
                                  wheelCount: 2,
                                  wheel1: scrollDeltaY,
                                  wheel2: scrollDeltaX,
                                  wheel3: 0) else {
            // CGEvent creation failed - this can happen in rare system conditions
            return
        }

        event.post(tap: .cghidEventTap)
    }
}
