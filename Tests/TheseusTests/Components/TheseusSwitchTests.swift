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

final class TheseusSwitchTests: XCTestCase {

    override func tearDown() {
        TheseusSettings.shared.simulateReduceMotion = nil
        super.tearDown()
    }

    private func makeLaidOutSwitch() -> TheseusSwitch {
        let switchControl = TheseusSwitch(frame: CGRect(x: 0, y: 0, width: 63, height: 28))
        switchControl.layoutIfNeeded()
        return switchControl
    }

    // MARK: - State Management

    func testDefaultIsOnState() {
        let switchControl = TheseusSwitch()
        XCTAssertFalse(switchControl.isOn)
    }

    func testIsOnCanBeToggled() {
        let switchControl = TheseusSwitch()
        switchControl.isOn = true
        XCTAssertTrue(switchControl.isOn)
        switchControl.isOn = false
        XCTAssertFalse(switchControl.isOn)
    }

    func testSetOnAnimated() {
        let switchControl = TheseusSwitch()
        switchControl.setOn(true, animated: true)
        XCTAssertTrue(switchControl.isOn)
    }

    func testSetOnAnimatedUnderReduceMotion() {
        TheseusSettings.shared.simulateReduceMotion = true
        let switchControl = makeLaidOutSwitch()
        switchControl.setOn(true, animated: true)
        XCTAssertTrue(switchControl.isOn)
        XCTAssertEqual(switchControl.accessibilityValue, "On")
    }

    func testSettingSameValueIsNoOp() {
        let switchControl = TheseusSwitch()
        var changeCount = 0
        switchControl.onValueChanged = { _ in changeCount += 1 }
        switchControl.isOn = false
        XCTAssertEqual(changeCount, 0)
    }

    // MARK: - Colors

    func testColorConfiguration() {
        let switchControl = TheseusSwitch()
        switchControl.onTintColor = .blue
        switchControl.offTintColor = .red
        switchControl.thumbTintColor = .black

        XCTAssertEqual(switchControl.onTintColor, .blue)
        XCTAssertEqual(switchControl.offTintColor, .red)
        XCTAssertEqual(switchControl.thumbTintColor, .black)
    }

    func testDefaultOffTintColorIsTranslucentInBothAppearances() {
        let switchControl = TheseusSwitch()

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        switchControl.offTintColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(a, 0.298, accuracy: 0.001)
        XCTAssertEqual(r * 255, 60, accuracy: 0.01)
        XCTAssertEqual(g * 255, 60, accuracy: 0.01)
        XCTAssertEqual(b * 255, 67, accuracy: 0.01)

        switchControl.offTintColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(a, 0.298, accuracy: 0.001)
        XCTAssertEqual(r * 255, 235, accuracy: 0.01)
        XCTAssertEqual(g * 255, 235, accuracy: 0.01)
        XCTAssertEqual(b * 255, 245, accuracy: 0.01)
    }

    func testCustomOffTintColorReplacesDefault() {
        let switchControl = TheseusSwitch()
        switchControl.offTintColor = .red

        let resolved = switchControl.offTintColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        XCTAssertEqual(resolved.cgColor.alpha, 1, accuracy: 0.001)
    }

    // MARK: - Pressed Glass

    func testPressedGlassMatchesTheNativeCapsule() {
        let layout = TheseusSwitch.Layout()
        XCTAssertEqual(layout.glassSize.width, 59.333)
        XCTAssertEqual(layout.glassSize.height, 39.667)
        XCTAssertEqual(layout.glassCornerRadius, 19.8335)
        XCTAssertEqual(layout.glassCenterOffset, .zero)
        XCTAssertEqual(layout.glassOverrun, 12.0)
        XCTAssertEqual(layout.glassOverrunResistance, 0.55)
        XCTAssertEqual(TheseusSwitch().glassMaterial, .knobGlass)
    }

    func testGlassFrameRoundsLikeTheNativeLens() {
        let size = TheseusSwitch.Layout().glassSize
        let off = TheseusSwitch.glassFrame(centeredAt: CGPoint(x: 20.5, y: 14), size: size, scale: 3)
        XCTAssertEqual(off.minX, -9.3333, accuracy: 0.001)
        XCTAssertEqual(off.minY, -6.0, accuracy: 0.001)
        XCTAssertEqual(off.midX, 20.3333, accuracy: 0.001)
        XCTAssertEqual(off.midY, 13.8333, accuracy: 0.001)
        let on = TheseusSwitch.glassFrame(centeredAt: CGPoint(x: 42.5, y: 14), size: size, scale: 3)
        XCTAssertEqual(on.midX, 42.6667, accuracy: 0.001)
        XCTAssertEqual(on.width * 3, 178, accuracy: 0.01)
        XCTAssertEqual(on.height * 3, 119, accuracy: 0.01)
    }

