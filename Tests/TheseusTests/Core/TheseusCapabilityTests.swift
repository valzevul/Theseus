import XCTest
@testable import Theseus

final class TheseusCapabilityTests: XCTestCase {

    // MARK: - Device Tier

    func testDeviceTierComparison() {
        XCTAssertTrue(DeviceTier.tier0 < DeviceTier.tier1)
        XCTAssertTrue(DeviceTier.tier1 < DeviceTier.tier2)
        XCTAssertTrue(DeviceTier.tier2 < DeviceTier.tier3)
        XCTAssertFalse(DeviceTier.tier3 < DeviceTier.tier0)
    }

    // MARK: - Refraction Quality

    func testRefractionQualityFrameRates() {
        XCTAssertEqual(RefractionQuality.low.frameRate, 15)
        XCTAssertEqual(RefractionQuality.medium.frameRate, 30)
        XCTAssertEqual(RefractionQuality.high.frameRate, 60)
    }

    func testRefractionQualityRenderScales() {
        XCTAssertEqual(RefractionQuality.low.renderScale, 0.25)
        XCTAssertEqual(RefractionQuality.medium.renderScale, 0.5)
        XCTAssertEqual(RefractionQuality.high.renderScale, 1.0)
    }

    // MARK: - Quality Level

    func testQualityLevelMaxBlurRadius() {
        XCTAssertEqual(QualityLevel.low.maxBlurRadius, 16)
        XCTAssertEqual(QualityLevel.medium.maxBlurRadius, 32)
        XCTAssertEqual(QualityLevel.high.maxBlurRadius, 64)
        XCTAssertEqual(QualityLevel.ultra.maxBlurRadius, 100)
    }

    func testQualityLevelRenderScale() {
        XCTAssertEqual(QualityLevel.low.renderScale, 0.5)
        XCTAssertEqual(QualityLevel.medium.renderScale, 0.75)
        XCTAssertEqual(QualityLevel.high.renderScale, 1.0)
        XCTAssertEqual(QualityLevel.ultra.renderScale, 1.0)
    }

    // MARK: - Device Info

    func testPhysicalMemoryGBIsPositive() {
        XCTAssertGreaterThan(TheseusCapability.physicalMemoryGB, 0)
    }

    func testProcessorCountIsPositive() {
        XCTAssertGreaterThan(TheseusCapability.processorCount, 0)
    }

    // MARK: - iOS Version

    func testIOSMajorVersionInRange() {
        let version = TheseusCapability.iosMajorVersion
        XCTAssertGreaterThanOrEqual(version, 13)
    }

    // MARK: - Device Identifier Matching

    func testOldDevicesAreUnsupported() {
        XCTAssertTrue(TheseusCapability.isUnsupportedDevice(identifier: "iPhone1,1"))   // original iPhone
        XCTAssertTrue(TheseusCapability.isUnsupportedDevice(identifier: "iPhone9,1"))   // iPhone 7
        XCTAssertTrue(TheseusCapability.isUnsupportedDevice(identifier: "iPhone10,3"))  // iPhone X
        XCTAssertTrue(TheseusCapability.isUnsupportedDevice(identifier: "iPhone11,8"))  // iPhone XR
        XCTAssertTrue(TheseusCapability.isUnsupportedDevice(identifier: "iPhone11,2"))  // iPhone XS
        XCTAssertTrue(TheseusCapability.isUnsupportedDevice(identifier: "iPod9,1"))     // iPod touch 7
    }

    func testModernDevicesAreSupported() {
        // "iPhone1," must not swallow the two-digit generations.
        XCTAssertFalse(TheseusCapability.isUnsupportedDevice(identifier: "iPhone12,1")) // iPhone 11
        XCTAssertFalse(TheseusCapability.isUnsupportedDevice(identifier: "iPhone13,2")) // iPhone 12
        XCTAssertFalse(TheseusCapability.isUnsupportedDevice(identifier: "iPhone14,5")) // iPhone 13
        XCTAssertFalse(TheseusCapability.isUnsupportedDevice(identifier: "iPhone17,1")) // iPhone 16 Pro
        XCTAssertFalse(TheseusCapability.isUnsupportedDevice(identifier: "arm64"))      // simulator
    }
}
