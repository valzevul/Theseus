import XCTest
@testable import Theseus

final class TheseusLensMaterialTests: XCTestCase {

    func testDepthScaleIsOneAtRestAndGrowsWithActivity() {
        var material = TheseusLensMaterial()
        material.motionGain = 2.5
        XCTAssertEqual(material.depthScale(activity: 0), 1, accuracy: 0.0001)
        XCTAssertEqual(material.depthScale(activity: 1), 3.5, accuracy: 0.0001)
        XCTAssertEqual(material.depthScale(activity: 4), 3.5, accuracy: 0.0001)
        XCTAssertEqual(material.depthScale(activity: -1), 1, accuracy: 0.0001)
    }

    func testTabBarAppliesMaterialToItsLens() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        let bar = TheseusTabBar(frame: CGRect(x: 0, y: 700, width: 400, height: 60))
        bar.items = [
            TheseusTabBarItem(icon: nil, title: "One"),
            TheseusTabBarItem(icon: nil, title: "Two")
        ]
        host.addSubview(bar)
        host.layoutIfNeeded()
        var material = TheseusLensMaterial()
        material.bandWidth = 33
        material.depth = 5.5
        material.profile.fallStart = 0.42
        bar.lensMaterial = material
        XCTAssertEqual(bar.lensMaterial.bandWidth, 33)
        XCTAssertEqual(bar.lensMaterial.profile.fallStart, 0.42)
        bar.lensMaterial = material
        XCTAssertEqual(bar.lensMaterial.depth, 5.5)
    }

    func testKnobGlassMatchesTheNativePressedCapsule() {
        let material = TheseusLensMaterial.knobGlass
        XCTAssertEqual(material.bandWidth, 32)
        XCTAssertEqual(material.depth, 3.17)
        XCTAssertEqual(material.dispersion, 0)
        XCTAssertEqual(material.blurRadius, 2.5)
        XCTAssertEqual(material.lift, 0)
        XCTAssertEqual(material.poleMix, 0.10)
        XCTAssertEqual(material.poleMixDark, 0.10)
        XCTAssertEqual(material.gain, 1.0)
        XCTAssertEqual(material.motionGain, 0)
        XCTAssertEqual(material.itemScale, 1)
        XCTAssertEqual(material.profile.riseStart, 0.03)
        XCTAssertEqual(material.profile.riseEnd, 0.21)
        XCTAssertEqual(material.profile.fallStart, 0.37)
        XCTAssertEqual(material.profile.fallLength, 0.055)
        XCTAssertEqual(material.profile.shadeFloor, 0.021)
        XCTAssertEqual(material.profile.shadeFloorDark, 0.06)
        XCTAssertEqual(material.profile.lip, 5.333)
        XCTAssertEqual(material.profile.lipReach, 1.2)
        XCTAssertEqual(material.profile.highlightTail, 0.012)
        XCTAssertEqual(material.profile.highlightTailDark, 0.03)
        XCTAssertEqual(material.profile.contourRamp, 4.0)
        XCTAssertEqual(material.profile.contourRampDark, 0)
        XCTAssertEqual(material.profile.contourSideDark, 1.28)
        XCTAssertEqual(material.profile.contourSideWidth, -0.2)
        XCTAssertEqual(material.profile.contourSideWidthDark, 1.5)
        XCTAssertEqual(material.profile.shadeSideReach, 10.93)
        XCTAssertEqual(material.profile.shadeSideReachDark, 12.51)
        XCTAssertEqual(material.profile.shadeShoulder, 0.55)
        XCTAssertEqual(material.profile.shadeSideShoulder, 0.163)
        XCTAssertEqual(material.profile.shadeLobeTilt, 12.74)
        XCTAssertEqual(material.profile.highlightLobe, 4)
        XCTAssertEqual(material.profile.highlightLobeLight, 8)
        XCTAssertEqual(material.profile.shadeSideOnsetWidth, 24.4)
        XCTAssertEqual(material.profile.shadeCapOnsetShare, 0.711)
        XCTAssertEqual(material.profile.shadeTopExponent, 0.561)
        XCTAssertEqual(material.profile.shadeTopLobeShift, 0.287)
        XCTAssertEqual(material.profile.shadeSideExponent, 3.27)
        XCTAssertEqual(material.profile.contourChroma, 1.0)
        XCTAssertEqual(material.profile.contourChromaDark, 0)
        XCTAssertEqual(material.profile.capExponent, 3.0)
        XCTAssertEqual(material.profile.capExponentTip, 2.3)
        XCTAssertTrue(material.profile.capOutlineOnly)
        var sliderProfile = TheseusLensMaterial.sliderKnobGlass.profile
        XCTAssertEqual(sliderProfile.contourRamp, 2.5)
        XCTAssertEqual(sliderProfile.contourDarkeningLight, 0.28)
        XCTAssertEqual(sliderProfile.contourRampDark, 0)
        XCTAssertEqual(sliderProfile.contourDarkening, 0.41)
        XCTAssertEqual(sliderProfile.contourSide, 1.3)
        XCTAssertEqual(sliderProfile.contourSideDark, 1.3)
        XCTAssertEqual(sliderProfile.contourSideWidth, 1.0)
        XCTAssertEqual(sliderProfile.contourSideWidthDark, 1.0)
        XCTAssertEqual(sliderProfile.highlight, 0.10)
        XCTAssertEqual(sliderProfile.highlightFade, 2.5)
        XCTAssertEqual(sliderProfile.highlightLight, 0.03)
        XCTAssertEqual(sliderProfile.highlightWidth, 1.3)
        XCTAssertEqual(sliderProfile.highlightFadeLight, 1.0)
        XCTAssertEqual(sliderProfile.highlightBottom, 2.0)
        XCTAssertEqual(sliderProfile.highlightBottomDark, 1.1)
        XCTAssertEqual(sliderProfile.shadeOnset, 30)
        XCTAssertEqual(sliderProfile.capExponent, 3.4)
        XCTAssertEqual(sliderProfile.capExponentTip, 2.15)
        sliderProfile.contourRamp = material.profile.contourRamp
        sliderProfile.contourDarkeningLight = material.profile.contourDarkeningLight
        sliderProfile.contourRampDark = material.profile.contourRampDark
        sliderProfile.contourDarkening = material.profile.contourDarkening
        sliderProfile.contourSide = material.profile.contourSide
        sliderProfile.contourSideDark = material.profile.contourSideDark
        sliderProfile.contourSideWidth = material.profile.contourSideWidth
        sliderProfile.contourSideWidthDark = material.profile.contourSideWidthDark
        sliderProfile.highlight = material.profile.highlight
        sliderProfile.highlightFade = material.profile.highlightFade
        sliderProfile.highlightLight = material.profile.highlightLight
        sliderProfile.highlightWidth = material.profile.highlightWidth
        sliderProfile.highlightFadeLight = material.profile.highlightFadeLight
        sliderProfile.highlightBottom = material.profile.highlightBottom
        sliderProfile.highlightBottomDark = material.profile.highlightBottomDark
        sliderProfile.shadeOnset = material.profile.shadeOnset
        sliderProfile.capExponent = material.profile.capExponent
        sliderProfile.capExponentTip = material.profile.capExponentTip
        XCTAssertEqual(sliderProfile, material.profile)
        XCTAssertEqual(material.profile.contourDarkeningLight, 0.264)
        XCTAssertEqual(material.profile.contourDarkening, 0.416)
        XCTAssertEqual(material.profile.contourFlat, 0.69)
        XCTAssertEqual(material.profile.contourFlatDark, 0.17)
        XCTAssertEqual(material.profile.contourSide, 1.32)
        XCTAssertEqual(material.profile.highlight, 0.13)
        XCTAssertEqual(material.profile.highlightWidth, 0.3)
        XCTAssertEqual(material.profile.highlightFade, 3.5)
        XCTAssertEqual(material.profile.highlightFadeLight, 1.5)
        XCTAssertEqual(material.profile.highlightBottomDark, 1.0)
        XCTAssertEqual(material.profile.shadeDark, 0.21)
        XCTAssertEqual(material.profile.shadeSideDark, 0.95)
        XCTAssertEqual(material.profile.shadeOnsetDark, 30)
        XCTAssertEqual(material.profile.highlightLight, 0.08)
        XCTAssertEqual(material.profile.highlightSide, 0)
        XCTAssertEqual(material.profile.highlightBottom, 1.0)
        XCTAssertEqual(material.profile.shade, 0.085)
        XCTAssertEqual(material.profile.shadeSide, 1.086)
        XCTAssertEqual(material.profile.shadeOnset, 29.4)
        XCTAssertEqual(material.profile.shadeSideOnset, 7.13)
        XCTAssertEqual(material.profile.shadeReach, 19.0)
        var configuration = TheseusConfiguration.lens
        material.apply(to: &configuration, isDark: false, activity: 0)
        XCTAssertEqual(configuration.refraction.edgeWidth, 32)
        XCTAssertEqual(configuration.refraction.thickness, 3.17)
        XCTAssertEqual(configuration.refraction.dispersion, 0)
        XCTAssertEqual(configuration.theme.luminanceLift, 0)
        XCTAssertEqual(configuration.theme.backdropGain, 1.0)
        XCTAssertEqual(configuration.theme.bodyPoleMix, 0.10)
        XCTAssertEqual(configuration.refraction.lensProfile, material.profile)
    }

    func testLensProfileDefaultsMatchMaterialDefaults() {
        XCTAssertEqual(TheseusLensMaterial.default.profile, TheseusLensProfile())
        XCTAssertEqual(TheseusRefraction().lensProfile, TheseusLensProfile())
    }

    func testRimLinesAreMeasuredPerAppearance() {
        let profile = TheseusLensProfile()
        XCTAssertEqual(profile.contourDarkening, 0.23)
        XCTAssertEqual(profile.contourDarkeningLight, 0.235)
        XCTAssertEqual(profile.highlight, 0.12)
        XCTAssertEqual(profile.highlightLight, 0.22)
        XCTAssertEqual(profile.highlightBottom, 0.75)
        XCTAssertEqual(profile.highlightWidth, 2.0)
        XCTAssertEqual(profile.highlightFade, 1.0)
        XCTAssertEqual(profile.highlightFadeLight, 1.0)
        XCTAssertEqual(profile.shade, 0.10)
        XCTAssertEqual(profile.shadeDark, 0.12)
        XCTAssertEqual(profile.shadeReach, 18.7)
        XCTAssertEqual(profile.contourSide, 1.0)
        XCTAssertEqual(profile.shadeSide, 0.7071)
        XCTAssertEqual(profile.shadeOnset, 30.0)
        XCTAssertEqual(profile.shadeSideOnset, 18.0)
        XCTAssertEqual(profile.highlightBottomDark, 0.75)
        XCTAssertEqual(profile.shadeSideDark, 0.7071)
        XCTAssertEqual(profile.shadeOnsetDark, 30.0)
        XCTAssertEqual(profile.shadeFloor, 0)
        XCTAssertEqual(profile.shadeFloorDark, 0)
        XCTAssertEqual(profile.lip, 0)
        XCTAssertEqual(profile.lipReach, 2.833)
        XCTAssertEqual(profile.highlightTail, 0.012)
        XCTAssertEqual(profile.highlightTailDark, 0)
        XCTAssertEqual(profile.contourRamp, 0)
        XCTAssertEqual(profile.contourRampDark, 0)
        XCTAssertEqual(profile.contourSideDark, 1.0)
        XCTAssertEqual(profile.contourSideWidth, 0)
        XCTAssertEqual(profile.contourSideWidthDark, 0)
        XCTAssertEqual(profile.shadeSideReach, 0)
        XCTAssertEqual(profile.shadeSideReachDark, 0)
        XCTAssertEqual(profile.shadeShoulder, 0)
        XCTAssertEqual(profile.shadeSideShoulder, -1)
        XCTAssertEqual(profile.shadeLobeTilt, 0)
        XCTAssertEqual(profile.highlightLobe, 0)
        XCTAssertEqual(profile.highlightLobeLight, 0)
        XCTAssertEqual(profile.shadeSideOnsetWidth, 0)
        XCTAssertEqual(profile.shadeCapOnsetShare, 0.27)
        XCTAssertEqual(profile.shadeTopExponent, 0.7)
        XCTAssertEqual(profile.shadeTopLobeShift, 0)
        XCTAssertEqual(profile.shadeSideExponent, 6.0)
        XCTAssertEqual(profile.contourChroma, 0)
        XCTAssertEqual(profile.contourChromaDark, 0)
        XCTAssertEqual(profile.capExponent, 0)
        XCTAssertEqual(profile.capExponentTip, 0)
        XCTAssertFalse(profile.capOutlineOnly)
        XCTAssertEqual(profile.contourFlat, 0.5)
        XCTAssertEqual(profile.contourFlatDark, 0.5)
        XCTAssertTrue(profile.highlightInLinearLight)
    }

    func testBevelRiseNeverFoldsTheBackdrop() {
        let profile = TheseusLensProfile()
        let material = TheseusLensMaterial()
        let bandPx = material.bandWidth * 3
        let risePx = (profile.riseEnd - profile.riseStart) * bandPx
        let peakSlope = material.depth * 3 / risePx
        XCTAssertEqual(profile.frost, 0.5)
        XCTAssertLessThan(peakSlope, 1)
    }

    func testLensItemScalesMatchTheNativeBar() {
        let material = TheseusLensMaterial()
        XCTAssertEqual(material.itemScale, 1.16)
        XCTAssertEqual(TheseusTabBar.liftScale, 1.0431)
        XCTAssertEqual(material.iconScale, 1)
        XCTAssertEqual(material.lift, 0)
        XCTAssertEqual(material.liftDark, 0)
    }

    func testChromeDetailMatchesTheNativeBar() {
        XCTAssertEqual(TheseusTabBar.chromeDetailLight, 0.48)
        XCTAssertEqual(TheseusTabBar.chromeDetailDark, 0.42)
        XCTAssertEqual(TheseusTabBar.chromeAverage, 80)
        XCTAssertEqual(TheseusTabBar.pillDetail, 0.5)
    }
}
