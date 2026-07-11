//
//  MouseMonitor.swift
//  macdragscroll
//
//  Created by Martin Calander on 2026-01-16.
//

import AppKit
import CoreGraphics
import ApplicationServices

struct ScrollDeltas: Equatable {
    let horizontal: Int32
    let vertical: Int32
}

struct TriggerClickSample: Equatable {
    let button: Int
    let modifiers: NSEvent.ModifierFlags
    let point: CGPoint
    let clickState: Int64
    let timestamp: CFTimeInterval
}

enum TriggerClickSequence {
    static func isDoubleClick(
        previous: TriggerClickSample?,
        current: TriggerClickSample,
        maxInterval: CFTimeInterval,
        maxTravel: CGFloat
    ) -> Bool {
        if current.clickState >= 2 {
            return true
        }

        guard let previous else { return false }
        guard previous.button == current.button,
              previous.modifiers == current.modifiers else {
            return false
        }

        let elapsed = current.timestamp - previous.timestamp
        guard elapsed >= 0, elapsed <= maxInterval else {
            return false
        }

        let deltaX = current.point.x - previous.point.x
        let deltaY = current.point.y - previous.point.y
        return sqrt(deltaX * deltaX + deltaY * deltaY) <= maxTravel
    }
}

enum TriggerInputSource {
    private static let defaultMouseSubtype: Int64 = 0

    static func canStartDragScroll(mouseSubtype: Int64) -> Bool {
        mouseSubtype == defaultMouseSubtype
    }
}

enum EventTapInterruption {
    static func requiresInteractionCancellation(_ eventType: CGEventType) -> Bool {
        eventType == .tapDisabledByTimeout || eventType == .tapDisabledByUserInput
    }
}

enum CursorHoldBehavior {
    static let middleMouseButton = 2
    static let maximumVirtualDistance: CGFloat = 2_048
    static let releaseMissThreshold = 2

    static func shouldActivate(isEnabled: Bool, mouseButton: Int) -> Bool {
        isEnabled && mouseButton == middleMouseButton
    }

    static func nextVirtualPoint(
        current: CGPoint,
        origin: CGPoint,
        deltaX: CGFloat,
        deltaY: CGFloat
    ) -> CGPoint {
        guard deltaX.isFinite, deltaY.isFinite else { return current }

        // Quartz mouse deltas grow downward; the visualizer uses AppKit's upward-growing Y axis.
        let proposed = CGPoint(x: current.x + deltaX, y: current.y - deltaY)
        let offsetX = proposed.x - origin.x
        let offsetY = proposed.y - origin.y
        let distance = hypot(offsetX, offsetY)

        guard distance.isFinite else { return current }
        guard distance > maximumVirtualDistance else { return proposed }

        let scale = maximumVirtualDistance / distance
        return CGPoint(
            x: origin.x + offsetX * scale,
            y: origin.y + offsetY * scale
        )
    }

    static func releaseMissCount(afterButtonState isPressed: Bool, previousCount: Int) -> Int {
        guard !isPressed else { return 0 }
        guard previousCount < releaseMissThreshold else { return releaseMissThreshold }
        return max(previousCount, 0) + 1
    }

    static func shouldCancelForMissingButton(releaseMissCount: Int) -> Bool {
        releaseMissCount >= releaseMissThreshold
    }
}

enum ScrollPhysics {
    private static let minimumAxisDirection = 0.12

    static func distance(from origin: CGPoint, to current: CGPoint) -> Double {
        let deltaX = current.x - origin.x
        let deltaY = current.y - origin.y
        return sqrt(deltaX * deltaX + deltaY * deltaY)
    }

    static func isInDeadZone(from origin: CGPoint, to current: CGPoint, deadZoneRadius: Double) -> Bool {
        distance(from: origin, to: current) <= deadZoneRadius
    }

    static func intensity(distance: Double, deadZoneRadius: Double, acceleration: Double, scrollSpeed: Double) -> Double {
        guard distance > deadZoneRadius else { return 0 }

        let effectiveDistance = distance - deadZoneRadius
        let acceleratedDistance = pow(effectiveDistance / 30.0, acceleration)
        return min(acceleratedDistance, 50.0) * scrollSpeed
    }

    static func direction(from origin: CGPoint, to current: CGPoint) -> (x: Double, y: Double) {
        let deltaX = current.x - origin.x
        let deltaY = current.y - origin.y
        let distance = distance(from: origin, to: current)

        guard distance > 0 else { return (0, 0) }
        return (deltaX / distance, deltaY / distance)
    }

