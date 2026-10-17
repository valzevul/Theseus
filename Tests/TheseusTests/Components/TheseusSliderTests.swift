import XCTest
@testable import Theseus

private final class ActionRecorder: NSObject {
    var count = 0
    @objc func fire() { count += 1 }
}

private final class StubPanGestureRecognizer: UIPanGestureRecognizer {
    var stubbedLocation: CGPoint = .zero
    override func location(in view: UIView?) -> CGPoint { stubbedLocation }
}

private final class StubEdgePanGestureRecognizer: UIScreenEdgePanGestureRecognizer {
    var stubbedLocation: CGPoint = .zero
    override func location(in view: UIView?) -> CGPoint { stubbedLocation }
}

final class TheseusSliderTests: XCTestCase {

    override func tearDown() {
        TheseusSettings.shared.simulateReduceMotion = nil
        super.tearDown()
    }

    private func makeLaidOutSlider(width: CGFloat = 300) -> TheseusSlider {
        let slider = TheseusSlider(frame: CGRect(x: 0, y: 0, width: width, height: 44))
        slider.layoutIfNeeded()
        return slider
    }

    private func knobCenterX(_ slider: TheseusSlider) -> CGFloat {
        slider.subviews.first?.frame.midX ?? .nan
    }

    // MARK: - Default Values

    func testDefaultValues() {
        let slider = TheseusSlider()
        XCTAssertEqual(slider.minimumValue, 0.0)
        XCTAssertEqual(slider.maximumValue, 1.0)
        XCTAssertEqual(slider.value, 0.0)
    }

    // MARK: - Value Constraints

    func testValueClamping() {
        let slider = TheseusSlider()
        slider.minimumValue = 0
        slider.maximumValue = 100

        slider.setValue(-10)
        XCTAssertEqual(slider.value, 0)

        slider.setValue(150)
        XCTAssertEqual(slider.value, 100)

        slider.setValue(50)
        XCTAssertEqual(slider.value, 50)
    }

    func testLowerBoundEnforcement() {
        let slider = TheseusSlider()
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.lowerBoundValue = 25

        slider.setValue(10)
        XCTAssertEqual(slider.value, 25)

        slider.setValue(50)
        XCTAssertEqual(slider.value, 50)
    }

    // MARK: - Increase/Decrease

    func testIncreaseDecrease() {
        let slider = TheseusSlider()
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.setValue(50)

        slider.increase()
        XCTAssertEqual(slider.value, 51)

        slider.decrease()
        XCTAssertEqual(slider.value, 50)

        slider.increaseBy(10)
        XCTAssertEqual(slider.value, 60)

        slider.decreaseBy(20)
        XCTAssertEqual(slider.value, 40)
    }

    func testBoundaryBehavior() {
        let slider = TheseusSlider()
        slider.minimumValue = 0
        slider.maximumValue = 100

        slider.setValue(100)
        slider.increase()
        XCTAssertEqual(slider.value, 100)

        slider.setValue(0)
        slider.decrease()
        XCTAssertEqual(slider.value, 0)
    }

    // MARK: - Negative Values

    func testNegativeRange() {
        let slider = TheseusSlider()
        slider.minimumValue = -100
        slider.maximumValue = 100
        slider.setValue(-50)
        XCTAssertEqual(slider.value, -50)
    }

    // MARK: - Intrinsic Content Size

    func testIntrinsicContentSize() {
        let slider = TheseusSlider()
        XCTAssertEqual(slider.intrinsicContentSize.height, 31.0)
    }

    // MARK: - setValue(_:animated:)

    func testSetValueAnimatedReachesEndState() {
        let slider = makeLaidOutSlider()
        let startX = knobCenterX(slider)

        slider.setValue(0.75, animated: true)

        XCTAssertEqual(slider.value, 0.75)
        XCTAssertGreaterThan(knobCenterX(slider), startX)
    }

    func testSetValueAnimatedUnderReduceMotionReachesEndState() {
        TheseusSettings.shared.simulateReduceMotion = true
        let slider = makeLaidOutSlider()
        let startX = knobCenterX(slider)

        slider.setValue(0.75, animated: true)
        slider.layoutIfNeeded()

        XCTAssertEqual(slider.value, 0.75)
        XCTAssertGreaterThan(knobCenterX(slider), startX)
    }

    func testSetValueAnimatedStillClamps() {
        let slider = makeLaidOutSlider()
        slider.setValue(5, animated: true)
        XCTAssertEqual(slider.value, 1)
    }

    // MARK: - Accessibility

