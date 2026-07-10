//
//  ScrollOverlayWindow.swift
//  macdragscroll
//
//  Created by Martin Calander on 2026-01-16.
//

import AppKit
import QuartzCore

enum ScrollOverlayGeometry {
    static let animationPadding: CGFloat = 18

    static func sideLength(deadZoneRadius: CGFloat, visualizerSize: CGFloat = 1.0) -> CGFloat {
        let baseLength = min(max(deadZoneRadius * 1.15 + 65, 88), 128)
        return min(max(baseLength * visualizerSize, 42), 154)
    }

    static func windowFrame(for origin: CGPoint, deadZoneRadius: CGFloat, visualizerSize: CGFloat = 1.0) -> CGRect {
        let side = windowSideLength(deadZoneRadius: deadZoneRadius, visualizerSize: visualizerSize)
        return CGRect(
            x: origin.x - side / 2,
            y: origin.y - side / 2,
            width: side,
            height: side
        )
    }

    static func windowSideLength(deadZoneRadius: CGFloat, visualizerSize: CGFloat = 1.0) -> CGFloat {
        sideLength(deadZoneRadius: deadZoneRadius, visualizerSize: visualizerSize) + animationPadding * 2
    }

    static func visualFrame(deadZoneRadius: CGFloat, visualizerSize: CGFloat = 1.0) -> CGRect {
        let side = sideLength(deadZoneRadius: deadZoneRadius, visualizerSize: visualizerSize)
        return CGRect(x: animationPadding, y: animationPadding, width: side, height: side)
    }

    static func originInVisualFrame(visualFrame: CGRect) -> CGPoint {
        CGPoint(x: visualFrame.width / 2, y: visualFrame.height / 2)
    }
}

enum ScrollOverlaySquashAxis: Equatable {
    case horizontal
    case vertical
}

struct ScrollOverlaySquash: Equatable {
    let amount: CGFloat
    let axis: ScrollOverlaySquashAxis

    static let none = ScrollOverlaySquash(amount: 0, axis: .vertical)
}

enum ScrollOverlayMotion {
    static let maximumSquash: CGFloat = 0.30

    static func flickSquash(previousVelocity: CGPoint, currentVelocity: CGPoint, liquidGlassIntensity: CGFloat) -> ScrollOverlaySquash {
        let horizontalVelocity = abs(currentVelocity.x)
        let verticalVelocity = abs(currentVelocity.y)
        let axis: ScrollOverlaySquashAxis = verticalVelocity >= horizontalVelocity ? .vertical : .horizontal
        let currentAxisVelocity = axis == .vertical ? currentVelocity.y : currentVelocity.x
        let previousAxisVelocity = axis == .vertical ? previousVelocity.y : previousVelocity.x

        guard currentAxisVelocity * previousAxisVelocity < 0 else {
            return .none
        }

        let reversalEnergy = abs(currentAxisVelocity - previousAxisVelocity)
        let dominantVelocity = max(horizontalVelocity, verticalVelocity)
        let velocityTotal = max(horizontalVelocity + verticalVelocity, 1)
        let dominance = dominantVelocity / velocityTotal
        let intensity = min(max(liquidGlassIntensity, 0.7), 2.0)
        let threshold = CGFloat(360) - intensity * 45
        let normalizedEnergy = min(max((reversalEnergy - threshold) / 1100, 0), 1)
        let verticalBias: CGFloat = axis == .vertical ? 1.16 : 1.0
        let amount = min(normalizedEnergy * dominance * verticalBias * (0.16 + intensity * 0.070), maximumSquash)

        guard amount > 0.004 else {
            return .none
        }

        return ScrollOverlaySquash(amount: amount, axis: axis)
    }

    static func dotScale(for squash: ScrollOverlaySquash) -> CGSize {
        guard squash.amount > 0 else {
            return CGSize(width: 1, height: 1)
        }

        switch squash.axis {
        case .vertical:
            return CGSize(width: 1 + squash.amount * 0.86, height: max(1 - squash.amount, 0.72))
        case .horizontal:
            return CGSize(width: max(1 - squash.amount, 0.72), height: 1 + squash.amount * 0.86)
        }
    }
}

final class ScrollOverlayWindow: NSWindow {
    private let overlayView: ScrollOverlayView
    private let glassView: NSGlassEffectView
    private let containerView: NSView
    private let screenOrigin: CGPoint
    private let animationPosition: CGPoint
    private var currentScale: CGFloat = 1.0
    private var currentTilt: CGPoint = .zero