    static func deltas(
        from origin: CGPoint,
        to current: CGPoint,
        scrollSpeed: Double,
        deadZoneRadius: Double,
        acceleration: Double,
        reversesDirection: Bool,
        allowsHorizontal: Bool = true,
        invertsHorizontal: Bool = false
    ) -> ScrollDeltas {
        let distance = distance(from: origin, to: current)
        guard distance > deadZoneRadius else {
            return ScrollDeltas(horizontal: 0, vertical: 0)
        }

        let direction = direction(from: origin, to: current)
        let intensity = intensity(
            distance: distance,
            deadZoneRadius: deadZoneRadius,
            acceleration: acceleration,
            scrollSpeed: scrollSpeed
        )

        let horizontalReverses = reversesDirection != invertsHorizontal
        let horizontal = allowsHorizontal
            ? wheelDelta(directionComponent: direction.x, intensity: intensity, reversesDirection: horizontalReverses)
            : 0
        let vertical = wheelDelta(directionComponent: direction.y, intensity: intensity, reversesDirection: reversesDirection)

        return ScrollDeltas(horizontal: horizontal, vertical: vertical)
    }

    private static func wheelDelta(directionComponent: Double, intensity: Double, reversesDirection: Bool) -> Int32 {
        guard abs(directionComponent) >= minimumAxisDirection else { return 0 }

        let directionMultiplier = reversesDirection ? -1.0 : 1.0
        let rawDelta = directionComponent * intensity * directionMultiplier
        let roundedDelta = Int32(round(rawDelta))

        if roundedDelta == 0 {
            return rawDelta > 0 ? 1 : -1
        }

        return roundedDelta
    }
}

enum ScrollEventFactory {
    static let syntheticEventMarker: Int64 = 0x4D445343524F4C4C

    static func makeScrollEvent(
        deltas: ScrollDeltas,
        location: CGPoint,
        source: CGEventSource? = nil
    ) -> CGEvent? {
        guard let source = source ?? CGEventSource(stateID: .combinedSessionState) else {
            return nil
        }

        guard let event = CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 2,
            wheel1: deltas.vertical,
            wheel2: deltas.horizontal,
            wheel3: 0
        ) else {
            return nil
        }

        event.location = location
        event.setIntegerValueField(.eventSourceUserData, value: syntheticEventMarker)
        return event
    }
}

final class MouseMonitor {
    private struct Constants {
        static let overlayShowDelay: TimeInterval = 0.12
        static let quickClickReplayLimit: CFTimeInterval = 0.26
        static var doubleClickReactionInterval: CFTimeInterval {
            min(max(NSEvent.doubleClickInterval, 0.34), 0.75)
        }
        static let doubleClickReactionMaxTravel: CGFloat = 8
        static let doubleClickReactionDuration: TimeInterval = 0.42
        static let windowValidationInterval: TimeInterval = 0.15
        static let cursorHoldWatchdogGracePeriod: CFTimeInterval = 0.12
    }

    private struct WindowIdentity: Equatable {
        let number: Int
        let ownerPID: pid_t
    }

    private struct WindowSnapshot: Equatable {
        let identity: WindowIdentity
        let bounds: CGRect
    }

    private struct PendingClick {
        let button: Int
        let modifiers: NSEvent.ModifierFlags
        let quartzPoint: CGPoint
        let clickState: Int64
        let startedAt: CFTimeInterval
    }

    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?
    private var scrollTimer: Timer?
    private var overlayShowTimer: Timer?
    private var overlayWindow: ScrollOverlayWindow?
    private var clickReactionWindow: ScrollOverlayWindow?
    private var clickReactionHideTimer: Timer?
    private let syntheticEventSource = CGEventSource(stateID: .combinedSessionState)
    private var userInteractionActivity: NSObjectProtocol?

    private var isTriggerActive = false
    private var isActivated = false
    private var isOverlayVisible = false
    private var hasMovedOutsideDeadZone = false

    private var originPoint: CGPoint = .zero
    private var currentPoint: CGPoint = .zero
    private var originQuartzPoint: CGPoint = .zero
    private var currentQuartzPoint: CGPoint = .zero
    private var originWindow: WindowSnapshot?
    private var originBundleIdentifier: String?
    private var activeTriggerConfig: TriggerConfig?
    private var pendingClick: PendingClick?
    private var lastQuickClick: TriggerClickSample?
    private var didShowReactionForActivePress = false
    private var isCursorHoldActive = false
    private var cursorHoldReleaseMissCount = 0
    private var isOriginWindowAvailable = false
    private var lastWindowValidation: CFTimeInterval = 0

