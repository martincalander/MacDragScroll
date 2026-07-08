//
//  ScrollCalculationTests.swift
//  macdragscrollTests
//
//  Created by Martin Calander on 2026-01-17.
//

import XCTest
@testable import macdragscroll

/// Helper struct for testing scroll calculations without requiring mouse events
struct ScrollCalculator {
    let scrollSpeed: Double
    let deadZoneRadius: Double
    let acceleration: Double
    var reversesDirection = false
    
    /// Calculate the distance between two points
    func calculateDistance(from origin: CGPoint, to current: CGPoint) -> Double {
        ScrollPhysics.distance(from: origin, to: current)
    }
    
    /// Check if point is within dead zone
    func isInDeadZone(from origin: CGPoint, to current: CGPoint) -> Bool {
        ScrollPhysics.isInDeadZone(from: origin, to: current, deadZoneRadius: deadZoneRadius)
    }
    
    /// Calculate scroll intensity for a given distance
    func calculateScrollIntensity(distance: Double) -> Double {
        ScrollPhysics.intensity(
            distance: distance,
            deadZoneRadius: deadZoneRadius,
            acceleration: acceleration,
            scrollSpeed: scrollSpeed
        )
    }
    
    /// Calculate normalized direction vector
    func calculateDirection(from origin: CGPoint, to current: CGPoint) -> (x: Double, y: Double) {
        ScrollPhysics.direction(from: origin, to: current)
    }
    
    /// Calculate scroll deltas (what would be sent to CGEvent)
    func calculateScrollDeltas(from origin: CGPoint, to current: CGPoint) -> (deltaX: Int32, deltaY: Int32) {
        let deltas = ScrollPhysics.deltas(
            from: origin,
            to: current,
            scrollSpeed: scrollSpeed,
            deadZoneRadius: deadZoneRadius,
            acceleration: acceleration,
            reversesDirection: reversesDirection
        )

        return (deltas.horizontal, deltas.vertical)
    }
}

// MARK: - Distance Calculation Tests

final class DistanceCalculationTests: XCTestCase {
    
    let calculator = ScrollCalculator(
        scrollSpeed: 2.0,
        deadZoneRadius: 20.0,
        acceleration: 1.8
    )
    
    func testDistanceHorizontal() {
        let origin = CGPoint(x: 100, y: 100)
        let current = CGPoint(x: 150, y: 100)
        
        let distance = calculator.calculateDistance(from: origin, to: current)
        XCTAssertEqual(distance, 50.0, accuracy: 0.001)
    }
    
    func testDistanceVertical() {
        let origin = CGPoint(x: 100, y: 100)
        let current = CGPoint(x: 100, y: 160)
        
        let distance = calculator.calculateDistance(from: origin, to: current)
        XCTAssertEqual(distance, 60.0, accuracy: 0.001)
    }
    
    func testDistanceDiagonal345Triangle() {
        let origin = CGPoint(x: 0, y: 0)
        let current = CGPoint(x: 30, y: 40)  // 3-4-5 triangle scaled by 10
        
        let distance = calculator.calculateDistance(from: origin, to: current)
        XCTAssertEqual(distance, 50.0, accuracy: 0.001)
    }
    
    func testDistanceZeroWhenSamePoint() {
        let point = CGPoint(x: 100, y: 100)
        
        let distance = calculator.calculateDistance(from: point, to: point)
        XCTAssertEqual(distance, 0.0, accuracy: 0.001)
    }
    
    func testDistanceNegativeMovement() {
        let origin = CGPoint(x: 100, y: 100)
        let current = CGPoint(x: 50, y: 50)  // Move left and down
        
        let distance = calculator.calculateDistance(from: origin, to: current)
        let expected = sqrt(50.0 * 50.0 + 50.0 * 50.0)  // ~70.71
        XCTAssertEqual(distance, expected, accuracy: 0.001)
    }
}

// MARK: - Dead Zone Tests

final class DeadZoneTests: XCTestCase {
    
    let calculator = ScrollCalculator(
        scrollSpeed: 2.0,
        deadZoneRadius: 20.0,
        acceleration: 1.8
    )
    