    init(origin: CGPoint) {
        let frame = Self.windowFrame(for: origin)
        let visualFrame = ScrollOverlayGeometry.visualFrame(
            deadZoneRadius: CGFloat(SettingsManager.shared.deadZoneRadius),
            visualizerSize: CGFloat(SettingsManager.shared.visualizerSize)
        )
        let originInVisualFrame = ScrollOverlayGeometry.originInVisualFrame(visualFrame: visualFrame)

        screenOrigin = origin
        containerView = NSView(frame: CGRect(origin: .zero, size: frame.size))
        overlayView = ScrollOverlayView(origin: originInVisualFrame, screenOrigin: origin, frame: CGRect(origin: .zero, size: visualFrame.size))
        glassView = NSGlassEffectView(frame: visualFrame)
        animationPosition = CGPoint(x: visualFrame.midX, y: visualFrame.midY)

        super.init(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        level = .statusBar
        isOpaque = false
        hasShadow = false
        backgroundColor = .clear
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        alphaValue = 0

        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor

        glassView.autoresizingMask = []
        glassView.wantsLayer = true
        glassView.style = .clear
        glassView.cornerRadius = min(visualFrame.width, visualFrame.height) / 2
        glassView.tintColor = SettingsManager.shared.visualizerTintStyle.glassTintColor(
            intensity: SettingsManager.shared.liquidGlassIntensity
        ) ?? NSColor.white.withAlphaComponent(
            min(0.090 + SettingsManager.shared.liquidGlassIntensity * 0.018, 0.14)
        )
        glassView.contentView = overlayView
        containerView.addSubview(glassView)
        contentView = containerView

        setScale(1.0)
    }

    func show() {
        orderFrontRegardless()

        guard SettingsManager.shared.visualizerAnimationsEnabled else {
            alphaValue = SettingsManager.shared.overlayOpacity
            return
        }

        setScale(0.82)
        alphaValue = 0

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = SettingsManager.shared.overlayOpacity
        }

        let animation = CASpringAnimation(keyPath: "transform.scale")
        animation.fromValue = 0.82
        animation.toValue = 1.0
        animation.damping = 16
        animation.stiffness = 260
        animation.mass = 0.8
        animation.initialVelocity = 5
        animation.duration = animation.settlingDuration
        glassView.layer?.add(animation, forKey: "appear")
        setScale(1.0)
    }

    func hide() {
        guard SettingsManager.shared.visualizerAnimationsEnabled else {
            orderOut(nil)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.08
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        } completionHandler: {
            self.orderOut(nil)
        }

        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 1.0
        animation.toValue = 0.92
        animation.duration = 0.08
        animation.timingFunction = CAMediaTimingFunction(name: .easeIn)
        glassView.layer?.add(animation, forKey: "disappear")
    }

    func updateDragPoint(to current: CGPoint) {
        overlayView.updateDragPoint(to: current)
        updateGlassSurface(to: current)
    }

    func animateClickBounce() {
        guard SettingsManager.shared.visualizerAnimationsEnabled else { return }

        let animation = CAKeyframeAnimation(keyPath: "transform.scale")
        animation.values = [1.0, 0.94, 1.04, 1.0]
        animation.keyTimes = [0, 0.25, 0.65, 1.0]
        animation.duration = 0.18
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glassView.layer?.add(animation, forKey: "activationBounce")
    }

    func showDoubleClickReaction() {
        orderFrontRegardless()

        guard SettingsManager.shared.visualizerAnimationsEnabled else {
            alphaValue = SettingsManager.shared.overlayOpacity
            return
        }

        setScale(0.78)
        alphaValue = 0
        overlayView.triggerClickRipple()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.09
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = SettingsManager.shared.overlayOpacity
        }