    func testAccessibilityElementAndTraits() {
        let slider = TheseusSlider()
        XCTAssertTrue(slider.isAccessibilityElement)
        XCTAssertTrue(slider.accessibilityTraits.contains(.adjustable))
        XCTAssertFalse(slider.accessibilityTraits.contains(.notEnabled))

        slider.isEnabled = false
        XCTAssertTrue(slider.accessibilityTraits.contains(.notEnabled))
        XCTAssertTrue(slider.accessibilityTraits.contains(.adjustable))
    }

    func testAccessibilityValueIsPercentageForContinuousSlider() {
        let slider = TheseusSlider()
        slider.minimumValue = 0
        slider.maximumValue = 200
        slider.setValue(100)

        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        XCTAssertEqual(slider.accessibilityValue, formatter.string(from: 0.5))
    }

    func testAccessibilityValueIsPositionValueForDiscreteSlider() {
        let slider = TheseusSlider()
        slider.minimumValue = 0
        slider.maximumValue = 4
        slider.positionsCount = 5
        slider.setValue(3)

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        XCTAssertEqual(slider.accessibilityValue, formatter.string(from: 3))
    }

    func testHostAccessibilityValueAndLabelWin() {
        let slider = TheseusSlider()
        slider.accessibilityLabel = "Volume"
        slider.accessibilityValue = "Loud"
        XCTAssertEqual(slider.accessibilityLabel, "Volume")
        XCTAssertEqual(slider.accessibilityValue, "Loud")
    }

    func testAccessibilityIncrementDecrementStepsByTenPercent() {
        let slider = makeLaidOutSlider()
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.setValue(50)

        slider.accessibilityIncrement()
        XCTAssertEqual(slider.value, 60, accuracy: 0.0001)
        XCTAssertEqual(slider.accessibilityValue, "60%")

        slider.accessibilityDecrement()
        XCTAssertEqual(slider.value, 50, accuracy: 0.0001)
        XCTAssertEqual(slider.accessibilityValue, "50%")
    }

    func testAccessibilityIncrementStepsOnePositionWhenDiscrete() {
        let slider = makeLaidOutSlider()
        slider.minimumValue = 0
        slider.maximumValue = 4
        slider.positionsCount = 5
        slider.setValue(1)

        slider.accessibilityIncrement()
        XCTAssertEqual(slider.value, 2, accuracy: 0.0001)

        slider.accessibilityDecrement()
        slider.accessibilityDecrement()
        XCTAssertEqual(slider.value, 0, accuracy: 0.0001)
    }