    private var scrollSpeed: Double { SettingsManager.shared.scrollSpeed }
    private var deadZoneRadius: Double { SettingsManager.shared.deadZoneRadius }
    private var acceleration: Double { SettingsManager.shared.acceleration }
    private var reverseScrollDirection: Bool { SettingsManager.shared.reverseScrollDirection }
    private var horizontalScrollingEnabled: Bool { SettingsManager.shared.horizontalScrollingEnabled }
    private var invertHorizontalScroll: Bool { SettingsManager.shared.invertHorizontalScroll }
    private var triggerConfig: TriggerConfig { SettingsManager.shared.triggerConfig }
    private var screenParametersObserver: NSObjectProtocol?
    private var workspaceObservers: [NSObjectProtocol] = []

    var isRunning: Bool {
        guard let eventTap, eventTapRunLoopSource != nil else { return false }
        return CFMachPortIsValid(eventTap) && CGEvent.tapIsEnabled(tap: eventTap)
    }

    @discardableResult
    func start() -> Bool {
        if let eventTap,
           CFMachPortIsValid(eventTap),
           eventTapRunLoopSource != nil {
            if !CGEvent.tapIsEnabled(tap: eventTap) {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return CGEvent.tapIsEnabled(tap: eventTap)
        }

        if eventTap != nil || eventTapRunLoopSource != nil {
            stop()
        }

        guard AXIsProcessTrusted() else {
            NSLog("[MacDragScroll] Accessibility permission is required before creating the mouse event tap.")
            return false
        }
        guard CGPreflightListenEventAccess() else {
            NSLog("[MacDragScroll] Input Monitoring permission is required before creating the mouse event tap.")
            return false
        }

        let eventMask = Self.eventMask(for: [
            .leftMouseDown, .leftMouseUp, .leftMouseDragged,
            .rightMouseDown, .rightMouseUp, .rightMouseDragged,
            .otherMouseDown, .otherMouseUp, .otherMouseDragged,
            .mouseMoved,
            .flagsChanged
        ])

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: Self.eventTapCallback,
            userInfo: refcon
        ) else {
            NSLog("[MacDragScroll] Failed to create mouse event tap.")
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            NSLog("[MacDragScroll] Failed to create the mouse event tap run-loop source.")
            return false
        }

        eventTap = tap
        eventTapRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)

