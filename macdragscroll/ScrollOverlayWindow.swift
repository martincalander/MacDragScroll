//
//  ScrollOverlayWindow.swift
//  macdragscroll
//
//  Created by Martin Calander on 2026-01-16.
//

import AppKit
import QuartzCore

class ScrollOverlayWindow: NSWindow {
    private let overlayView: ScrollOverlayView
    private let originPoint: CGPoint
    
    init(origin: CGPoint) {
        // Get the screen containing the origin point
        let screen = NSScreen.screens.first { NSMouseInRect(origin, $0.frame, false) } ?? NSScreen.main!
        let screenFrame = screen.frame
        
        self.originPoint = origin
        self.overlayView = ScrollOverlayView(origin: origin, screenFrame: screenFrame)
        
        super.init(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.contentView = overlayView
        
        // Start hidden for fade in
        self.alphaValue = 0
    }
    
    func show() {
        orderFrontRegardless()
        
        let animationsEnabled = SettingsManager.shared.animationsEnabled
        
        if animationsEnabled {
            // Start with scale down
            overlayView.setScale(0.6)
            self.alphaValue = 0
            
            // Animate fade in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.animator().alphaValue = SettingsManager.shared.overlayOpacity
            }
            
            // Bouncy spring animation for scale
            overlayView.animateBounceIn()
        } else {
            self.alphaValue = SettingsManager.shared.overlayOpacity
        }
    }
    
    func hide() {
        let animationsEnabled = SettingsManager.shared.animationsEnabled
        
        if animationsEnabled {
            // Animate scale down
            overlayView.animateBounceOut()
            
            // Fade out
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.08
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                self.animator().alphaValue = 0
            }, completionHandler: {
                self.orderOut(nil)
                self.alphaValue = 0
            })
        } else {
            orderOut(nil)
        }
    }
    
    func updateArrow(to current: CGPoint) {
        overlayView.updateArrow(to: current)
    }
    
    func animateClickBounce() {
        guard SettingsManager.shared.animationsEnabled else { return }
        overlayView.animateClickBounce()
    }
    
    func setPaused(_ paused: Bool) {
        let targetOpacity = paused ? SettingsManager.shared.overlayOpacity * 0.3 : SettingsManager.shared.overlayOpacity
        
        if SettingsManager.shared.animationsEnabled {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().alphaValue = targetOpacity
            }
        } else {
            self.alphaValue = targetOpacity
        }
    }
}

class ScrollOverlayView: NSView {
    private let originScreen: CGPoint  // Origin in screen coordinates
    private var currentScreen: CGPoint // Current in screen coordinates
    private let screenFrame: CGRect
    private let centerDotRadius: CGFloat = 10
    private var deadZoneRadius: CGFloat { CGFloat(SettingsManager.shared.deadZoneRadius) }
    
    // For scale animation - we'll use a container layer
    private var containerLayer: CALayer!
    private var drawingLayer: CALayer!
    private var currentScale: CGFloat = 1.0
    