        let animation = CAKeyframeAnimation(keyPath: "transform.scale")
        animation.values = [0.78, 1.18, 0.94, 1.04, 1.0]
        animation.keyTimes = [0, 0.24, 0.56, 0.78, 1.0]
        animation.duration = 0.36
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glassView.layer?.add(animation, forKey: "doubleClickPulse")
        setScale(1.0)
    }

    private func setScale(_ scale: CGFloat) {
        currentScale = scale
        applyGlassTransform(animated: false)
    }

    private func updateGlassSurface(to current: CGPoint) {
        let deltaX = current.x - screenOrigin.x
        let deltaY = current.y - screenOrigin.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        let intensity = CGFloat(SettingsManager.shared.liquidGlassIntensity)
        let activationDistance = max(46, 78 - intensity * 16)
        let activation = min(max((distance - CGFloat(SettingsManager.shared.deadZoneRadius)) / activationDistance, 0), 1)

        guard activation > 0, distance > 0 else {
            currentTilt = .zero
            applyGlassTransform(animated: SettingsManager.shared.visualizerAnimationsEnabled)
            return
        }

        currentTilt = CGPoint(
            x: (deltaX / distance) * activation,
            y: (deltaY / distance) * activation
        )
        applyGlassTransform(animated: SettingsManager.shared.visualizerAnimationsEnabled)
    }

    private func applyGlassTransform(animated: Bool) {
        CATransaction.begin()
        if animated {
            CATransaction.setAnimationDuration(0.10)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        } else {
            CATransaction.setDisableActions(true)
        }

        glassView.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        glassView.layer?.position = animationPosition

        let intensity = CGFloat(SettingsManager.shared.liquidGlassIntensity)
        let maxTiltAngle = CGFloat.pi / 180 * (4.5 + intensity * 1.4)
        let reactiveScale = 1 + min(abs(currentTilt.x) + abs(currentTilt.y), 1) * (0.010 + intensity * 0.004)
        var transform = CATransform3DIdentity
        transform.m34 = -1 / 650
        transform = CATransform3DScale(transform, currentScale * reactiveScale, currentScale * reactiveScale, 1)
        transform = CATransform3DRotate(transform, currentTilt.y * maxTiltAngle, 1, 0, 0)
        transform = CATransform3DRotate(transform, -currentTilt.x * maxTiltAngle, 0, 1, 0)
        glassView.layer?.transform = transform

        CATransaction.commit()
    }

    private static func windowFrame(for origin: CGPoint) -> CGRect {
        return ScrollOverlayGeometry.windowFrame(
            for: origin,
            deadZoneRadius: CGFloat(SettingsManager.shared.deadZoneRadius),
            visualizerSize: CGFloat(SettingsManager.shared.visualizerSize)
        )
    }
}

final class ScrollOverlayView: NSView {
    private let originPoint: CGPoint
    private let originScreenPoint: CGPoint
    private var currentScreenPoint: CGPoint
    private var lastMotionTime: CFTimeInterval?
    private var lastVelocity: CGPoint = .zero
    private var dotSquash = ScrollOverlaySquash.none
    private var squashDecayTimer: Timer?
    private var clickRippleStartTime: CFTimeInterval?
    private var clickRippleTimer: Timer?

    private struct Style {
        static let reflectionInset: CGFloat = 1.5
        static let clickRippleDuration: CFTimeInterval = 0.42
    }

    private var deadZoneRadius: CGFloat {
        CGFloat(SettingsManager.shared.deadZoneRadius)
    }