    func testPointInsideDeadZone() {
        let origin = CGPoint(x: 100, y: 100)
        let current = CGPoint(x: 110, y: 100)  // 10px away, dead zone is 20px
        
        XCTAssertTrue(calculator.isInDeadZone(from: origin, to: current))
    }
    
    func testPointOutsideDeadZone() {
        let origin = CGPoint(x: 100, y: 100)
        let current = CGPoint(x: 150, y: 100)  // 50px away, dead zone is 20px
        
        XCTAssertFalse(calculator.isInDeadZone(from: origin, to: current))
    }
    
    func testPointExactlyOnDeadZoneBoundary() {
        let origin = CGPoint(x: 100, y: 100)
        let current = CGPoint(x: 120, y: 100)  // Exactly 20px away
        
        XCTAssertTrue(calculator.isInDeadZone(from: origin, to: current), "Points on boundary should be considered inside")
    }
    
    func testPointJustOutsideDeadZone() {
        let origin = CGPoint(x: 100, y: 100)
        let current = CGPoint(x: 121, y: 100)  // 21px away
        
        XCTAssertFalse(calculator.isInDeadZone(from: origin, to: current))
    }
    
    func testDifferentDeadZoneSizes() {
        let smallDeadZone = ScrollCalculator(scrollSpeed: 2.0, deadZoneRadius: 5.0, acceleration: 1.8)
        let largeDeadZone = ScrollCalculator(scrollSpeed: 2.0, deadZoneRadius: 50.0, acceleration: 1.8)
        
        let origin = CGPoint(x: 100, y: 100)
        let current = CGPoint(x: 130, y: 100)  // 30px away
        
        XCTAssertFalse(smallDeadZone.isInDeadZone(from: origin, to: current), "30px should be outside 5px dead zone")
        XCTAssertTrue(largeDeadZone.isInDeadZone(from: origin, to: current), "30px should be inside 50px dead zone")
    }
}

// MARK: - Scroll Intensity Tests

final class ScrollIntensityTests: XCTestCase {
    
    let calculator = ScrollCalculator(
        scrollSpeed: 2.0,
        deadZoneRadius: 20.0,
        acceleration: 1.8
    )
    
    func testIntensityZeroInsideDeadZone() {
        let intensity = calculator.calculateScrollIntensity(distance: 10.0)
        XCTAssertEqual(intensity, 0.0, accuracy: 0.001)
    }
    
    func testIntensityZeroExactlyAtDeadZone() {
        let intensity = calculator.calculateScrollIntensity(distance: 20.0)
        XCTAssertEqual(intensity, 0.0, accuracy: 0.001, "Intensity should be zero at dead zone boundary")
    }
    
    func testIntensityIncreasesWithDistance() {
        let intensity30 = calculator.calculateScrollIntensity(distance: 30.0)
        let intensity50 = calculator.calculateScrollIntensity(distance: 50.0)
        let intensity100 = calculator.calculateScrollIntensity(distance: 100.0)
        
        XCTAssertGreaterThan(intensity50, intensity30)
        XCTAssertGreaterThan(intensity100, intensity50)
    }
    
    func testIntensityIsCapped() {
        // Very large distance should be capped at max
        let intensity = calculator.calculateScrollIntensity(distance: 1000.0)
        let maxIntensity = 50.0 * calculator.scrollSpeed
        
        XCTAssertLessThanOrEqual(intensity, maxIntensity + 0.001)
    }
    
    func testIntensityPositiveJustOutsideDeadZone() {
        let intensity = calculator.calculateScrollIntensity(distance: 21.0)
        XCTAssertGreaterThan(intensity, 0.0, "Intensity should be positive just outside dead zone")
    }
}

// MARK: - Direction Tests

final class DirectionTests: XCTestCase {
    
    let calculator = ScrollCalculator(
        scrollSpeed: 2.0,
        deadZoneRadius: 20.0,
        acceleration: 1.8
    )
    
    func testDirectionRight() {
        let origin = CGPoint(x: 100, y: 100)
        let current = CGPoint(x: 200, y: 100)
        
        let direction = calculator.calculateDirection(from: origin, to: current)
        XCTAssertEqual(direction.x, 1.0, accuracy: 0.001)
        XCTAssertEqual(direction.y, 0.0, accuracy: 0.001)
    }
    
