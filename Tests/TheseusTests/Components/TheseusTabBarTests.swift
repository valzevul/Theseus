import XCTest
@testable import Theseus

final class TheseusTabBarTests: XCTestCase {

    private func makeThreeItemBar(frame: CGRect = .zero) -> TheseusTabBar {
        let tabBar = TheseusTabBar(frame: frame)
        tabBar.items = [
            TheseusTabBarItem(icon: nil, title: "One"),
            TheseusTabBarItem(icon: nil, title: "Two"),
            TheseusTabBarItem(icon: nil, title: "Three")
        ]
        return tabBar
    }

    private func accessibilityItems(of tabBar: TheseusTabBar) throws -> [NSObject] {
        try XCTUnwrap(tabBar.accessibilityElements as? [NSObject])
    }

    private func selectedIndices(in elements: [NSObject]) -> [Int] {
        elements.indices.filter { elements[$0].accessibilityTraits.contains(.selected) }
    }

    // MARK: - Default State

    func testDefaultState() {
        let tabBar = TheseusTabBar()
        XCTAssertTrue(tabBar.items.isEmpty)
        XCTAssertEqual(tabBar.selectedIndex, 0)
    }

    // MARK: - Items Management

    func testItemsManagement() {
        let tabBar = TheseusTabBar()
        tabBar.items = [
            TheseusTabBarItem(icon: UIImage(systemName: "house"), title: "Home"),
            TheseusTabBarItem(icon: UIImage(systemName: "gear"), title: "Settings")
        ]
        XCTAssertEqual(tabBar.items.count, 2)

        tabBar.items = []
        XCTAssertTrue(tabBar.items.isEmpty)
    }

    // MARK: - Selection

    func testSelectionIndex() {
        let tabBar = makeThreeItemBar()

        tabBar.selectedIndex = 2
        XCTAssertEqual(tabBar.selectedIndex, 2)

        tabBar.selectedIndex = 0
        XCTAssertEqual(tabBar.selectedIndex, 0)
    }

    // MARK: - Glass Properties

    func testGlassProperties() {
        let tabBar = TheseusTabBar()

        tabBar.glassBlurRadius = 10.0
        XCTAssertEqual(tabBar.glassBlurRadius, 10.0)

        tabBar.glassBlurRadius = 2.0
        XCTAssertEqual(tabBar.glassBlurRadius, 2.0)
    }

    // MARK: - Colors

    func testColorConfiguration() {
        let tabBar = TheseusTabBar()

        tabBar.selectedTintColor = .red
        XCTAssertEqual(tabBar.selectedTintColor, .red)

        tabBar.unselectedTintColor = .gray
        XCTAssertEqual(tabBar.unselectedTintColor, .gray)
    }

    func testUnselectedItemsDefaultToTheNativeVibrantTint() {
        let tabBar = TheseusTabBar()
        XCTAssertTrue(tabBar.unselectedTintColor === TheseusTabBar.nativeUnselectedTint)
        tabBar.unselectedTintColor = .red
        XCTAssertEqual(tabBar.unselectedTint(), .red)
    }

    // MARK: - Tab Bar Item

    func testTabBarItemInit() {
        let item = TheseusTabBarItem(icon: UIImage(systemName: "star"), title: "Favorites")
        XCTAssertEqual(item.title, "Favorites")
        XCTAssertNotNil(item.icon)

        let textOnlyItem = TheseusTabBarItem(icon: nil, title: "Text Only")
        XCTAssertNil(textOnlyItem.icon)
    }

    // MARK: - Accessibility

    func testBarIsAnAccessibilityContainerWithTabBarTrait() throws {
        let tabBar = makeThreeItemBar()

        XCTAssertFalse(tabBar.isAccessibilityElement)
        XCTAssertTrue(tabBar.accessibilityTraits.contains(.tabBar))

        let elements = try accessibilityItems(of: tabBar)
        XCTAssertEqual(elements.count, 3)
        XCTAssertEqual(elements.map(\.accessibilityLabel), ["One", "Two", "Three"])
        for element in elements {
            XCTAssertTrue(element.isAccessibilityElement)
            XCTAssertTrue(element.accessibilityTraits.contains(.button))
            XCTAssertNil(element.accessibilityHint)
        }
    }

    func testExactlyOneItemCarriesSelectedTrait() throws {
        let tabBar = makeThreeItemBar()
        let elements = try accessibilityItems(of: tabBar)

        XCTAssertEqual(selectedIndices(in: elements), [0])

        tabBar.selectedIndex = 2
        XCTAssertEqual(selectedIndices(in: elements), [2])

        tabBar.selectedTintColor = .red
        XCTAssertEqual(selectedIndices(in: elements), [2])
    }