    func testAccessibilityIncrementClampsAndDoesNotFireAtBounds() {
        let slider = makeLaidOutSlider()
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.setValue(100)

        let recorder = ActionRecorder()
        slider.addTarget(recorder, action: #selector(ActionRecorder.fire), for: .valueChanged)

        slider.accessibilityIncrement()
        XCTAssertEqual(slider.value, 100)
        XCTAssertEqual(recorder.count, 0)

        slider.setValue(0)
        slider.accessibilityDecrement()
        XCTAssertEqual(slider.value, 0)
        XCTAssertEqual(recorder.count, 0)
    }

    func testAccessibilityIncrementIgnoredWhenDisabled() {
        let slider = makeLaidOutSlider()
        slider.setValue(0.5)
        slider.isEnabled = false

        slider.accessibilityIncrement()
        XCTAssertEqual(slider.value, 0.5)
    }

    // MARK: - Native Geometry

    func testKnobTrackAndPressedGlassMatchTheNativeSlider() {
        let layout = TheseusSlider.Layout()
        XCTAssertEqual(layout.knobSize.width, 37)
        XCTAssertEqual(layout.knobSize.height, 24)
        XCTAssertEqual(layout.trackHeight, 6)
        XCTAssertEqual(layout.glassSize.width, 57.35 + 4.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(layout.glassSize.height, 37.0 + 4.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(layout.glassCenterOffset.x, 0)
        XCTAssertEqual(layout.glassCenterOffset.y, 0)
        XCTAssertEqual(TheseusSlider().glassMaterial, .sliderKnobGlass)
    }

    func testPressedGlassUsesTheNativeSliderOptics() {
        let chain = TheseusConfiguration.LensChain.sliderKnob
        XCTAssertEqual(chain.backdropWarp, 0)
        XCTAssertEqual(chain.innerRefraction, 11.1)
        XCTAssertEqual(chain.innerRefractionHeight, 6.66)
        XCTAssertEqual(chain.aberration, 0)
        XCTAssertTrue(chain.warpIgnoresShare)
        let layout = TheseusSlider.Layout()
        let band = { (distance: CGFloat) in TheseusSlider.overrun(distance, limit: layout.glassOverrun, resistance: layout.glassOverrunResistance) }
        XCTAssertEqual(band(0.85), 0.6, accuracy: 0.1)
        XCTAssertEqual(band(4.45), 2.54, accuracy: 0.15)
        XCTAssertEqual(band(8.05), 3.98, accuracy: 0.15)
    }

    func testDefaultTrackColorIsATenPercentOverlayInBothAppearances() {
        let slider = TheseusSlider()
        for (style, expectedWhite) in [(UIUserInterfaceStyle.light, CGFloat(0)), (.dark, 1)] {
            let resolved = slider.backColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
            var white: CGFloat = 0
            var alpha: CGFloat = 0
            XCTAssertTrue(resolved.getWhite(&white, alpha: &alpha))
            XCTAssertEqual(white, expectedWhite, accuracy: 0.001)
            XCTAssertEqual(alpha, 0.10, accuracy: 0.001)
        }
    }

    func testKnobTravelIgnoresTheKnobShadowPadding() {
        let slider = makeLaidOutSlider()
        slider.setValue(0)
        slider.layoutIfNeeded()
        XCTAssertEqual(knobCenterX(slider), 18.5, accuracy: 0.01)
        let scale = UIScreen.main.scale
        let knobTop = ((-3.5 * scale).rounded(.up)) / scale
        XCTAssertEqual(slider.subviews.first?.frame.midY ?? .nan, knobTop + 26, accuracy: 0.01)
        slider.setValue(1.0)
        slider.layoutIfNeeded()
        XCTAssertEqual(knobCenterX(slider), slider.bounds.width - 18.5, accuracy: 0.01)
    }

    func testKnobFollowsTheFingerAfterTheNativeSlopAtTheNativeGain() {
        let offset = { (delta: CGFloat) in TheseusSlider.knobOffset(forFingerDelta: delta, travel: 325, width: 362) }
        XCTAssertEqual(offset(0), 0)
        XCTAssertEqual(offset(8), 0)
        XCTAssertEqual(offset(-8), 0)
        XCTAssertEqual(offset(20), 9.0, accuracy: 0.3)
        XCTAssertEqual(offset(60), 44.9, accuracy: 0.3)
        XCTAssertEqual(offset(100), 80.6, accuracy: 0.3)
        XCTAssertEqual(offset(-60), -44.9, accuracy: 0.3)
        XCTAssertEqual(TheseusSlider.knobOffset(forFingerDelta: 30, travel: 100, width: 0), 20)
    }

    // MARK: - Gesture Arbitration

    func testForeignPanInsideKnobIsRefused() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        let slider = makeLaidOutSlider()
        container.addSubview(slider)
        slider.setValue(0.5)
        slider.layoutIfNeeded()

        let pan = StubPanGestureRecognizer()
        container.addGestureRecognizer(pan)
        pan.stubbedLocation = CGPoint(x: knobCenterX(slider), y: 22)

        XCTAssertFalse(slider.gestureRecognizerShouldBegin(pan))
    }

    func testForeignPanOnTrackAwayFromKnobIsAllowed() {
        let slider = makeLaidOutSlider()
        slider.setValue(1.0)
        slider.layoutIfNeeded()

        let pan = StubPanGestureRecognizer()
        pan.stubbedLocation = CGPoint(x: 40, y: 22)

        XCTAssertTrue(slider.gestureRecognizerShouldBegin(pan))
    }

    func testForeignEdgePanInsideIsRefused() {
        let slider = makeLaidOutSlider()
        slider.setValue(0.5)
        slider.layoutIfNeeded()

        let edgePan = StubEdgePanGestureRecognizer()
        edgePan.stubbedLocation = CGPoint(x: 150, y: 22)

        XCTAssertFalse(slider.gestureRecognizerShouldBegin(edgePan))
    }

    func testForeignPanOutsideIsAllowed() {
        let slider = makeLaidOutSlider()

        let pan = StubPanGestureRecognizer()
        pan.stubbedLocation = CGPoint(x: -80, y: -80)

        XCTAssertTrue(slider.gestureRecognizerShouldBegin(pan))
    }

    func testForeignPanIsAllowedWhenDisabled() {
        let slider = makeLaidOutSlider()
        slider.isEnabled = false

        let pan = StubPanGestureRecognizer()
        pan.stubbedLocation = CGPoint(x: 150, y: 22)

        XCTAssertTrue(slider.gestureRecognizerShouldBegin(pan))
    }

    func testForeignNonPanRecognizerIsAllowed() {
        let slider = makeLaidOutSlider()
        let tap = UITapGestureRecognizer()

        XCTAssertTrue(slider.gestureRecognizerShouldBegin(tap))
    }
}