    init(origin: CGPoint, screenOrigin: CGPoint, frame: CGRect) {
        originPoint = origin
        originScreenPoint = screenOrigin
        currentScreenPoint = screenOrigin
        super.init(frame: frame)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateDragPoint(to point: CGPoint) {
        updateMotionEffects(to: point)
        currentScreenPoint = point
        needsDisplay = true
    }

    func triggerClickRipple() {
        guard SettingsManager.shared.visualizerAnimationsEnabled else { return }

        clickRippleStartTime = CACurrentMediaTime()
        startClickRippleTimer()
        needsDisplay = true
    }

    deinit {
        squashDecayTimer?.invalidate()
        clickRippleTimer?.invalidate()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let opacity = CGFloat(SettingsManager.shared.overlayOpacity)
        let intensity = CGFloat(SettingsManager.shared.liquidGlassIntensity)
        let deltaX = currentScreenPoint.x - originScreenPoint.x
        let deltaY = currentScreenPoint.y - originScreenPoint.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        let activation = clamped((distance - deadZoneRadius) / 42)
        let unitX = distance > 0 ? deltaX / distance : 0
        let unitY = distance > 0 ? deltaY / distance : 0

        drawGlassReflections(in: context, opacity: opacity, activation: activation, unitX: unitX, unitY: unitY, intensity: intensity)
        drawClickRipple(in: context, opacity: opacity, intensity: intensity)
        drawMovingDot(in: context, deltaX: deltaX, deltaY: deltaY, distance: distance, opacity: opacity, intensity: intensity)
    }

    private func drawGlassReflections(in context: CGContext, opacity: CGFloat, activation: CGFloat, unitX: CGFloat, unitY: CGFloat, intensity: CGFloat) {
        let inset = Style.reflectionInset
        let radius = min(bounds.width, bounds.height) / 2 - inset
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let lightVector = normalized(
            x: -0.56 + unitX * (0.38 + intensity * 0.09) * activation,
            y: 0.83 + unitY * (0.38 + intensity * 0.09) * activation
        )
        let reflectionTravel = bounds.width * (0.050 + intensity * 0.016)
        let highlightAngle = atan2(lightVector.y, lightVector.x)
        let shadowAngle = highlightAngle + .pi
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        drawFrostedFill(in: context, rect: rect, center: center, radius: radius, lightVector: lightVector, opacity: opacity, activation: activation, intensity: intensity)
        drawGlassSheen(in: context, rect: rect, center: center, radius: radius, lightVector: lightVector, opacity: opacity, activation: activation, intensity: intensity)

        context.saveGState()
        context.setLineWidth(1.2)
        context.setStrokeColor(glassHighlight(alpha: min((0.28 + activation * 0.06) * opacity * (0.92 + intensity * 0.10), 0.48)).cgColor)
        context.addEllipse(in: rect.insetBy(dx: 0.4, dy: 0.4))
        context.strokePath()
        context.restoreGState()

        context.saveGState()
        context.setLineCap(.round)
        context.setLineWidth(1.4)
        context.setStrokeColor(glassHighlight(alpha: min((0.20 + activation * 0.08) * opacity * (0.92 + intensity * 0.12), 0.42)).cgColor)
        context.addArc(
            center: CGPoint(
                x: center.x + lightVector.x * reflectionTravel * 0.26,
                y: center.y + lightVector.y * reflectionTravel * 0.26
            ),
            radius: radius - 1.2,
            startAngle: highlightAngle - .pi * 0.22,
            endAngle: highlightAngle + .pi * 0.22,
            clockwise: false
        )
        context.strokePath()
        context.restoreGState()

        context.saveGState()
        context.setLineCap(.round)
        context.setLineWidth(0.9)
        context.setStrokeColor(glassShadow(alpha: min((0.026 + activation * 0.018) * opacity * (0.78 + intensity * 0.12), 0.075)).cgColor)
        context.addArc(
            center: CGPoint(
                x: center.x - lightVector.x * reflectionTravel * 0.45,
                y: center.y - lightVector.y * reflectionTravel * 0.45
            ),
            radius: radius - 0.5,
            startAngle: shadowAngle - .pi * 0.20,
            endAngle: shadowAngle + .pi * 0.20,
            clockwise: false
        )
        context.strokePath()
        context.restoreGState()
    }

    private func drawFrostedFill(in context: CGContext, rect: CGRect, center: CGPoint, radius: CGFloat, lightVector: CGPoint, opacity: CGFloat, activation: CGFloat, intensity: CGFloat) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            glassHighlight(alpha: min((0.16 + activation * 0.040) * opacity * (0.92 + intensity * 0.12), 0.31)).cgColor,
            glassHighlight(alpha: min((0.070 + activation * 0.018) * opacity * (0.90 + intensity * 0.10), 0.16)).cgColor,
            aeroRefraction(alpha: min((0.018 + activation * 0.014) * opacity * (0.80 + intensity * 0.16), 0.055)).cgColor
        ] as CFArray
        let locations: [CGFloat] = [0, 0.58, 1]

        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else {
            return
        }