    init(origin: CGPoint, screenFrame: CGRect) {
        self.originScreen = origin
        self.currentScreen = origin
        self.screenFrame = screenFrame
        super.init(frame: NSRect(origin: .zero, size: screenFrame.size))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupLayers() {
        // Create container layer for transform animations
        let container = CALayer()
        container.frame = bounds
        
        // Set anchor point at the origin point location
        let viewOrigin = screenToView(originScreen)
        let anchorX = viewOrigin.x / bounds.width
        let anchorY = viewOrigin.y / bounds.height
        container.anchorPoint = CGPoint(x: anchorX, y: anchorY)
        container.position = viewOrigin
        
        layer?.addSublayer(container)
        containerLayer = container
    }
    
    func setScale(_ scale: CGFloat) {
        currentScale = scale
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        containerLayer?.transform = CATransform3DMakeScale(scale, scale, 1)
        CATransaction.commit()
    }
    
    func animateBounceIn() {
        guard let container = containerLayer else { return }
        
        let animation = CASpringAnimation(keyPath: "transform.scale")
        animation.fromValue = 0.6
        animation.toValue = 1.0
        animation.damping = 14
        animation.stiffness = 280
        animation.mass = 0.8
        animation.initialVelocity = 8
        animation.duration = animation.settlingDuration
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        container.transform = CATransform3DIdentity
        CATransaction.commit()
        
        container.add(animation, forKey: "bounceIn")
        currentScale = 1.0
    }
    
    func animateBounceOut() {
        guard let container = containerLayer else { return }
        
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 1.0
        animation.toValue = 0.85
        animation.duration = 0.08
        animation.timingFunction = CAMediaTimingFunction(name: .easeIn)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        
        container.add(animation, forKey: "bounceOut")
    }
    
    func animateClickBounce() {
        guard let container = containerLayer else { return }
        
        // Quick squeeze and bounce back
        let animation = CAKeyframeAnimation(keyPath: "transform.scale")
        animation.values = [1.0, 0.88, 1.08, 0.97, 1.0]
        animation.keyTimes = [0, 0.15, 0.4, 0.7, 1.0]
        animation.duration = 0.25
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        container.add(animation, forKey: "clickBounce")
    }
    
    // Convert screen coordinates to view coordinates
    private func screenToView(_ point: CGPoint) -> CGPoint {
        return CGPoint(
            x: point.x - screenFrame.origin.x,
            y: point.y - screenFrame.origin.y
        )
    }
    
    func updateArrow(to point: CGPoint) {
        currentScreen = point
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let opacity = CGFloat(SettingsManager.shared.overlayOpacity)
        
        // Convert to view coordinates
        let viewOrigin = screenToView(originScreen)
        let viewCurrent = screenToView(currentScreen)
        
        let deltaX = viewCurrent.x - viewOrigin.x
        let deltaY = viewCurrent.y - viewOrigin.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        
        // Draw dead zone circle
        context.setStrokeColor(NSColor.gray.withAlphaComponent(0.4 * opacity).cgColor)
        context.setLineWidth(1.5)
        context.addEllipse(in: CGRect(
            x: viewOrigin.x - deadZoneRadius,
            y: viewOrigin.y - deadZoneRadius,
            width: deadZoneRadius * 2,
            height: deadZoneRadius * 2
        ))
        context.strokePath()
        
        // Draw center dot with shadow
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -1), blur: 4, color: NSColor.black.withAlphaComponent(0.5 * opacity).cgColor)
        context.setFillColor(NSColor.white.withAlphaComponent(opacity).cgColor)
        context.addEllipse(in: CGRect(
            x: viewOrigin.x - centerDotRadius,
            y: viewOrigin.y - centerDotRadius,
            width: centerDotRadius * 2,
            height: centerDotRadius * 2
        ))
        context.fillPath()
        context.restoreGState()
        
        // Draw inner blue dot
        let innerRadius = centerDotRadius - 3
        context.setFillColor(NSColor.systemBlue.withAlphaComponent(opacity).cgColor)
        context.addEllipse(in: CGRect(
            x: viewOrigin.x - innerRadius,
            y: viewOrigin.y - innerRadius,
            width: innerRadius * 2,
            height: innerRadius * 2
        ))
        context.fillPath()
        
        // Draw directional arrow if outside dead zone
        if distance > deadZoneRadius {
            let normalizedX = deltaX / distance
            let normalizedY = deltaY / distance
            
            drawDirectionArrow(context: context, at: viewOrigin, dirX: normalizedX, dirY: normalizedY)
        }
    }
    
    private func drawDirectionArrow(context: CGContext, at center: CGPoint, dirX: CGFloat, dirY: CGFloat) {
        let opacity = CGFloat(SettingsManager.shared.overlayOpacity)
        let arrowDistance = deadZoneRadius + 12
        
        // Arrow tip position
        let tipX = center.x + dirX * arrowDistance
        let tipY = center.y + dirY * arrowDistance
        
        // Perpendicular for wings
        let perpX = -dirY
        let perpY = dirX
        
        let wingLength: CGFloat = 7
        let wingBack: CGFloat = 10
        
        let tip = CGPoint(x: tipX, y: tipY)
        let leftWing = CGPoint(
            x: tipX - dirX * wingBack + perpX * wingLength,
            y: tipY - dirY * wingBack + perpY * wingLength
        )
        let rightWing = CGPoint(
            x: tipX - dirX * wingBack - perpX * wingLength,
            y: tipY - dirY * wingBack - perpY * wingLength
        )
        
        // Draw arrow with shadow
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -1), blur: 3, color: NSColor.black.withAlphaComponent(0.4 * opacity).cgColor)
        context.setFillColor(NSColor.white.withAlphaComponent(opacity).cgColor)
        
        context.move(to: tip)
        context.addLine(to: leftWing)
        context.addLine(to: rightWing)
        context.closePath()
        context.fillPath()
        context.restoreGState()
    }
}