    func testPressedGlassWarpsLikeTheNativeKnob() {
        let chain = TheseusConfiguration.LensChain.knob
        XCTAssertEqual(chain.backdropWarp, 9)
        XCTAssertEqual(chain.backdropWarpHeight, 36)
        XCTAssertEqual(chain.ovalization, 0.5)
        XCTAssertEqual(chain.itemWarp, 0)
        XCTAssertEqual(chain.itemLensing, 0)
        XCTAssertEqual(chain.aberration, 0)
        XCTAssertEqual(chain.inset, 2.0 / 3.0, accuracy: 0.0001)
    }

    func testGlassFramesSnapToWholePixels() {
        let aligned = CGRect(x: 10.1, y: 20.26, width: 59.333, height: 39.667).pixelAligned(scale: 3)
        XCTAssertEqual(aligned.origin.x * 3, (aligned.origin.x * 3).rounded(), accuracy: 0.0001)
        XCTAssertEqual(aligned.origin.y * 3, (aligned.origin.y * 3).rounded(), accuracy: 0.0001)
        XCTAssertEqual(aligned.width * 3, 178, accuracy: 0.0001)
        XCTAssertEqual(aligned.height * 3, 119, accuracy: 0.0001)
        XCTAssertEqual(CGRect(x: 1, y: 1, width: 2, height: 2).pixelAligned(scale: 0), CGRect(x: 1, y: 1, width: 2, height: 2))
    }

    func testOverrunFollowsTheNativeRubberBand() {
        let layout = TheseusSwitch.Layout()
        let band = { (distance: CGFloat) in TheseusSwitch.overrun(distance, limit: layout.glassOverrun, resistance: layout.glassOverrunResistance) }
        XCTAssertEqual(band(0), 0)
        XCTAssertEqual(band(-3), 0)
        XCTAssertEqual(band(10), 3.67, accuracy: 0.25)
        XCTAssertEqual(band(20), 5.83, accuracy: 0.25)
        XCTAssertEqual(band(30), 6.83, accuracy: 0.25)
        XCTAssertEqual(band(45), 8.17, accuracy: 0.25)
        XCTAssertEqual(band(60), 8.83, accuracy: 0.25)
        XCTAssertEqual(band(81), 9.5, accuracy: 0.25)
        XCTAssertLessThan(band(1000), 12.0)
        XCTAssertEqual(TheseusSwitch.overrun(5, limit: 0, resistance: 0.8), 0)
    }

    func testReleaseTogglesUnlessTheThumbReachedAnEnd() {
        XCTAssertTrue(TheseusSwitch.committedValue(isOn: false, visuallyOn: false, latched: false))
        XCTAssertFalse(TheseusSwitch.committedValue(isOn: true, visuallyOn: true, latched: false))
        XCTAssertTrue(TheseusSwitch.committedValue(isOn: false, visuallyOn: true, latched: true))
        XCTAssertFalse(TheseusSwitch.committedValue(isOn: false, visuallyOn: false, latched: true))
        XCTAssertFalse(TheseusSwitch.committedValue(isOn: true, visuallyOn: false, latched: true))
    }

    func testSinglePressRecognizerDrivesTheSwitch() {
        let switchControl = makeLaidOutSwitch()
        let recognizers = switchControl.gestureRecognizers ?? []
        XCTAssertEqual(recognizers.count, 1)
        let press = recognizers.first as? UILongPressGestureRecognizer
        XCTAssertNotNil(press)
        XCTAssertEqual(press?.minimumPressDuration, 0)
        XCTAssertEqual(press?.allowableMovement, .greatestFiniteMagnitude)
    }

    // MARK: - Intrinsic Content Size

    func testIntrinsicContentSize() {
        let switchControl = TheseusSwitch()
        let size = switchControl.intrinsicContentSize
        XCTAssertEqual(size.width, 63.0)
        XCTAssertEqual(size.height, 28.0)
    }

    // MARK: - Callback Behavior

    func testValueChangedNotCalledOnProgrammaticChange() {
        let switchControl = TheseusSwitch()
        var callbackCalled = false
        switchControl.onValueChanged = { _ in callbackCalled = true }
        switchControl.isOn = true
        XCTAssertFalse(callbackCalled)
    }

    // MARK: - Accessibility