    func testAccessibilityActivateSelectsItem() throws {
        let tabBar = makeThreeItemBar()
        var received: [Int] = []
        tabBar.onItemSelected = { received.append($0) }
        let elements = try accessibilityItems(of: tabBar)

        XCTAssertTrue(elements[1].accessibilityActivate())
        XCTAssertEqual(tabBar.selectedIndex, 1)
        XCTAssertEqual(received, [1])
        XCTAssertEqual(selectedIndices(in: elements), [1])

        XCTAssertTrue(elements[1].accessibilityActivate())
        XCTAssertEqual(received, [1])
    }

    // MARK: - Gesture Arbitration

    private final class StubPanGestureRecognizer: UIPanGestureRecognizer {
        var stubbedLocation: CGPoint = .zero
        override func location(in view: UIView?) -> CGPoint { stubbedLocation }
    }

    private final class StubScreenEdgePanGestureRecognizer: UIScreenEdgePanGestureRecognizer {
        var stubbedLocation: CGPoint = .zero
        override func location(in view: UIView?) -> CGPoint { stubbedLocation }
    }

    func testForeignPanInsideBarIsRefused() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let tabBar = makeThreeItemBar(frame: CGRect(x: 0, y: 200, width: 400, height: 60))
        container.addSubview(tabBar)

        let foreignPan = StubPanGestureRecognizer()
        container.addGestureRecognizer(foreignPan)
        foreignPan.stubbedLocation = CGPoint(x: 200, y: 30)
        XCTAssertFalse(tabBar.gestureRecognizerShouldBegin(foreignPan))

        foreignPan.stubbedLocation = CGPoint(x: 200, y: -30)
        XCTAssertTrue(tabBar.gestureRecognizerShouldBegin(foreignPan))

