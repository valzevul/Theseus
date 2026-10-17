import XCTest
@testable import Theseus

final class TheseusStretchAnimatorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TheseusSettings.shared.simulateReduceMotion = false
    }

    override func tearDown() {
        TheseusSettings.shared.simulateReduceMotion = nil
        super.tearDown()
    }

    // MARK: - Configuration

    func testDefaultConfiguration() {
        let config = TheseusStretchConfiguration()
        XCTAssertEqual(config.sizeFactor, 0.35)
        XCTAssertEqual(config.tension, 0.18)
        XCTAssertEqual(config.friction, 0.88)
        XCTAssertEqual(config.stretchLimit, 0.45)
    }

    // MARK: - Initial State

    func testInitialState() {
        let animator = TheseusStretchAnimator()
        XCTAssertEqual(animator.currentStretch.x, 1.0)
        XCTAssertEqual(animator.currentStretch.y, 1.0)
        XCTAssertFalse(animator.isActive)
    }

    // MARK: - Interaction Lifecycle

    func testBeginEndInteraction() {
        let animator = TheseusStretchAnimator()

        animator.beginInteraction()
        XCTAssertTrue(animator.isActive)

        animator.cancelAnimation()
        XCTAssertFalse(animator.isActive)
        XCTAssertEqual(animator.currentStretch.x, 1.0)
        XCTAssertEqual(animator.currentStretch.y, 1.0)
    }

    // MARK: - Reset

    func testResetToNeutral() {
        let animator = TheseusStretchAnimator()
        animator.applyDragVelocity(CGPoint(x: 1000, y: 500))
        animator.resetToNeutral()

        XCTAssertEqual(animator.currentStretch.x, 1.0)
        XCTAssertEqual(animator.currentStretch.y, 1.0)
    }

    func testResetCallsCallback() {
        let animator = TheseusStretchAnimator()
        var callbackStretch: CGPoint?

        animator.stretchDidChange = { stretch in
            callbackStretch = stretch
        }

        animator.resetToNeutral()

        XCTAssertEqual(callbackStretch?.x, 1.0)
        XCTAssertEqual(callbackStretch?.y, 1.0)
    }

    // MARK: - Stretch Constraints

    func testStretchWithinLimits() {
        var config = TheseusStretchConfiguration()
        config.stretchLimit = 0.45
        let animator = TheseusStretchAnimator(configuration: config)

        animator.beginInteraction()
        animator.applyDragVelocity(CGPoint(x: 10000, y: 10000))

        let expectation = expectation(description: "Animation tick")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        // After settling, stretch should return toward neutral (1.0)
        // The spring physics will oscillate but eventually converge
        XCTAssertGreaterThanOrEqual(animator.currentStretch.x, 0.5)
        XCTAssertLessThanOrEqual(animator.currentStretch.x, 1.5)

        animator.cancelAnimation()
    }
}