        context.saveGState()
        context.addEllipse(in: rect.insetBy(dx: 1.5, dy: 1.5))
        context.clip()
        context.drawLinearGradient(
            gradient,
            start: CGPoint(
                x: center.x + lightVector.x * radius,
                y: center.y + lightVector.y * radius
            ),
            end: CGPoint(
                x: center.x - lightVector.x * radius * 0.80,
                y: center.y - lightVector.y * radius * 0.80
            ),
            options: []
        )
        context.restoreGState()
    }

    private func drawGlassSheen(in context: CGContext, rect: CGRect, center: CGPoint, radius: CGFloat, lightVector: CGPoint, opacity: CGFloat, activation: CGFloat, intensity: CGFloat) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            glassHighlight(alpha: min((0.24 + activation * 0.08) * opacity * (0.86 + intensity * 0.18), 0.52)).cgColor,
            glassHighlight(alpha: min((0.080 + activation * 0.035) * opacity * (0.86 + intensity * 0.16), 0.24)).cgColor,
            aeroRefraction(alpha: min((0.018 + activation * 0.018) * opacity * (0.75 + intensity * 0.14), 0.070)).cgColor
        ] as CFArray
        let locations: [CGFloat] = [0, 0.46, 1]

        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else {
            return
        }

        context.saveGState()
        context.addEllipse(in: rect.insetBy(dx: 3, dy: 3))
        context.clip()
        context.setBlendMode(.screen)
        context.drawLinearGradient(
            gradient,
            start: CGPoint(
                x: center.x + lightVector.x * radius * 0.95,
                y: center.y + lightVector.y * radius * 0.95
            ),
            end: CGPoint(
                x: center.x - lightVector.x * radius * 0.45,
                y: center.y - lightVector.y * radius * 0.45
            ),
            options: []
        )
        context.restoreGState()
    }

    private func drawMovingDot(in context: CGContext, deltaX: CGFloat, deltaY: CGFloat, distance: CGFloat, opacity: CGFloat, intensity: CGFloat) {
        let effectiveDistance = max(distance - deadZoneRadius, 0)
        let travel = min(effectiveDistance * (0.55 + intensity * 0.07), bounds.width * 0.25)
        let unitX = distance > 0 ? deltaX / distance : 0
        let unitY = distance > 0 ? deltaY / distance : 0
        let dot = CGPoint(
            x: originPoint.x + unitX * travel,
            y: originPoint.y + unitY * travel
        )
        let dotRadius = min(max(bounds.width * 0.074, 4.0), 10.0)
        let squash = SettingsManager.shared.visualizerAnimationsEnabled ? dotSquash : .none
        let dotScale = ScrollOverlayMotion.dotScale(for: squash)
        let dotRect = CGRect(
            x: dot.x - dotRadius * dotScale.width,
            y: dot.y - dotRadius * dotScale.height,
            width: dotRadius * 2 * dotScale.width,
            height: dotRadius * 2 * dotScale.height
        )
        let gradientRadius = max(dotRect.width, dotRect.height) / 2

        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -1.2), blur: 6 + intensity * 1.6, color: glassShadow(alpha: min(0.090 * opacity * (0.85 + intensity * 0.12), 0.17)).cgColor)
        context.setFillColor(glassFill(alpha: min(0.18 * opacity * (0.88 + intensity * 0.10), 0.30)).cgColor)
        context.addEllipse(in: dotRect)
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addEllipse(in: dotRect)
        context.clip()

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            glassFill(alpha: min(0.82 * opacity * (0.96 + intensity * 0.06), 0.92)).cgColor,
            glassFill(alpha: min(0.54 * opacity * (0.92 + intensity * 0.08), 0.76)).cgColor,
            aeroRefraction(alpha: min(0.18 * opacity * (0.80 + intensity * 0.12), 0.28)).cgColor
        ] as CFArray
        let locations: [CGFloat] = [0, 0.62, 1]

        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
            context.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: dot.x - gradientRadius * 0.28, y: dot.y + gradientRadius * 0.32),
                startRadius: 0,
                endCenter: dot,
                endRadius: gradientRadius * 1.18,
                options: []
            )
        }
        context.restoreGState()

        context.saveGState()
        context.setLineWidth(0.85)
        context.setStrokeColor(glassHighlight(alpha: min(0.45 * opacity * (0.90 + intensity * 0.08), 0.58)).cgColor)
        context.addEllipse(in: dotRect.insetBy(dx: 0.35, dy: 0.35))
        context.strokePath()
        context.setLineWidth(0.55)
        context.setStrokeColor(glassShadow(alpha: min(0.035 * opacity * (0.85 + intensity * 0.10), 0.070)).cgColor)
        context.addEllipse(in: dotRect.insetBy(dx: 0.15, dy: 0.15))
        context.strokePath()
        context.restoreGState()
    }

    private func drawClickRipple(in context: CGContext, opacity: CGFloat, intensity: CGFloat) {
        guard SettingsManager.shared.visualizerAnimationsEnabled,
              let clickRippleStartTime else {
            return
        }

        let elapsed = CACurrentMediaTime() - clickRippleStartTime
        let progress = CGFloat(elapsed / Style.clickRippleDuration)

        guard progress < 1 else {
            self.clickRippleStartTime = nil
            return
        }

        let easedProgress = 1 - pow(1 - progress, 3)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = bounds.width * (0.14 + easedProgress * 0.30)
        let fade = pow(1 - progress, 1.28)

        context.saveGState()
        context.setLineCap(.round)
        context.setLineWidth(1.4 + (1 - progress) * 1.25)
        context.setStrokeColor(glassHighlight(alpha: min(fade * opacity * (0.34 + intensity * 0.075), 0.56)).cgColor)
        context.addEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        context.strokePath()
        context.restoreGState()

        context.saveGState()
        context.setLineWidth(0.95)
        context.setStrokeColor(aeroRefraction(alpha: min(fade * opacity * (0.13 + intensity * 0.036), 0.27)).cgColor)
        let innerRadius = radius * 0.72
        context.addEllipse(in: CGRect(
            x: center.x - innerRadius,
            y: center.y - innerRadius,
            width: innerRadius * 2,
            height: innerRadius * 2
        ))
        context.strokePath()
        context.restoreGState()
    }

    private func updateMotionEffects(to point: CGPoint) {
        guard SettingsManager.shared.visualizerAnimationsEnabled else {
            resetMotionEffects()
            return
        }

        let now = CACurrentMediaTime()
        defer { lastMotionTime = now }

        guard let lastMotionTime else {
            return
        }

        let deltaTime = max(now - lastMotionTime, 1.0 / 240.0)
        let velocity = CGPoint(
            x: (point.x - currentScreenPoint.x) / deltaTime,
            y: (point.y - currentScreenPoint.y) / deltaTime
        )
        let squash = ScrollOverlayMotion.flickSquash(
            previousVelocity: lastVelocity,
            currentVelocity: velocity,
            liquidGlassIntensity: CGFloat(SettingsManager.shared.liquidGlassIntensity)
        )

        if squash.amount > dotSquash.amount {
            dotSquash = squash
            startSquashDecayTimer()
        }

        lastVelocity = velocity
    }

    private func resetMotionEffects() {
        lastMotionTime = nil
        lastVelocity = .zero
        dotSquash = .none
        squashDecayTimer?.invalidate()
        squashDecayTimer = nil
    }

    private func startSquashDecayTimer() {
        guard squashDecayTimer == nil else { return }

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            guard SettingsManager.shared.visualizerAnimationsEnabled else {
                self.resetMotionEffects()
                self.needsDisplay = true
                return
            }

            self.dotSquash = ScrollOverlaySquash(
                amount: self.dotSquash.amount * 0.82,
                axis: self.dotSquash.axis
            )

            if self.dotSquash.amount < 0.006 {
                self.dotSquash = .none
                timer.invalidate()
                self.squashDecayTimer = nil
            }

            self.needsDisplay = true
        }

        squashDecayTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func startClickRippleTimer() {
        clickRippleTimer?.invalidate()

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            guard let clickRippleStartTime = self.clickRippleStartTime,
                  SettingsManager.shared.visualizerAnimationsEnabled else {
                self.clickRippleStartTime = nil
                timer.invalidate()
                self.clickRippleTimer = nil
                self.needsDisplay = true
                return
            }

            if CACurrentMediaTime() - clickRippleStartTime >= Style.clickRippleDuration {
                self.clickRippleStartTime = nil
                timer.invalidate()
                self.clickRippleTimer = nil
            }

            self.needsDisplay = true
        }

        clickRippleTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }

    private func normalized(x: CGFloat, y: CGFloat) -> CGPoint {
        let length = sqrt(x * x + y * y)
        guard length > 0 else {
            return CGPoint(x: -0.56, y: 0.83)
        }

        return CGPoint(x: x / length, y: y / length)
    }

    private func glassFill(alpha: CGFloat) -> NSColor {
        NSColor.white.withAlphaComponent(alpha)
    }

    private func glassHighlight(alpha: CGFloat) -> NSColor {
        NSColor.white.withAlphaComponent(alpha)
    }

    private func aeroRefraction(alpha: CGFloat) -> NSColor {
        NSColor(calibratedRed: 0.70, green: 0.92, blue: 1.0, alpha: alpha)
    }

    private func glassShadow(alpha: CGFloat) -> NSColor {
        NSColor.black.withAlphaComponent(alpha)
    }
}