        let edgePan = StubScreenEdgePanGestureRecognizer()
        container.addGestureRecognizer(edgePan)
        edgePan.stubbedLocation = CGPoint(x: 5, y: 30)
        XCTAssertFalse(tabBar.gestureRecognizerShouldBegin(edgePan))
    }

    func testOwnRecognizersStillBegin() throws {
        let tabBar = makeThreeItemBar(frame: CGRect(x: 0, y: 0, width: 400, height: 60))
        let recognizers = try XCTUnwrap(tabBar.gestureRecognizers)
        let ownPan = try XCTUnwrap(recognizers.first { $0 is UIPanGestureRecognizer })
        let ownPress = try XCTUnwrap(recognizers.first { $0 is UILongPressGestureRecognizer } as? UILongPressGestureRecognizer)

        XCTAssertTrue(tabBar.gestureRecognizerShouldBegin(ownPan))
        XCTAssertTrue(tabBar.gestureRecognizerShouldBegin(ownPress))
        XCTAssertEqual(ownPress.minimumPressDuration, 0)
        XCTAssertTrue(tabBar.gestureRecognizer(ownPress, shouldRecognizeSimultaneouslyWith: ownPan))
        XCTAssertNil(recognizers.first { $0 is UITapGestureRecognizer })
    }

    // MARK: - Native Geometry And Timing

    func testPillAndLensMatchTheNativeBar() {
        XCTAssertEqual(TheseusTabBar.pillSize, CGSize(width: 80, height: 53.5))
        XCTAssertEqual(TheseusTabBar.lensSize, CGSize(width: 96, height: 70))
        XCTAssertEqual(TheseusTabBar.liftScale, 1.0431)
    }

    func testLensChainCarriesTheNativeOptics() {
        let chain = TheseusConfiguration.LensChain()
        XCTAssertEqual(chain.backdropWarp, 9)
        XCTAssertEqual(chain.backdropWarpHeight, 36)
        XCTAssertEqual(chain.itemWarp, 17.5)
        XCTAssertEqual(chain.itemLensing, 14)
        XCTAssertEqual(chain.itemWarpHeight, 11.2)
        XCTAssertEqual(chain.ovalization, 0.5)
        XCTAssertEqual(chain.itemRimFade, 3.6)
        XCTAssertEqual(TheseusConfiguration.LensChain.knob.itemRimFade, 0)
    }

    func testLensGrowSpringSettlesLikeNative() {
        let spring = TheseusTabBar.lensGrowSpring
        XCTAssertEqual(spring.progress(0.040 - 0.023), 0.154, accuracy: 0.03)
        XCTAssertEqual(spring.progress(0.140 - 0.023), 0.829, accuracy: 0.03)
        XCTAssertEqual(spring.progress(0.240 - 0.023), 0.978, accuracy: 0.02)
        XCTAssertLessThan(spring.progress(0.6), 1.005)
    }

    func testPressStretchPeaksAndRelaxesLikeNative() {
        XCTAssertEqual(TheseusTabBar.pressStretch(at: 0.3), 1)
        XCTAssertEqual(TheseusTabBar.pressStretch(at: 0.47), 1.119, accuracy: 1e-9)
        XCTAssertEqual(TheseusTabBar.pressStretch(at: 0.685), 1.0505, accuracy: 1e-3)
        XCTAssertEqual(TheseusTabBar.pressStretch(at: 1.1), 1)
        let ios27 = TheseusTabBar.iOS27PressStretch
        XCTAssertEqual(TheseusTabBar.pressStretch(at: 0.30, table: ios27), 1)
        XCTAssertEqual(TheseusTabBar.pressStretch(at: 0.56, table: ios27), 1.128, accuracy: 1e-9)
        XCTAssertEqual(TheseusTabBar.pressStretch(at: 0.685, table: ios27), 1.080, accuracy: 1e-3)
        XCTAssertEqual(TheseusTabBar.pressStretch(at: 0.97, table: ios27), 1)
    }

    func testShrinkSpringHoldsBeforeItShrinks() {
        let spring = TheseusTabBar.lensShrinkSpring
        XCTAssertLessThan(spring.progress(0.01), 0.015)
        XCTAssertEqual(spring.progress(0.25), 1, accuracy: 0.03)
    }

    private func grey(_ level: CGFloat, chrome: TheseusTabBar.ChromeCurve, pill: TheseusTabBar.PillMaterial?) -> CGFloat {
        var configuration = TheseusConfiguration()
        configuration.theme.bodyCurve = chrome.knots
        configuration.theme.bodyCurveChromaSlope = chrome.chromaSlope
        configuration.theme.backdropSaturation = chrome.chroma
        if let pill {
            configuration.theme.bodyCurveSaturation = pill.saturation
            configuration.theme.backdropGain = pill.gain
            configuration.theme.luminanceLift = pill.lift
        }
        return TheseusMaterialModel.bodyValue(level / 255, configuration: configuration, isDark: false, spectrum: 0.5) * 255
    }

    func testChromeAndPillFollowTheNativeIOS27Sweep() {
        let light = TheseusTabBar.iOS27Chrome(isDark: false, spectrum: 0.5)
        let dark = TheseusTabBar.iOS27Chrome(isDark: true, spectrum: 0.5)
        for (level, chrome, pill) in [(16.0, 141.0, 107.5), (128, 195, 168.7), (208, 232, 210.6)] {
            XCTAssertEqual(grey(level, chrome: light, pill: nil), chrome, accuracy: 1)
            XCTAssertEqual(grey(level, chrome: light, pill: TheseusTabBar.iOS27PillLight), pill, accuracy: 1.5)
        }
        for (level, chrome, pill) in [(16.0, 47.0, 24.0), (128, 134, 99), (208, 172, 131.9)] {
            XCTAssertEqual(grey(level, chrome: dark, pill: nil), chrome, accuracy: 1)
            XCTAssertEqual(grey(level, chrome: dark, pill: TheseusTabBar.iOS27PillDark), pill, accuracy: 1.5)
        }
    }

    func testChromeAndPillFollowTheNativeIOS26Sweep() {
        XCTAssertEqual(grey(128, chrome: TheseusTabBar.iOS26Chrome(isDark: false, spectrum: 0), pill: nil), 205, accuracy: 1.5)
        XCTAssertEqual(grey(128, chrome: TheseusTabBar.iOS26Chrome(isDark: false, spectrum: 0), pill: TheseusTabBar.iOS26PillLight), 181, accuracy: 1.5)
        XCTAssertEqual(grey(128, chrome: TheseusTabBar.iOS26Chrome(isDark: true, spectrum: 0), pill: nil), 89, accuracy: 1)
        XCTAssertEqual(grey(128, chrome: TheseusTabBar.iOS26Chrome(isDark: true, spectrum: 0), pill: TheseusTabBar.iOS26PillDark), 120, accuracy: 1.5)
        XCTAssertEqual(grey(128, chrome: TheseusTabBar.iOS26Chrome(isDark: false, spectrum: 1), pill: nil), 230, accuracy: 1)
        XCTAssertEqual(grey(128, chrome: TheseusTabBar.iOS26Chrome(isDark: false, spectrum: 1), pill: TheseusTabBar.iOS26PillLight), 209, accuracy: 1.5)
        XCTAssertEqual(grey(128, chrome: TheseusTabBar.iOS26Chrome(isDark: true, spectrum: 1), pill: nil), 47, accuracy: 1)
        XCTAssertEqual(grey(128, chrome: TheseusTabBar.iOS26Chrome(isDark: true, spectrum: 1), pill: TheseusTabBar.iOS26PillDark), 79, accuracy: 1.5)
    }

    func testIOS26BarShadowRendersAGaussianUnderTheCapsule() {
        let image = TheseusTabBar.shadowImage(bar: CGSize(width: 100, height: 40), margin: 50, sigma: 10, offset: 8, opacity: 0.2, scale: 1)
        XCTAssertEqual(image?.width, 200)
        XCTAssertEqual(image?.height, 140)
    }
}
