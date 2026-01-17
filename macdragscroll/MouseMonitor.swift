//
//  MouseMonitor.swift
//  macdragscroll
//
//  Created by Martin Calander on 2026-01-16.
//

import AppKit
import CoreGraphics
import ApplicationServices

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

    // UI Element tracking - pause scroll when cursor leaves original element
    private var originElement: AXUIElement?  // The UI element where drag started
    private var originElementBounds: CGRect?  // Cached bounds of the origin element
    private var isCursorInOriginElement = true  // Track if cursor is in original element
    
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

        // Capture the UI element under the cursor for element-bound scrolling
        captureOriginElement(at: point)
        isCursorInOriginElement = true

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

        // Check if cursor is still in the original UI element
        let wasInOriginElement = isCursorInOriginElement
        isCursorInOriginElement = isCursorOverOriginElement(at: point)

        // Determine if scrolling should be active (must be in both window AND element)
        let wasScrollActive = wasInOriginWindow && wasInOriginElement
        let isScrollActive = isCursorInOriginWindow && isCursorInOriginElement

        // Update overlay opacity when entering/leaving scroll-active region
        if wasScrollActive != isScrollActive && isOverlayVisible {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.overlayWindow?.setPaused(!isScrollActive)
            }
        }

        let deltaX = currentPoint.x - originPoint.x
        let deltaY = currentPoint.y - originPoint.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)

        // Track if moved outside dead zone
        if !hasMovedOutsideDeadZone && distance > deadZoneRadius {
            hasMovedOutsideDeadZone = true

            // Trigger click bounce when starting to scroll (if overlay is visible)
            if isOverlayVisible && isScrollActive {
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

    // MARK: - UI Element Tracking

    /// Captures the scrollable UI element at the given point for element-bound scrolling
    private func captureOriginElement(at point: CGPoint) {
        // Convert from bottom-left (NSEvent) to top-left (Accessibility) coordinate system
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let accessibilityPoint = CGPoint(x: point.x, y: screenHeight - point.y)

        // Get the system-wide accessibility element
        let systemWideElement = AXUIElementCreateSystemWide()

        // Get the element at the cursor position
        var elementRef: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(systemWideElement, Float(accessibilityPoint.x), Float(accessibilityPoint.y), &elementRef)

        guard result == .success, let element = elementRef else {
            print("[DragScroll] Failed to get element at position: \(result.rawValue)")
            originElement = nil
            originElementBounds = nil
            return
        }

        // Debug: print the element we found
        debugPrintElement(element, label: "Element at cursor")

        // Find the best container element for scroll bounds
        let containerElement = findBestContainerElement(from: element, at: point)
        originElement = containerElement

        // Cache the bounds of the container element
        originElementBounds = getElementBounds(containerElement)

        // Debug: print what we're using
        debugPrintElement(containerElement, label: "Using container")
        print("[DragScroll] Container bounds: \(originElementBounds?.debugDescription ?? "nil")")
    }

    /// Debug helper to print element info
    private func debugPrintElement(_ element: AXUIElement, label: String) {
        var roleRef: CFTypeRef?
        var titleRef: CFTypeRef?
        var identifierRef: CFTypeRef?

        let role: String
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success {
            role = roleRef as? String ?? "unknown"
        } else {
            role = "unknown"
        }

        let title: String
        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef) == .success {
            title = titleRef as? String ?? ""
        } else {
            title = ""
        }

        let identifier: String
        if AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identifierRef) == .success {
            identifier = identifierRef as? String ?? ""
        } else {
            identifier = ""
        }

        let bounds = getElementBounds(element)
        print("[DragScroll] \(label): role=\(role), title='\(title)', id='\(identifier)', bounds=\(bounds?.debugDescription ?? "nil")")
    }

    /// Finds the best container element for scroll bounds - looks for panels, split groups, scroll areas, etc.
    private func findBestContainerElement(from element: AXUIElement, at point: CGPoint) -> AXUIElement {
        var current: AXUIElement? = element
        var bestContainer: AXUIElement = element
        var bestContainerBounds: CGRect? = getElementBounds(element)

        // Get window bounds to avoid selecting the entire window
        let windowBounds = getWindowBoundsAtPoint(point)
        let minContainerSize: CGFloat = 50  // Minimum reasonable container size

        while let elem = current {
            guard let bounds = getElementBounds(elem) else {
                // Move to parent
                current = getParentElement(elem)
                continue
            }

            // Skip if this is basically the whole window (within 20px margin)
            if let winBounds = windowBounds {
                let isFullWindow = abs(bounds.width - winBounds.width) < 40 &&
                                   abs(bounds.height - winBounds.height) < 40
                if isFullWindow {
                    // Stop here, don't go further up
                    break
                }
            }

            // Check the role
            var roleRef: CFTypeRef?
            let role: String
            if AXUIElementCopyAttributeValue(elem, kAXRoleAttribute as CFString, &roleRef) == .success {
                role = roleRef as? String ?? ""
            } else {
                role = ""
            }

            // Good container roles - these typically represent panels/sections
            let isGoodContainer = role == kAXScrollAreaRole as String ||
                                  role == kAXGroupRole as String ||
                                  role == kAXSplitGroupRole as String ||
                                  role == kAXTableRole as String ||
                                  role == kAXListRole as String ||
                                  role == kAXOutlineRole as String ||
                                  role == kAXTextAreaRole as String ||
                                  role == "AXTabGroup" ||
                                  role == "AXLayoutArea"

            // Skip window and application roles
            let skipRoles = [kAXWindowRole as String, kAXApplicationRole as String]
            if skipRoles.contains(role) {
                break
            }

            // If this is a good container with reasonable size, use it
            if isGoodContainer && bounds.width >= minContainerSize && bounds.height >= minContainerSize {
                // Prefer this container if it's larger than current best but still reasonable
                if bestContainerBounds == nil ||
                   (bounds.width >= bestContainerBounds!.width && bounds.height >= bestContainerBounds!.height) {
                    bestContainer = elem
                    bestContainerBounds = bounds

                    // If it's a scroll area, that's usually ideal - stop here
                    if role == kAXScrollAreaRole as String {
                        print("[DragScroll] Found scroll area, using it")
                        return elem
                    }
                }
            }

            // Move to parent
            current = getParentElement(elem)
        }

        return bestContainer
    }

    /// Gets the parent element
    private func getParentElement(_ element: AXUIElement) -> AXUIElement? {
        var parentRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parentRef) == .success,
           let parent = parentRef {
            return (parent as! AXUIElement)
        }
        return nil
    }

    /// Gets window bounds at the given point
    private func getWindowBoundsAtPoint(_ point: CGPoint) -> CGRect? {
        let windowListOptions: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(windowListOptions, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        let screenHeight = NSScreen.main?.frame.height ?? 0
        let flippedY = screenHeight - point.y

        for windowInfo in windowInfoList {
            guard let bounds = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int32 else {
                continue
            }

            if ownerPID == ProcessInfo.processInfo.processIdentifier {
                continue
            }

            let windowFrame = CGRect(
                x: bounds["X"] ?? 0,
                y: bounds["Y"] ?? 0,
                width: bounds["Width"] ?? 0,
                height: bounds["Height"] ?? 0
            )

            let checkPoint = CGPoint(x: point.x, y: flippedY)
            if windowFrame.contains(checkPoint) {
                // Convert to NSEvent coordinate system
                let bottomLeftY = screenHeight - windowFrame.origin.y - windowFrame.height
                return CGRect(x: windowFrame.origin.x, y: bottomLeftY,
                              width: windowFrame.width, height: windowFrame.height)
            }
        }

        return nil
    }

    // Keep for reference but not actively used
    private func findScrollableAncestor(from element: AXUIElement) -> AXUIElement? {
        var current: AXUIElement? = element
        var bestScrollable: AXUIElement? = nil

        while let elem = current {
            if isElementScrollable(elem) {
                bestScrollable = elem

                var roleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(elem, kAXRoleAttribute as CFString, &roleRef) == .success,
                   let role = roleRef as? String {
                    if role == kAXScrollAreaRole as String ||
                       role == kAXTableRole as String ||
                       role == kAXListRole as String ||
                       role == kAXOutlineRole as String {
                        return elem
                    }
                }
            }

            var parentRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(elem, kAXParentAttribute as CFString, &parentRef) == .success,
               let parent = parentRef {
                current = (parent as! AXUIElement)
            } else {
                break
            }
        }

        return bestScrollable
    }

    /// Checks if an element is scrollable (has scroll bars or is a scroll area)
    private func isElementScrollable(_ element: AXUIElement) -> Bool {
        // Check role
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
           let role = roleRef as? String {
            // These roles are inherently scrollable
            if role == kAXScrollAreaRole as String ||
               role == kAXTableRole as String ||
               role == kAXListRole as String ||
               role == kAXOutlineRole as String ||
               role == kAXTextAreaRole as String {
                return true
            }
        }

        // Check for scroll bar children
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                var childRoleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &childRoleRef) == .success,
                   let childRole = childRoleRef as? String,
                   childRole == kAXScrollBarRole as String {
                    return true
                }
            }
        }

        return false
    }

    /// Gets the bounds of a UI element in screen coordinates (bottom-left origin for comparison with NSEvent)
    private func getElementBounds(_ element: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?

        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        guard AXValueGetValue(positionRef as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else {
            return nil
        }

        // Convert from top-left (Accessibility) to bottom-left (NSEvent) coordinate system
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let bottomLeftY = screenHeight - position.y - size.height

        return CGRect(x: position.x, y: bottomLeftY, width: size.width, height: size.height)
    }

    /// Checks if the cursor is within the bounds of the original element
    private func isCursorOverOriginElement(at point: CGPoint) -> Bool {
        // If we don't have element bounds, don't restrict (fall back to window-only tracking)
        guard let bounds = originElementBounds else { return true }

        // Add a small tolerance to prevent jitter at edges
        let tolerance: CGFloat = 2.0
        let expandedBounds = bounds.insetBy(dx: -tolerance, dy: -tolerance)

        return expandedBounds.contains(point)
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

        // Reset element tracking
        originElement = nil
        originElementBounds = nil
        isCursorInOriginElement = true

        DispatchQueue.main.async { [weak self] in
            self?.overlayWindow?.hide()
            self?.overlayWindow = nil
        }
    }
    
    private func performScroll() {
        // Only scroll if cursor is in both the original window AND the original element
        guard isActivated, isCursorInOriginWindow, isCursorInOriginElement else { return }

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