    func testDirectionLeft() {
        let origin = CGPoint(x: 100, y: 100)
        let current = CGPoint(x: 0, y: 100)
        
        let direction = calculator.calculateDirection(from: origin, to: current)
        XCTAssertEqual(direction.x, -1.0, accuracy: 0.001)
        XCTAssertEqual(direction.y, 0.0, accuracy: 0.001)
    }
    
    func testDirectionUp() {
        let origin = CGPoint(x: 100, y: 100)
        let current = CGPoint(x: 100, y: 200)
        
        let direction = calculator.calculateDirection(from: origin, to: current)
        XCTAssertEqual(direction.x, 0.0, accuracy: 0.001)
        XCTAssertEqual(direction.y, 1.0, accuracy: 0.001)
    }
    
    func testDirectionDown() {
        let origin = CGPoint(x: 100, y: 100)
        let current = CGPoint(x: 100, y: 0)
        
        let direction = calculator.calculateDirection(from: origin, to: current)
        XCTAssertEqual(direction.x, 0.0, accuracy: 0.001)
        XCTAssertEqual(direction.y, -1.0, accuracy: 0.001)
    }
    
    func testDirectionDiagonal() {
        let origin = CGPoint(x: 0, y: 0)
        let current = CGPoint(x: 100, y: 100)
        
        let direction = calculator.calculateDirection(from: origin, to: current)
        let expected = 1.0 / sqrt(2.0)  // ~0.707
        XCTAssertEqual(direction.x, expected, accuracy: 0.001)
        XCTAssertEqual(direction.y, expected, accuracy: 0.001)
    }
    
    func testDirectionZeroWhenSamePoint() {
        let point = CGPoint(x: 100, y: 100)
        
        let direction = calculator.calculateDirection(from: point, to: point)
        XCTAssertEqual(direction.x, 0.0, accuracy: 0.001)
        XCTAssertEqual(direction.y, 0.0, accuracy: 0.001)
    }
    
    func testDirectionIsNormalized() {
        let origin = CGPoint(x: 0, y: 0)
        let current = CGPoint(x: 30, y: 40)
        
        let direction = calculator.calculateDirection(from: origin, to: current)
        let magnitude = sqrt(direction.x * direction.x + direction.y * direction.y)
        
        XCTAssertEqual(magnitude, 1.0, accuracy: 0.001, "Direction vector should be normalized")
    }
}

// MARK: - Scroll Delta Tests

final class ScrollDeltaTests: XCTestCase {
    
    let calculator = ScrollCalculator(
        scrollSpeed: 2.0,
        deadZoneRadius: 20.0,
        acceleration: 1.8
    )
    
    func testDeltasZeroInsideDeadZone() {
        let origin = CGPoint(x: 100, y: 100)
        let current = CGPoint(x: 105, y: 105)
        
        let deltas = calculator.calculateScrollDeltas(from: origin, to: current)
        XCTAssertEqual(deltas.deltaX, 0)
        XCTAssertEqual(deltas.deltaY, 0)
    }
    
    func testDeltasNonZeroOutsideDeadZone() {
        let origin = CGPoint(x: 100, y: 100)
        let current = CGPoint(x: 200, y: 100)  // 100px to the right
        
        let deltas = calculator.calculateScrollDeltas(from: origin, to: current)
        XCTAssertNotEqual(deltas.deltaX, 0, "Horizontal delta should be non-zero")
    }
    
    func testDeltasDirectionRight() {
        let origin = CGPoint(x: 100, y: 100)
        let current = CGPoint(x: 200, y: 100)
        
        let deltas = calculator.calculateScrollDeltas(from: origin, to: current)
        XCTAssertGreaterThan(deltas.deltaX, 0, "Moving right should produce positive horizontal wheel delta by default")
    }
    
    func testDeltasDirectionLeft() {
        let origin = CGPoint(x: 100, y: 100)
        let current = CGPoint(x: 0, y: 100)
        
        let deltas = calculator.calculateScrollDeltas(from: origin, to: current)
        XCTAssertLessThan(deltas.deltaX, 0, "Moving left should produce negative horizontal wheel delta by default")
    }
    
