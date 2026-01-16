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
    
    private var isMiddleButtonDown = false
    private var originPoint: CGPoint = .zero
    private var currentPoint: CGPoint = .zero
    private var isActivated = false
    private var isOverlayVisible = false  // Track if overlay is actually shown
    private var hasMovedOutsideDeadZone = false  // Track if moved outside dead zone
    
    // Quick click threshold - if released before this, don't show overlay
    private let overlayShowDelay: TimeInterval = 0.15  // 150ms
    
    // Get settings from SettingsManager
    private var scrollSpeed: Double { SettingsManager.shared.scrollSpeed }
    private var deadZoneRadius: Double { SettingsManager.shared.deadZoneRadius }
    private var acceleration: Double { SettingsManager.shared.acceleration }
    
    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.otherMouseDown, .otherMouseUp, .otherMouseDragged, .mouseMoved]) { [weak self] event in
            self?.handleMouseEvent(event)
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.otherMouseDown, .otherMouseUp, .otherMouseDragged, .mouseMoved]) { [weak self] event in
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
        
        switch event.type {
        case .otherMouseDown:
            if event.buttonNumber == 2 {
                handleMiddleMouseDown(at: NSEvent.mouseLocation)
            }
        case .otherMouseUp:
            if event.buttonNumber == 2 {
                handleMiddleMouseUp()
            }
        case .otherMouseDragged, .mouseMoved:
            if isMiddleButtonDown {
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
    
    private func handleMiddleMouseDown(at point: CGPoint) {
        isMiddleButtonDown = true
        hasMovedOutsideDeadZone = false
        isOverlayVisible = false
        originPoint = point
        currentPoint = point
        
        // Activate scroll mode immediately (logic runs), but delay showing the overlay
        activateScrollMode()
        
        // Schedule overlay to appear after a short delay
        // If user releases before this, overlay never shows (quick click)
        overlayShowTimer = Timer.scheduledTimer(withTimeInterval: overlayShowDelay, repeats: false) { [weak self] _ in
            guard let self = self, self.isMiddleButtonDown, self.isActivated else { return }
            self.showOverlay()
        }
    }
    
    private func handleMiddleMouseUp() {
        isMiddleButtonDown = false
        
        // Cancel the overlay show timer if it hasn't fired yet
        overlayShowTimer?.invalidate()
        overlayShowTimer = nil
        
        stopScrolling()
    }
    
    private func handleMouseMoved(at point: CGPoint) {
        currentPoint = point
        
        let deltaX = currentPoint.x - originPoint.x
        let deltaY = currentPoint.y - originPoint.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        
        // Track if moved outside dead zone
        if !hasMovedOutsideDeadZone && distance > deadZoneRadius {
            hasMovedOutsideDeadZone = true
            
            // Trigger click bounce when starting to scroll (if overlay is visible)
            if isOverlayVisible {
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
    
    private func showOverlay() {
        guard isActivated, !isOverlayVisible else { return }
        isOverlayVisible = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.overlayWindow = ScrollOverlayWindow(origin: self.originPoint)
            self.overlayWindow?.show()
        }
    }
    
    private func activateScrollMode() {
        guard isMiddleButtonDown else { return }
        isActivated = true
        
        // Start scroll timer immediately (logic runs even if overlay not visible yet)
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
        
        DispatchQueue.main.async { [weak self] in
            self?.overlayWindow?.hide()
            self?.overlayWindow = nil
        }
    }
    
    private func performScroll() {
        // Don't scroll if not activated
        guard isActivated else { return }
        
        let deltaX = currentPoint.x - originPoint.x
        let deltaY = currentPoint.y - originPoint.y
        
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        
        guard distance > deadZoneRadius else { return }
        
        // Calculate scroll intensity with exponential acceleration
        // The further from origin, the faster it accelerates
        let effectiveDistance = distance - deadZoneRadius
        
        // Use power function for acceleration: starts slow, ramps up quickly
        // acceleration setting controls the exponent (default 1.8)
        let acceleratedDistance = pow(effectiveDistance / 30.0, acceleration)
        let intensity = min(acceleratedDistance, 50.0) * scrollSpeed
        
        // Normalize direction
        let normalizedX = deltaX / distance
        let normalizedY = deltaY / distance
        
        // Calculate scroll amounts
        // Drag up (positive Y) = scroll up = positive wheel value
        // Drag right (positive X) = scroll right = positive wheel value
        let scrollDeltaY = Int32(round(normalizedY * intensity))
        let scrollDeltaX = Int32(round(normalizedX * intensity))
        
        // Only post if there's actual movement
        guard scrollDeltaX != 0 || scrollDeltaY != 0 else { return }
        
        // Create scroll wheel event
        let event = CGEvent(scrollWheelEvent2Source: nil,
                           units: .pixel,
                           wheelCount: 2,
                           wheel1: scrollDeltaY,
                           wheel2: scrollDeltaX,
                           wheel3: 0)
        
        event?.post(tap: .cghidEventTap)
    }
}