    func testAccessibilityElementAndTraits() {
        let switchControl = TheseusSwitch()
        XCTAssertTrue(switchControl.isAccessibilityElement)
        XCTAssertTrue(switchControl.accessibilityTraits.contains(.button))
        XCTAssertFalse(switchControl.accessibilityTraits.contains(.notEnabled))
        if #available(iOS 17.0, *) {
            XCTAssertTrue(switchControl.accessibilityTraits.contains(.toggleButton))
        }

        switchControl.isEnabled = false
        XCTAssertTrue(switchControl.accessibilityTraits.contains(.notEnabled))
        XCTAssertTrue(switchControl.accessibilityTraits.contains(.button))
    }

    func testAccessibilityValueFollowsState() {
        let switchControl = TheseusSwitch()
        XCTAssertEqual(switchControl.accessibilityValue, "Off")

        switchControl.isOn = true
        XCTAssertEqual(switchControl.accessibilityValue, "On")

        switchControl.setOn(false, animated: false)
        XCTAssertEqual(switchControl.accessibilityValue, "Off")
    }

    func testHostAccessibilityValueAndLabelWin() {
        let switchControl = TheseusSwitch()
        switchControl.accessibilityLabel = "Wi-Fi"
        switchControl.accessibilityValue = "Connected"
        XCTAssertEqual(switchControl.accessibilityLabel, "Wi-Fi")
        XCTAssertEqual(switchControl.accessibilityValue, "Connected")
    }

    func testAccessibilityActivateTogglesAndNotifies() {
        let switchControl = makeLaidOutSwitch()
        var received: [Bool] = []
        switchControl.onValueChanged = { received.append($0) }

        XCTAssertTrue(switchControl.accessibilityActivate())
        XCTAssertTrue(switchControl.isOn)
        XCTAssertEqual(switchControl.accessibilityValue, "On")
        XCTAssertEqual(received, [true])

        XCTAssertTrue(switchControl.accessibilityActivate())
        XCTAssertFalse(switchControl.isOn)
        XCTAssertEqual(switchControl.accessibilityValue, "Off")
        XCTAssertEqual(received, [true, false])
    }

    func testAccessibilityActivateUnderReduceMotionToggles() {
        TheseusSettings.shared.simulateReduceMotion = true
        let switchControl = makeLaidOutSwitch()

        XCTAssertTrue(switchControl.accessibilityActivate())
        XCTAssertTrue(switchControl.isOn)
    }

    func testAccessibilityActivateIgnoredWhenDisabled() {
        let switchControl = makeLaidOutSwitch()
        switchControl.isEnabled = false
        var callbackCalled = false
        switchControl.onValueChanged = { _ in callbackCalled = true }

        XCTAssertFalse(switchControl.accessibilityActivate())
        XCTAssertFalse(switchControl.isOn)
        XCTAssertFalse(callbackCalled)
    }

    // MARK: - Gesture Arbitration

    func testForeignPanInsideBoundsIsRefused() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        let switchControl = makeLaidOutSwitch()
        container.addSubview(switchControl)

        let pan = StubPanGestureRecognizer()
        container.addGestureRecognizer(pan)
        pan.stubbedLocation = CGPoint(x: 31, y: 15)

        XCTAssertFalse(switchControl.gestureRecognizerShouldBegin(pan))
    }

    func testForeignEdgePanInsideBoundsIsRefused() {
        let switchControl = makeLaidOutSwitch()

        let edgePan = StubEdgePanGestureRecognizer()
        edgePan.stubbedLocation = CGPoint(x: 5, y: 15)

        XCTAssertFalse(switchControl.gestureRecognizerShouldBegin(edgePan))
    }

    func testForeignPanOutsideBoundsIsAllowed() {
        let switchControl = makeLaidOutSwitch()

        let pan = StubPanGestureRecognizer()
        pan.stubbedLocation = CGPoint(x: 100, y: 100)

        XCTAssertTrue(switchControl.gestureRecognizerShouldBegin(pan))
    }

    func testOwnRecognizersAreAllowed() {
        let switchControl = makeLaidOutSwitch()
        let ownRecognizers = switchControl.gestureRecognizers ?? []
        XCTAssertFalse(ownRecognizers.isEmpty)

        for recognizer in ownRecognizers {
            XCTAssertTrue(switchControl.gestureRecognizerShouldBegin(recognizer))
        }
    }

    func testForeignPanIsAllowedWhenDisabled() {
        let switchControl = makeLaidOutSwitch()
        switchControl.isEnabled = false

        let pan = StubPanGestureRecognizer()
        pan.stubbedLocation = CGPoint(x: 31, y: 15)

        XCTAssertTrue(switchControl.gestureRecognizerShouldBegin(pan))
    }
}