    func testDeltasDirectionUp() {
        let origin = CGPoint(x: 100, y: 100)
        let current = CGPoint(x: 100, y: 200)
        
        let deltas = calculator.calculateScrollDeltas(from: origin, to: current)
        XCTAssertGreaterThan(deltas.deltaY, 0, "Moving up should produce positive vertical wheel delta by default")
    }
    
    func testDeltasDirectionDown() {
        let origin = CGPoint(x: 100, y: 100)
        let current = CGPoint(x: 100, y: 0)
        
        let deltas = calculator.calculateScrollDeltas(from: origin, to: current)
        XCTAssertLessThan(deltas.deltaY, 0, "Moving down should produce negative vertical wheel delta by default")
    }
}

// MARK: - Configuration Tests

final class ScrollCalculatorConfigurationTests: XCTestCase {
    
    func testHigherSpeedProducesLargerDeltas() {
        let slowCalculator = ScrollCalculator(scrollSpeed: 1.0, deadZoneRadius: 20.0, acceleration: 1.8)
        let fastCalculator = ScrollCalculator(scrollSpeed: 4.0, deadZoneRadius: 20.0, acceleration: 1.8)
        
        let distance = 100.0
        
        let slowIntensity = slowCalculator.calculateScrollIntensity(distance: distance)
        let fastIntensity = fastCalculator.calculateScrollIntensity(distance: distance)
        
        XCTAssertGreaterThan(fastIntensity, slowIntensity, "Higher speed should produce larger intensity")
        XCTAssertEqual(fastIntensity, slowIntensity * 4.0, accuracy: 0.001, "Intensity should scale linearly with speed")
    }
    
    func testLargerDeadZoneRequiresMoreMovement() {
        let smallDeadZone = ScrollCalculator(scrollSpeed: 2.0, deadZoneRadius: 10.0, acceleration: 1.8)
        let largeDeadZone = ScrollCalculator(scrollSpeed: 2.0, deadZoneRadius: 40.0, acceleration: 1.8)
        
        let origin = CGPoint(x: 100, y: 100)
        let current = CGPoint(x: 130, y: 100)  // 30px away
        
        XCTAssertFalse(smallDeadZone.isInDeadZone(from: origin, to: current), "30px should be outside 10px dead zone")
        XCTAssertTrue(largeDeadZone.isInDeadZone(from: origin, to: current), "30px should be inside 40px dead zone")
    }
    
    func testHigherAccelerationFasterRampUp() {
        let lowAccel = ScrollCalculator(scrollSpeed: 2.0, deadZoneRadius: 20.0, acceleration: 1.0)
        let highAccel = ScrollCalculator(scrollSpeed: 2.0, deadZoneRadius: 20.0, acceleration: 2.5)
        
        let distance = 60.0  // 40px effective distance
        
        let lowIntensity = lowAccel.calculateScrollIntensity(distance: distance)
        let highIntensity = highAccel.calculateScrollIntensity(distance: distance)
        
        // With effectiveDistance/30 > 1, higher acceleration produces higher intensity
        XCTAssertGreaterThan(highIntensity, lowIntensity, "Higher acceleration should produce greater intensity at moderate distances")
    }
    
    func testZeroDeadZone() {
        let noDeadZone = ScrollCalculator(scrollSpeed: 2.0, deadZoneRadius: 0.0, acceleration: 1.8)
        
        let origin = CGPoint(x: 100, y: 100)
        let current = CGPoint(x: 101, y: 100)  // Just 1px away
        
        XCTAssertFalse(noDeadZone.isInDeadZone(from: origin, to: current), "With zero dead zone, even 1px should be outside")
        
        let intensity = noDeadZone.calculateScrollIntensity(distance: 1.0)
        XCTAssertGreaterThan(intensity, 0.0, "Should produce intensity with zero dead zone")
    }
}

// MARK: - Production Scroll Physics Tests

final class ProductionScrollPhysicsTests: XCTestCase {

    func testProductionPhysicsReturnsZeroInsideDeadZone() {
        let deltas = ScrollPhysics.deltas(
            from: CGPoint(x: 100, y: 100),
            to: CGPoint(x: 110, y: 100),
            scrollSpeed: 2.0,
            deadZoneRadius: 20.0,
            acceleration: 1.8,
            reversesDirection: false
        )

        XCTAssertEqual(deltas, ScrollDeltas(horizontal: 0, vertical: 0))
    }

