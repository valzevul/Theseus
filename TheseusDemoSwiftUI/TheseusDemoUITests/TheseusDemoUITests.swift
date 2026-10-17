import XCTest

final class TheseusDemoUITests: XCTestCase {

    private func launch(_ demo: String, dark: Bool, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.example.TheseusDemoSwiftUI")
        app.launchArguments = ["-demo", demo, "-isDarkMode", dark ? "1" : "0"] + extra
        app.launch()
        sleep(3)
        return app
    }

    private func point(_ app: XCUIApplication, _ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
    }

    @MainActor
    private func press(_ demo: String, dark: Bool, at spot: CGPoint) {
        let app = launch(demo, dark: dark)
        point(app, spot.x, spot.y).press(forDuration: 5)
        sleep(2)
    }

    @MainActor
    private func drag(_ demo: String, dark: Bool, from start: CGPoint, to end: CGPoint) {
        let app = launch(demo, dark: dark)
        point(app, start.x, start.y).press(forDuration: 0.8, thenDragTo: point(app, end.x, end.y), withVelocity: 100, thenHoldForDuration: 4)
        sleep(2)
    }

    @MainActor
    private func pressBoth(_ demo: String, dark: Bool, native: CGPoint, ours: CGPoint) {
        let app = launch(demo, dark: dark)
        point(app, native.x, native.y).press(forDuration: 5)
        sleep(2)
        point(app, ours.x, ours.y).press(forDuration: 5)
        sleep(2)
    }

    @MainActor private func shortPress(_ demo: String, at spot: CGPoint) {
        let app = launch(demo, dark: false)
        point(app, spot.x, spot.y).press(forDuration: 1.5)
        sleep(2)
    }
    @MainActor func testSwitchShortNativeLight() { shortPress("switch", at: CGPoint(x: 293, y: 438)) }
    @MainActor func testSwitchShortOursLight() { shortPress("switch", at: CGPoint(x: 293, y: 517)) }
    @MainActor private func pressOn(dark: Bool, at spot: CGPoint) {
        let app = launch("switch", dark: dark)
        point(app, 293, 438).press(forDuration: 0.2)
        sleep(2)
        point(app, spot.x, spot.y).press(forDuration: 5)
        sleep(2)
    }
    @MainActor func testSwitchOnNativeLight() { pressOn(dark: false, at: CGPoint(x: 315, y: 438)) }
    @MainActor func testSwitchOnOursLight() { pressOn(dark: false, at: CGPoint(x: 317, y: 516)) }
    @MainActor func testSwitchOnNativeDark() { pressOn(dark: true, at: CGPoint(x: 315, y: 438)) }
    @MainActor func testSwitchOnOursDark() { pressOn(dark: true, at: CGPoint(x: 317, y: 516)) }
    @MainActor func testSliderBothLight() { pressBoth("slider", dark: false, native: CGPoint(x: 200, y: 482), ours: CGPoint(x: 200, y: 578)) }
    @MainActor func testSliderBothDark() { pressBoth("slider", dark: true, native: CGPoint(x: 200, y: 482), ours: CGPoint(x: 200, y: 578)) }
    @MainActor func testSwitchNativeLight() { press("switch", dark: false, at: CGPoint(x: 293, y: 438)) }
    @MainActor func testSwitchOursLight() { press("switch", dark: false, at: CGPoint(x: 293, y: 517)) }
    @MainActor func testSwitchNativeDark() { press("switch", dark: true, at: CGPoint(x: 293, y: 438)) }
    @MainActor func testSwitchOursDark() { press("switch", dark: true, at: CGPoint(x: 293, y: 517)) }
    @MainActor func testSliderNativeLight() { press("slider", dark: false, at: CGPoint(x: 200, y: 482)) }
    @MainActor func testSliderOursLight() { press("slider", dark: false, at: CGPoint(x: 200, y: 578)) }
    @MainActor func testSliderNativeDark() { press("slider", dark: true, at: CGPoint(x: 200, y: 482)) }
    @MainActor func testSliderOursDark() { press("slider", dark: true, at: CGPoint(x: 200, y: 578)) }
    @MainActor func testTabBarHoldNativeLight() { press("tabbar", dark: false, at: CGPoint(x: 201, y: 418)) }
    @MainActor func testTabBarHoldOursLight() { press("tabbar", dark: false, at: CGPoint(x: 201, y: 547)) }
    @MainActor func testTabBarNativeLight() { drag("tabbar", dark: false, from: CGPoint(x: 78, y: 418), to: CGPoint(x: 230, y: 418)) }
    @MainActor func testTabBarOursLight() { drag("tabbar", dark: false, from: CGPoint(x: 78, y: 547), to: CGPoint(x: 230, y: 547)) }
    @MainActor func testTabBarNativeDark() { drag("tabbar", dark: true, from: CGPoint(x: 78, y: 418), to: CGPoint(x: 230, y: 418)) }
    @MainActor func testTabBarOursDark() { drag("tabbar", dark: true, from: CGPoint(x: 78, y: 547), to: CGPoint(x: 230, y: 547)) }
}
