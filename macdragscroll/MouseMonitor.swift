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
    
    private var isMiddleButtonDown = false
    private var originPoint: CGPoint = .zero
    private var currentPoint: CGPoint = .zero
    private var isActivated = false
    
    // Scroll settings
    private let scrollSpeed: Double = 2.0
    private let deadZoneRadius: Double = 20.0
    
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
    
    private func handleMiddleMouseDown(at point: CGPoint) {
        isMiddleButtonDown = true
        originPoint = point
        currentPoint = point
        activateScrollMode()
    }
    
    private func handleMiddleMouseUp() {
        isMiddleButtonDown = false
        stopScrolling()
    }
    
    private func handleMouseMoved(at point: CGPoint) {
        currentPoint = point
        
        if isActivated {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.overlayWindow?.updateArrow(to: self.currentPoint)
            }
        }
    }
    
    private func activateScrollMode() {
        guard isMiddleButtonDown else { return }
        isActivated = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.overlayWindow = ScrollOverlayWindow(origin: self.originPoint)
            self.overlayWindow?.show()
        }
        
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.performScroll()
        }
        RunLoop.main.add(scrollTimer!, forMode: .common)
    }
    
    private func stopScrolling() {
        isActivated = false
        scrollTimer?.invalidate()
        scrollTimer = nil
        
        DispatchQueue.main.async { [weak self] in
            self?.overlayWindow?.hide()
            self?.overlayWindow = nil
        }
    }
    
    private func performScroll() {
        let deltaX = currentPoint.x - originPoint.x
        let deltaY = currentPoint.y - originPoint.y
        
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        
        guard distance > deadZoneRadius else { return }
        
        // Calculate scroll intensity with exponential acceleration
        // The further from origin, the faster it accelerates
        let effectiveDistance = distance - deadZoneRadius
        
        // Use power function for acceleration: starts slow, ramps up quickly
        // pow(x, 1.8) gives nice exponential feel
        let acceleratedDistance = pow(effectiveDistance / 30.0, 1.8)
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
