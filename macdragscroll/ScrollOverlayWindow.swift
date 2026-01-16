//
//  ScrollOverlayWindow.swift
//  macdragscroll
//
//  Created by Martin Calander on 2026-01-16.
//

import AppKit

class ScrollOverlayWindow: NSWindow {
    private let overlayView: ScrollOverlayView
    
    init(origin: CGPoint) {
        // Get the screen containing the origin point
        let screen = NSScreen.screens.first { NSMouseInRect(origin, $0.frame, false) } ?? NSScreen.main!
        let screenFrame = screen.frame
        
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
    }
    
    func show() {
        orderFrontRegardless()
    }
    
    func hide() {
        orderOut(nil)
    }
    
    func updateArrow(to current: CGPoint) {
        overlayView.updateArrow(to: current)
    }
}

class ScrollOverlayView: NSView {
    private let originScreen: CGPoint  // Origin in screen coordinates
    private var currentScreen: CGPoint // Current in screen coordinates
    private let screenFrame: CGRect
    private let centerDotRadius: CGFloat = 10
    private let deadZoneRadius: CGFloat = 20
    
    init(origin: CGPoint, screenFrame: CGRect) {
        self.originScreen = origin
        self.currentScreen = origin
        self.screenFrame = screenFrame
        super.init(frame: NSRect(origin: .zero, size: screenFrame.size))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        
        // Convert to view coordinates
        let viewOrigin = screenToView(originScreen)
        let viewCurrent = screenToView(currentScreen)
        
        let deltaX = viewCurrent.x - viewOrigin.x
        let deltaY = viewCurrent.y - viewOrigin.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        
        // Draw dead zone circle
        context.setStrokeColor(NSColor.gray.withAlphaComponent(0.4).cgColor)
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
        context.setShadow(offset: CGSize(width: 0, height: -1), blur: 4, color: NSColor.black.withAlphaComponent(0.5).cgColor)
        context.setFillColor(NSColor.white.cgColor)
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
        context.setFillColor(NSColor.systemBlue.cgColor)
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
        context.setShadow(offset: CGSize(width: 0, height: -1), blur: 3, color: NSColor.black.withAlphaComponent(0.4).cgColor)
        context.setFillColor(NSColor.white.cgColor)
        
        context.move(to: tip)
        context.addLine(to: leftWing)
        context.addLine(to: rightWing)
        context.closePath()
        context.fillPath()
        context.restoreGState()
    }
}