    func testProductionPhysicsUsesDragDirectionByDefault() {
        let right = ScrollPhysics.deltas(
            from: CGPoint(x: 100, y: 100),
            to: CGPoint(x: 220, y: 100),
            scrollSpeed: 2.0,
            deadZoneRadius: 20.0,
            acceleration: 1.8,
            reversesDirection: false
        )

        let left = ScrollPhysics.deltas(
            from: CGPoint(x: 100, y: 100),
            to: CGPoint(x: -20, y: 100),
            scrollSpeed: 2.0,
            deadZoneRadius: 20.0,
            acceleration: 1.8,
            reversesDirection: false
        )

        XCTAssertGreaterThan(right.horizontal, 0)
        XCTAssertLessThan(left.horizontal, 0)
        XCTAssertEqual(right.vertical, 0)
        XCTAssertEqual(left.vertical, 0)
    }

    func testProductionPhysicsCanReverseDirection() {
        let normal = ScrollPhysics.deltas(
            from: CGPoint(x: 100, y: 100),
            to: CGPoint(x: 100, y: 40),
            scrollSpeed: 2.0,
            deadZoneRadius: 20.0,
            acceleration: 1.8,
            reversesDirection: false
        )

        let reversed = ScrollPhysics.deltas(
            from: CGPoint(x: 100, y: 100),
            to: CGPoint(x: 100, y: 40),
            scrollSpeed: 2.0,
            deadZoneRadius: 20.0,
            acceleration: 1.8,
            reversesDirection: true
        )

        XCTAssertLessThan(normal.vertical, 0)
        XCTAssertGreaterThan(reversed.vertical, 0)
        XCTAssertEqual(normal.horizontal, 0)
        XCTAssertEqual(reversed.horizontal, 0)
    }

    func testProductionPhysicsProducesMinimumDeltaJustOutsideDeadZone() {
        let down = ScrollPhysics.deltas(
            from: CGPoint(x: 100, y: 100),
            to: CGPoint(x: 100, y: 78),
            scrollSpeed: 1.0,
            deadZoneRadius: 20.0,
            acceleration: 1.8,
            reversesDirection: false
        )

        XCTAssertEqual(down.horizontal, 0)
        XCTAssertLessThan(down.vertical, 0)
    }

    func testProductionPhysicsSuppressesTinyDiagonalDrift() {
        let mostlyDown = ScrollPhysics.deltas(
            from: CGPoint(x: 100, y: 100),
            to: CGPoint(x: 103, y: 60),
            scrollSpeed: 2.0,
            deadZoneRadius: 20.0,
            acceleration: 1.8,
            reversesDirection: false
        )

        XCTAssertEqual(mostlyDown.horizontal, 0)
        XCTAssertLessThan(mostlyDown.vertical, 0)
    }

    func testProductionPhysicsIntensityScalesWithSpeed() {
        let slow = ScrollPhysics.intensity(distance: 120, deadZoneRadius: 20, acceleration: 1.8, scrollSpeed: 1.0)
        let fast = ScrollPhysics.intensity(distance: 120, deadZoneRadius: 20, acceleration: 1.8, scrollSpeed: 3.0)

        XCTAssertEqual(fast, slow * 3.0, accuracy: 0.001)
    }
}

// MARK: - Scroll Event Tests

final class ScrollEventFactoryTests: XCTestCase {

    func testScrollEventUsesPixelDeltasAtOriginLocation() {
        let location = CGPoint(x: 320, y: 240)
        guard let event = ScrollEventFactory.makeScrollEvent(
            deltas: ScrollDeltas(horizontal: -12, vertical: 24),
            location: location
        ) else {
            return XCTFail("Expected scroll event to be created")
        }

        XCTAssertEqual(event.location, location)
        XCTAssertEqual(event.getIntegerValueField(.eventSourceUserData), ScrollEventFactory.syntheticEventMarker)
        XCTAssertEqual(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1), 24)
        XCTAssertEqual(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2), -12)
        XCTAssertEqual(event.getIntegerValueField(.scrollWheelEventIsContinuous), 1)
        XCTAssertEqual(event.getIntegerValueField(.scrollWheelEventScrollPhase), 0)
    }
}