        installInteractionObservers()
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        cancelInteraction()
        hideClickReaction(immediately: true)

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }

        if let source = eventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            eventTapRunLoopSource = nil
        }

        removeInteractionObservers()
    }

    private func installInteractionObservers() {
        guard screenParametersObserver == nil else { return }

        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.cancelInteractionForSystemChange()
            }
        }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let cancellationNotifications: [Notification.Name] = [
            NSWorkspace.willSleepNotification,
            NSWorkspace.sessionDidResignActiveNotification,
            NSWorkspace.screensDidSleepNotification
        ]
        workspaceObservers = cancellationNotifications.map { name in
            workspaceCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.cancelInteractionForSystemChange()
                }
            }
        }

        workspaceObservers.append(
            workspaceCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let activatedProcessIdentifier = (
                    notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                )?.processIdentifier
                MainActor.assumeIsolated {
                    self?.handleApplicationActivation(
                        processIdentifier: activatedProcessIdentifier
                    )
                }
            }
        )
    }

    private func removeInteractionObservers() {
        if let screenParametersObserver {
            NotificationCenter.default.removeObserver(screenParametersObserver)
            self.screenParametersObserver = nil
        }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers {
            workspaceCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()
    }

    private func cancelInteractionForSystemChange() {
        if isTriggerActive || isActivated {
            cancelInteraction()
        }
    }

    private func handleApplicationActivation(processIdentifier: pid_t?) {
        guard isTriggerActive, let originWindow else { return }
        guard processIdentifier == originWindow.identity.ownerPID else {
            cancelInteraction()
            return
        }
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else {
            return Unmanaged.passUnretained(event)
        }

        let monitor = Unmanaged<MouseMonitor>.fromOpaque(refcon).takeUnretainedValue()
        return monitor.handleEventTap(type: type, event: event)
    }

    private func handleEventTap(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if EventTapInterruption.requiresInteractionCancellation(type) {
            // The matching release event may have been lost while the tap was disabled.
            // Stop the timer before re-enabling the tap so stale drag state cannot scroll.
            cancelInteraction()
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return pass(event)
        }

        if event.getIntegerValueField(.eventSourceUserData) == ScrollEventFactory.syntheticEventMarker {
            return pass(event)
        }

        if SettingsManager.shared.isCapturingTrigger {
            return pass(event)
        }

        if !SettingsManager.shared.isEnabled {
            if isTriggerActive {
                cancelInteraction()
            }
            return pass(event)
        }

        if type == .flagsChanged {
            if isTriggerActive {
                handleFlagsChanged(Self.modifierFlags(from: event.flags))
            }
            return pass(event)
        }

        if type == .mouseMoved {
            guard isTriggerActive else { return pass(event) }

            let shouldSuppressEvent = handlePointerEvent(event)
            return shouldSuppressEvent ? nil : pass(event)
        }

        guard let buttonNumber = Self.buttonNumber(for: type, event: event) else {
            return pass(event)
        }

        if Self.isMouseDown(type) {
            let config = triggerConfig
            let modifiers = Self.modifierFlags(from: event.flags)
            guard config.matches(button: buttonNumber, modifiers: modifiers),
                  Self.canStartDragScroll(from: event) else {
                return pass(event)
            }

            let quartzPoint = event.location
            let point = appKitPoint(fromQuartzPoint: quartzPoint)
            guard let targetWindow = windowAtQuartzPoint(quartzPoint) else {
                return pass(event)
            }

            let targetBundleIdentifier = bundleIdentifier(
                forProcessIdentifier: targetWindow.identity.ownerPID
            )
            guard !SettingsManager.shared.isAppExcluded(bundleIdentifier: targetBundleIdentifier) else {
                return pass(event)
            }

            handleTriggerPress(
                at: point,
                quartzPoint: quartzPoint,
                button: buttonNumber,
                modifiers: modifiers,
                clickState: event.getIntegerValueField(.mouseEventClickState),
                targetWindow: targetWindow,
                targetBundleIdentifier: targetBundleIdentifier,
                config: config
            )
            return nil
        }

        guard isTriggerActive, let activeConfig = activeTriggerConfig else {
            return pass(event)
        }

        guard buttonNumber == activeConfig.mouseButton else {
            return pass(event)
        }

        if Self.isMouseUp(type) {
            handleTriggerRelease(shouldReplayClick: true)
            return nil
        }

        if Self.isMouseDragged(type) {
            handlePointerEvent(event)
            return nil
        }

        return pass(event)
    }

    private func handleFlagsChanged(_ modifiers: NSEvent.ModifierFlags) {
        guard isTriggerActive, let activeConfig = activeTriggerConfig, activeConfig.hasModifiers else {
            return
        }

        if !activeConfig.modifiersStillHeld(modifiers) {
            handleTriggerRelease(shouldReplayClick: false)
        }
    }

    private func handleTriggerPress(
        at point: CGPoint,
        quartzPoint: CGPoint,
        button: Int,
        modifiers: NSEvent.ModifierFlags,
        clickState: Int64,
        targetWindow: WindowSnapshot,
        targetBundleIdentifier: String?,
        config: TriggerConfig
    ) {
        guard !isTriggerActive else { return }

        hideClickReaction(immediately: true)
        didShowReactionForActivePress = false
        isTriggerActive = true
        isActivated = true
        isOverlayVisible = false
        hasMovedOutsideDeadZone = false
        isCursorHoldActive = CursorHoldBehavior.shouldActivate(
            isEnabled: SettingsManager.shared.keepCursorInPlace,
            mouseButton: button
        )
        cursorHoldReleaseMissCount = 0
        activeTriggerConfig = config
        pendingClick = PendingClick(
            button: button,
            modifiers: modifiers,
            quartzPoint: quartzPoint,
            clickState: max(clickState, 1),
            startedAt: CACurrentMediaTime()
        )
        originPoint = point
        currentPoint = point
        originQuartzPoint = quartzPoint
        currentQuartzPoint = quartzPoint
        originWindow = targetWindow
        originBundleIdentifier = targetBundleIdentifier
        isOriginWindowAvailable = true
        lastWindowValidation = 0

        beginUserInteractionActivity()

        if clickState >= 2 {
            lastQuickClick = nil
            didShowReactionForActivePress = true
            showDoubleClickReaction(at: point)
        }

        updateOriginWindowAvailability(force: true)
        startScrollTimer()
        scheduleOverlay()
    }

    private func handleTriggerRelease(shouldReplayClick: Bool) {
        let clickToReplay = shouldReplayClick ? pendingClickForReplay() : nil

        isTriggerActive = false
        activeTriggerConfig = nil
        pendingClick = nil
        overlayShowTimer?.invalidate()
        overlayShowTimer = nil
        stopScrolling()

        if let clickToReplay, !didShowReactionForActivePress {
            registerQuickClickReaction(for: clickToReplay)
        }

        didShowReactionForActivePress = false

        if let clickToReplay {
            self.replayClick(clickToReplay)
        }
    }

    private func cancelInteraction() {
        isTriggerActive = false
        activeTriggerConfig = nil
        pendingClick = nil
        didShowReactionForActivePress = false
        overlayShowTimer?.invalidate()
        overlayShowTimer = nil
        stopScrolling()
    }

    private func pendingClickForReplay() -> PendingClick? {
        guard let pendingClick, !hasMovedOutsideDeadZone else { return nil }

        let elapsed = CACurrentMediaTime() - pendingClick.startedAt
        guard elapsed <= Constants.quickClickReplayLimit else { return nil }

        return pendingClick
    }

    private func handlePointerMoved(to point: CGPoint, quartzPoint: CGPoint) {
        currentPoint = point
        currentQuartzPoint = quartzPoint

        let distance = ScrollPhysics.distance(from: originPoint, to: currentPoint)

        if !hasMovedOutsideDeadZone && distance > deadZoneRadius {
            hasMovedOutsideDeadZone = true
            lastQuickClick = nil
            if isOverlayVisible && isOriginWindowAvailable {
                overlayWindow?.animateClickBounce()
            }
        }
    }

    @discardableResult
    private func handlePointerEvent(_ event: CGEvent) -> Bool {
        guard isCursorHoldActive else {
            let quartzPoint = event.location
            handlePointerMoved(
                to: appKitPoint(fromQuartzPoint: quartzPoint),
                quartzPoint: quartzPoint
            )
            return false
        }

        guard SettingsManager.shared.keepCursorInPlace else {
            disableCursorHold(resetVirtualPosition: false)
            let quartzPoint = event.location
            handlePointerMoved(
                to: appKitPoint(fromQuartzPoint: quartzPoint),
                quartzPoint: quartzPoint
            )
            return false
        }

        let deltaX = CGFloat(event.getIntegerValueField(.mouseEventDeltaX))
        let deltaY = CGFloat(event.getIntegerValueField(.mouseEventDeltaY))
        let virtualPoint = CursorHoldBehavior.nextVirtualPoint(
            current: currentPoint,
            origin: originPoint,
            deltaX: deltaX,
            deltaY: deltaY
        )

        // A warp has no persistent lock state, so a crash or forced quit immediately restores normal movement.
        guard CGWarpMouseCursorPosition(originQuartzPoint) == .success else {
            NSLog("[MacDragScroll] Cursor hold failed; continuing the drag with normal pointer movement.")
            disableCursorHold(resetVirtualPosition: false)
            let quartzPoint = event.location
            handlePointerMoved(
                to: appKitPoint(fromQuartzPoint: quartzPoint),
                quartzPoint: quartzPoint
            )
            return false
        }

        handlePointerMoved(to: virtualPoint, quartzPoint: originQuartzPoint)
        return true
    }

    private func disableCursorHold(resetVirtualPosition: Bool) {
        isCursorHoldActive = false
        cursorHoldReleaseMissCount = 0

        if resetVirtualPosition {
            currentPoint = originPoint
            currentQuartzPoint = originQuartzPoint
        }
    }

    private func scheduleOverlay() {
        overlayShowTimer?.invalidate()
        overlayShowTimer = Timer(timeInterval: Constants.overlayShowDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isTriggerActive, self.isActivated else { return }
                self.showOverlay()
            }
        }
        if let overlayShowTimer {
            RunLoop.main.add(overlayShowTimer, forMode: .common)
        }
    }

    private func showOverlay() {
        guard SettingsManager.shared.showIndicator else { return }
        guard isActivated, !isOverlayVisible else { return }

        isOverlayVisible = true
        let window = ScrollOverlayWindow(origin: originPoint)
        overlayWindow = window
        window.show()
        window.updateDragPoint(to: currentPoint)
    }

    private func startScrollTimer() {
        guard scrollTimer == nil else { return }

        scrollTimer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.performScroll()
            }
        }

        if let scrollTimer {
            RunLoop.main.add(scrollTimer, forMode: .common)
        }
    }

    private func stopScrolling() {
        isActivated = false
        isOverlayVisible = false
        hasMovedOutsideDeadZone = false
        isCursorHoldActive = false
        cursorHoldReleaseMissCount = 0
        originWindow = nil
        originBundleIdentifier = nil
        originQuartzPoint = .zero
        currentQuartzPoint = .zero
        isOriginWindowAvailable = false
        lastWindowValidation = 0

        endUserInteractionActivity()

        scrollTimer?.invalidate()
        scrollTimer = nil

        overlayWindow?.hide()
        overlayWindow = nil
    }

    private func registerQuickClickReaction(for pendingClick: PendingClick) {
        let sample = TriggerClickSample(
            button: pendingClick.button,
            modifiers: pendingClick.modifiers,
            point: appKitPoint(fromQuartzPoint: pendingClick.quartzPoint),
            clickState: pendingClick.clickState,
            timestamp: CACurrentMediaTime()
        )

        if TriggerClickSequence.isDoubleClick(
            previous: lastQuickClick,
            current: sample,
            maxInterval: Constants.doubleClickReactionInterval,
            maxTravel: Constants.doubleClickReactionMaxTravel
        ) {
            lastQuickClick = nil
            showDoubleClickReaction(at: sample.point)
        } else {
            lastQuickClick = sample
        }
    }

    private func showDoubleClickReaction(at point: CGPoint) {
        guard SettingsManager.shared.showIndicator,
              SettingsManager.shared.visualizerAnimationsEnabled else {
            return
        }

        hideClickReaction(immediately: true)

        let window = ScrollOverlayWindow(origin: point)
        clickReactionWindow = window
        window.showDoubleClickReaction()

        clickReactionHideTimer = Timer(timeInterval: Constants.doubleClickReactionDuration, repeats: false) { [weak self, weak window] _ in
            MainActor.assumeIsolated {
                guard let self else { return }

                window?.hide()
                if self.clickReactionWindow === window {
                    self.clickReactionWindow = nil
                    self.clickReactionHideTimer = nil
                }
            }
        }

        if let clickReactionHideTimer {
            RunLoop.main.add(clickReactionHideTimer, forMode: .common)
        }
    }

    private func hideClickReaction(immediately: Bool) {
        clickReactionHideTimer?.invalidate()
        clickReactionHideTimer = nil

        guard let clickReactionWindow else { return }

        if immediately {
            clickReactionWindow.orderOut(nil)
        } else {
            clickReactionWindow.hide()
        }

        self.clickReactionWindow = nil
    }

    private func performScroll() {
        guard isActivated else { return }

        if !SettingsManager.shared.isEnabled || isOriginAppExcluded() {
            cancelInteraction()
            return
        }

        if isCursorHoldActive {
            guard SettingsManager.shared.keepCursorInPlace else {
                disableCursorHold(resetVirtualPosition: true)
                return
            }

            let holdStartedAt = pendingClick?.startedAt ?? 0
            if CACurrentMediaTime() - holdStartedAt >= Constants.cursorHoldWatchdogGracePeriod {
                let isMiddleButtonPressed = CGEventSource.buttonState(
                    .hidSystemState,
                    button: .center
                )
                cursorHoldReleaseMissCount = CursorHoldBehavior.releaseMissCount(
                    afterButtonState: isMiddleButtonPressed,
                    previousCount: cursorHoldReleaseMissCount
                )

                if CursorHoldBehavior.shouldCancelForMissingButton(
                    releaseMissCount: cursorHoldReleaseMissCount
                ) {
                    cancelInteraction()
                    return
                }
            }
        }

        updateOriginWindowAvailability()
        guard isOriginWindowAvailable else {
            cancelInteraction()
            return
        }

        if isOverlayVisible {
            overlayWindow?.updateDragPoint(to: currentPoint)
        }

        let deltas = ScrollPhysics.deltas(
            from: originPoint,
            to: currentPoint,
            scrollSpeed: scrollSpeed,
            deadZoneRadius: deadZoneRadius,
            acceleration: acceleration,
            reversesDirection: reverseScrollDirection,
            allowsHorizontal: horizontalScrollingEnabled,
            invertsHorizontal: invertHorizontalScroll
        )

        guard deltas.horizontal != 0 || deltas.vertical != 0 else { return }

        guard let scrollLocation = scrollDeliveryQuartzPoint(),
              let scrollEvent = ScrollEventFactory.makeScrollEvent(
                  deltas: deltas,
                  location: scrollLocation,
                  source: syntheticEventSource
              ) else {
            return
        }

        scrollEvent.post(tap: .cghidEventTap)
    }

    private func updateOriginWindowAvailability(force: Bool = false) {
        guard let originWindow else {
            setOriginWindowAvailable(false)
            return
        }

        let now = CACurrentMediaTime()
        guard force || now - lastWindowValidation >= Constants.windowValidationInterval else {
            return
        }

        lastWindowValidation = now

        let snapshots = windowSnapshots()
        guard let refreshedWindow = snapshots.first(where: { $0.identity == originWindow.identity }) else {
            setOriginWindowAvailable(false)
            return
        }

        self.originWindow = refreshedWindow
        guard !isCursorHoldActive || refreshedWindow.bounds.contains(originQuartzPoint) else {
            setOriginWindowAvailable(false)
            return
        }

        guard let deliveryPoint = scrollDeliveryQuartzPoint() else {
            setOriginWindowAvailable(false)
            return
        }

        let frontmostWindow = snapshots.first { $0.bounds.contains(deliveryPoint) }
        setOriginWindowAvailable(frontmostWindow?.identity == refreshedWindow.identity)
    }

    private func setOriginWindowAvailable(_ available: Bool) {
        guard available != isOriginWindowAvailable else { return }

        isOriginWindowAvailable = available
    }

    private func scrollDeliveryQuartzPoint() -> CGPoint? {
        guard let originWindow else { return nil }

        if originWindow.bounds.contains(currentQuartzPoint) {
            return currentQuartzPoint
        }

        if originWindow.bounds.contains(originQuartzPoint) {
            return originQuartzPoint
        }

        return CGPoint(x: originWindow.bounds.midX, y: originWindow.bounds.midY)
    }

    private func windowAtQuartzPoint(_ quartzPoint: CGPoint) -> WindowSnapshot? {
        return windowSnapshots().first { $0.bounds.contains(quartzPoint) }
    }

    private func windowSnapshots() -> [WindowSnapshot] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]

        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return windowInfoList.compactMap(windowSnapshot(from:))
    }

    private func isOriginAppExcluded() -> Bool {
        SettingsManager.shared.isAppExcluded(bundleIdentifier: originBundleIdentifier)
    }

    private func bundleIdentifier(forProcessIdentifier processIdentifier: pid_t) -> String? {
        let app = NSRunningApplication(processIdentifier: processIdentifier)
        return app?.bundleIdentifier
    }

    private func replayClick(_ pendingClick: PendingClick) {
        guard
            let source = syntheticEventSource ?? CGEventSource(stateID: .combinedSessionState),
            let mouseButton = CGMouseButton(rawValue: UInt32(pendingClick.button)),
            let downEvent = CGEvent(
                mouseEventSource: source,
                mouseType: cgEventType(for: pendingClick.button, isDown: true),
                mouseCursorPosition: pendingClick.quartzPoint,
                mouseButton: mouseButton
            ),
            let upEvent = CGEvent(
                mouseEventSource: source,
                mouseType: cgEventType(for: pendingClick.button, isDown: false),
                mouseCursorPosition: pendingClick.quartzPoint,
                mouseButton: mouseButton
            )
        else {
            return
        }

        let flags = cgEventFlags(from: pendingClick.modifiers)
        [downEvent, upEvent].forEach { event in
            event.flags = flags
            event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(pendingClick.button))
            event.setIntegerValueField(.mouseEventClickState, value: pendingClick.clickState)
            event.setIntegerValueField(.eventSourceUserData, value: ScrollEventFactory.syntheticEventMarker)
        }

        downEvent.post(tap: .cghidEventTap)
        upEvent.post(tap: .cghidEventTap)
    }

    private func beginUserInteractionActivity() {
        guard userInteractionActivity == nil else { return }
        userInteractionActivity = ProcessInfo.processInfo.beginActivity(
            options: .userInteractive,
            reason: "Mac Drag Scroll active drag scrolling"
        )
    }

    private func endUserInteractionActivity() {
        guard let userInteractionActivity else { return }
        ProcessInfo.processInfo.endActivity(userInteractionActivity)
        self.userInteractionActivity = nil
    }

    private func windowSnapshot(from windowInfo: [String: Any]) -> WindowSnapshot? {
        guard let ownerPID = int32Value(windowInfo[kCGWindowOwnerPID as String]),
              ownerPID != ProcessInfo.processInfo.processIdentifier,
              let windowNumber = intValue(windowInfo[kCGWindowNumber as String]),
              let layer = intValue(windowInfo[kCGWindowLayer as String]),
              layer == 0,
              let bounds = rectValue(windowInfo[kCGWindowBounds as String]),
              bounds.width > 1,
              bounds.height > 1 else {
            return nil
        }

        let alpha = doubleValue(windowInfo[kCGWindowAlpha as String]) ?? 1.0
        guard alpha > 0.01 else { return nil }

        return WindowSnapshot(
            identity: WindowIdentity(number: windowNumber, ownerPID: ownerPID),
            bounds: bounds
        )
    }

    private func cgEventType(for button: Int, isDown: Bool) -> CGEventType {
        switch (button, isDown) {
        case (0, true):
            return .leftMouseDown
        case (0, false):
            return .leftMouseUp
        case (1, true):
            return .rightMouseDown
        case (1, false):
            return .rightMouseUp
        default:
            return isDown ? .otherMouseDown : .otherMouseUp
        }
    }

    private func cgEventFlags(from modifiers: NSEvent.ModifierFlags) -> CGEventFlags {
        var flags: CGEventFlags = []

        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }

        return flags
    }

    private func appKitPoint(fromQuartzPoint point: CGPoint) -> CGPoint {
        for screen in NSScreen.screens {
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                continue
            }

            let displayBounds = CGDisplayBounds(CGDirectDisplayID(screenNumber.uint32Value))
            guard displayBounds.contains(point) else { continue }

            let xInScreen = point.x - displayBounds.minX
            let yInScreenFromTop = point.y - displayBounds.minY
            return CGPoint(
                x: screen.frame.minX + xInScreen,
                y: screen.frame.maxY - yInScreenFromTop
            )
        }

        let screenHeight = NSScreen.main?.frame.height ?? 0
        return CGPoint(x: point.x, y: screenHeight - point.y)
    }

    private static func eventMask(for types: [CGEventType]) -> CGEventMask {
        types.reduce(CGEventMask(0)) { mask, type in
            mask | (CGEventMask(1) << CGEventMask(type.rawValue))
        }
    }

    private static func modifierFlags(from flags: CGEventFlags) -> NSEvent.ModifierFlags {
        var modifiers: NSEvent.ModifierFlags = []

        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        if flags.contains(.maskShift) { modifiers.insert(.shift) }

        return modifiers
    }

    private static func buttonNumber(for type: CGEventType, event: CGEvent) -> Int? {
        switch type {
        case .leftMouseDown, .leftMouseUp, .leftMouseDragged:
            return 0
        case .rightMouseDown, .rightMouseUp, .rightMouseDragged:
            return 1
        case .otherMouseDown, .otherMouseUp, .otherMouseDragged:
            return Int(event.getIntegerValueField(.mouseEventButtonNumber))
        default:
            return nil
        }
    }

    private static func canStartDragScroll(from event: CGEvent) -> Bool {
        let mouseSubtype = event.getIntegerValueField(.mouseEventSubtype)
        return TriggerInputSource.canStartDragScroll(mouseSubtype: mouseSubtype)
    }

    private static func isMouseDown(_ type: CGEventType) -> Bool {
        type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown
    }

    private static func isMouseUp(_ type: CGEventType) -> Bool {
        type == .leftMouseUp || type == .rightMouseUp || type == .otherMouseUp
    }

    private static func isMouseDragged(_ type: CGEventType) -> Bool {
        type == .leftMouseDragged || type == .rightMouseDragged || type == .otherMouseDragged
    }

    private func pass(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        Unmanaged.passUnretained(event)
    }

    private func rectValue(_ value: Any?) -> CGRect? {
        guard let dictionary = value as? [String: Any],
              let x = cgFloatValue(dictionary["X"]),
              let y = cgFloatValue(dictionary["Y"]),
              let width = cgFloatValue(dictionary["Width"]),
              let height = cgFloatValue(dictionary["Height"]) else {
            return nil
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func cgFloatValue(_ value: Any?) -> CGFloat? {
        if let value = value as? CGFloat { return value }
        if let value = value as? NSNumber { return CGFloat(truncating: value) }
        if let value = value as? Double { return CGFloat(value) }
        if let value = value as? Int { return CGFloat(value) }
        return nil
    }

    private func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private func int32Value(_ value: Any?) -> pid_t? {
        if let value = value as? pid_t { return value }
        if let value = value as? NSNumber { return value.int32Value }
        return nil
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }
}
