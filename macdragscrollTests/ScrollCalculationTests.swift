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
    
    /// Calculate the distance between two points
    func calculateDistance(from origin: CGPoint, to current: CGPoint) -> Double {
        let deltaX = current.x - origin.x
        let deltaY = current.y - origin.y
        return sqrt(deltaX * deltaX + deltaY * deltaY)
    }
    
    /// Check if point is within dead zone
    func isInDeadZone(from origin: CGPoint, to current: CGPoint) -> Bool {
        return calculateDistance(from: origin, to: current) <= deadZoneRadius
    }
    
    /// Calculate scroll intensity for a given distance
    func calculateScrollIntensity(distance: Double) -> Double {
        guard distance > deadZoneRadius else { return 0 }
        
        let effectiveDistance = distance - deadZoneRadius
        let acceleratedDistance = pow(effectiveDistance / 30.0, acceleration)
        return min(acceleratedDistance, 50.0) * scrollSpeed
    }
    
    /// Calculate normalized direction vector
    func calculateDirection(from origin: CGPoint, to current: CGPoint) -> (x: Double, y: Double) {
        let deltaX = current.x - origin.x
        let deltaY = current.y - origin.y
        let distance = calculateDistance(from: origin, to: current)
        
        guard distance > 0 else { return (0, 0) }
        
        return (deltaX / distance, deltaY / distance)
    }
    
    /// Calculate scroll deltas (what would be sent to CGEvent)
    func calculateScrollDeltas(from origin: CGPoint, to current: CGPoint) -> (deltaX: Int32, deltaY: Int32) {
        let distance = calculateDistance(from: origin, to: current)
        guard distance > deadZoneRadius else { return (0, 0) }
        
        let intensity = calculateScrollIntensity(distance: distance)
        let direction = calculateDirection(from: origin, to: current)
        
        let scrollDeltaY = Int32(round(direction.y * intensity))
        let scrollDeltaX = Int32(round(direction.x * intensity))
        
        return (scrollDeltaX, scrollDeltaY)
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
        XCTAssertGreaterThan(deltas.deltaX, 0, "Moving right should produce positive deltaX")
    }
    
    func testDeltasDirectionLeft() {
        let origin = CGPoint(x: 100, y: 100)
        let current = CGPoint(x: 0, y: 100)
        
        let deltas = calculator.calculateScrollDeltas(from: origin, to: current)
        XCTAssertLessThan(deltas.deltaX, 0, "Moving left should produce negative deltaX")
    }
    
    func testDeltasDirectionUp() {
        let origin = CGPoint(x: 100, y: 100)
        let current = CGPoint(x: 100, y: 200)
        
        let deltas = calculator.calculateScrollDeltas(from: origin, to: current)
        XCTAssertGreaterThan(deltas.deltaY, 0, "Moving up should produce positive deltaY")
    }
    
    func testDeltasDirectionDown() {
        let origin = CGPoint(x: 100, y: 100)
        let current = CGPoint(x: 100, y: 0)
        
        let deltas = calculator.calculateScrollDeltas(from: origin, to: current)
        XCTAssertLessThan(deltas.deltaY, 0, "Moving down should produce negative deltaY")
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