// MARK: - Overlay Geometry Tests

final class ScrollOverlayGeometryTests: XCTestCase {

    func testCenteredOriginUsesCenteredAnimationAnchor() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let origin = CGPoint(x: 400, y: 300)
        let frame = ScrollOverlayGeometry.windowFrame(for: origin, deadZoneRadius: 20, visibleFrame: visibleFrame)
        let originInWindow = ScrollOverlayGeometry.originInWindow(screenOrigin: origin, windowFrame: frame)
        let anchor = ScrollOverlayGeometry.anchorPoint(originInWindow: originInWindow, windowSize: frame.size)

        XCTAssertEqual(anchor.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(anchor.y, 0.5, accuracy: 0.001)
    }

    func testWindowAddsPaddingAroundCenteredVisualSurface() {
        let deadZoneRadius: CGFloat = 20
        let visualFrame = ScrollOverlayGeometry.visualFrame(deadZoneRadius: deadZoneRadius)
        let windowFrame = ScrollOverlayGeometry.windowFrame(
            for: CGPoint(x: 400, y: 300),
            deadZoneRadius: deadZoneRadius,
            visibleFrame: CGRect(x: 0, y: 0, width: 800, height: 600)
        )

        XCTAssertEqual(visualFrame.width, ScrollOverlayGeometry.sideLength(deadZoneRadius: deadZoneRadius), accuracy: 0.001)
        XCTAssertEqual(windowFrame.width, visualFrame.width + ScrollOverlayGeometry.animationPadding * 2, accuracy: 0.001)
        XCTAssertEqual(visualFrame.midX, windowFrame.width / 2, accuracy: 0.001)
        XCTAssertEqual(visualFrame.midY, windowFrame.height / 2, accuracy: 0.001)
    }

    func testVisualizerSizeScalesVisualSurfaceAndWindow() {
        let deadZoneRadius: CGFloat = 20
        let smallVisualFrame = ScrollOverlayGeometry.visualFrame(deadZoneRadius: deadZoneRadius, visualizerSize: 0.45)
        let largeVisualFrame = ScrollOverlayGeometry.visualFrame(deadZoneRadius: deadZoneRadius, visualizerSize: 1.3)
        let smallWindowFrame = ScrollOverlayGeometry.windowFrame(
            for: CGPoint(x: 400, y: 300),
            deadZoneRadius: deadZoneRadius,
            visualizerSize: 0.45,
            visibleFrame: CGRect(x: 0, y: 0, width: 800, height: 600)
        )
        let largeWindowFrame = ScrollOverlayGeometry.windowFrame(
            for: CGPoint(x: 400, y: 300),
            deadZoneRadius: deadZoneRadius,
            visualizerSize: 1.3,
            visibleFrame: CGRect(x: 0, y: 0, width: 800, height: 600)
        )

        XCTAssertLessThan(smallVisualFrame.width, largeVisualFrame.width)
        XCTAssertLessThan(smallWindowFrame.width, largeWindowFrame.width)
        XCTAssertLessThan(smallVisualFrame.width, 64)
        XCTAssertEqual(smallWindowFrame.midX, largeWindowFrame.midX, accuracy: 0.001)
        XCTAssertEqual(smallWindowFrame.midY, largeWindowFrame.midY, accuracy: 0.001)
    }

    func testEdgeOriginStillUsesCenteredAnimationAnchor() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let origin = CGPoint(x: 12, y: 12)
        let frame = ScrollOverlayGeometry.windowFrame(for: origin, deadZoneRadius: 20, visibleFrame: visibleFrame)
        let originInWindow = ScrollOverlayGeometry.originInWindow(screenOrigin: origin, windowFrame: frame)
        let anchor = ScrollOverlayGeometry.anchorPoint(originInWindow: originInWindow, windowSize: frame.size)

        XCTAssertEqual(originInWindow.x, frame.width / 2, accuracy: 0.001)
        XCTAssertEqual(originInWindow.y, frame.height / 2, accuracy: 0.001)
        XCTAssertEqual(anchor.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(anchor.y, 0.5, accuracy: 0.001)
    }
}
