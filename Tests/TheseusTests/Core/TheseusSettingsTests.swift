import XCTest
@testable import Theseus

final class TheseusSettingsTests: XCTestCase {

    var settings: TheseusSettings!

    override func setUp() {
        super.setUp()
        settings = TheseusSettings.shared
        settings.resetToDefaults()
    }

    override func tearDown() {
        settings.resetToDefaults()
        super.tearDown()
    }

    // MARK: - Tier Override

    func testTierOverrideApplied() {
        settings.tierOverride = .tier0
        XCTAssertEqual(settings.effectiveTier, .tier0)

        settings.tierOverride = .tier3
        XCTAssertEqual(settings.effectiveTier, .tier3)

        settings.tierOverride = nil
        XCTAssertEqual(settings.effectiveTier, TheseusCapability.deviceTier)
    }

    // MARK: - iOS Version Override

    func testIOSVersionOverrideApplied() {
        settings.iosVersionOverride = 13
        XCTAssertEqual(settings.effectiveIOSVersion, 13)

        settings.iosVersionOverride = nil
        XCTAssertEqual(settings.effectiveIOSVersion, TheseusCapability.iosMajorVersion)
    }

    func testIOSMajorVersionMatchesProcessInfo() {
        let expected = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        XCTAssertEqual(TheseusCapability.iosMajorVersion, expected)
        settings.iosVersionOverride = nil
        XCTAssertEqual(settings.effectiveIOSVersion, expected)
    }

    // MARK: - Refraction Policy Override

    func testRefractionPolicyOverrideApplied() {
        settings.refractionPolicyOverride = .off
        XCTAssertEqual(settings.effectiveRefractionPolicy, .off)

        settings.refractionPolicyOverride = .trueRefraction
        XCTAssertEqual(settings.effectiveRefractionPolicy, .trueRefraction)
    }

    // MARK: - Refraction Quality Override

    func testRefractionQualityOverrideApplied() {
        settings.refractionQualityOverride = .low
        XCTAssertEqual(settings.effectiveRefractionQuality, .low)

        settings.refractionQualityOverride = .high
        XCTAssertEqual(settings.effectiveRefractionQuality, .high)
    }

    // MARK: - Fallback Mode

    func testShouldUseFallback() {
        settings.forceFallback = true
        XCTAssertTrue(settings.shouldUseFallback)

        settings.forceFallback = false
        settings.tierOverride = .tier0
        XCTAssertTrue(settings.shouldUseFallback)

        settings.tierOverride = .tier3
        settings.refractionPolicyOverride = .off
        XCTAssertTrue(settings.shouldUseFallback)
    }

    // MARK: - Environment Simulation

    func testEnvironmentSimulation() {
        settings.simulateLowPowerMode = true
        XCTAssertTrue(settings.isLowPowerModeActive)
        XCTAssertTrue(settings.isConstrained)

        settings.simulateLowPowerMode = false
        settings.simulateReduceTransparency = true
        XCTAssertTrue(settings.isReduceTransparencyActive)

        settings.simulateReduceTransparency = false
        settings.simulateReduceMotion = true
        XCTAssertTrue(settings.isReduceMotionActive)
    }

    // MARK: - Policy Computation

    func testReduceTransparencyReturnsOffPolicy() {
        settings.simulateReduceTransparency = true
        settings.refractionPolicyOverride = nil
        XCTAssertEqual(settings.effectiveRefractionPolicy, .off)
    }

    func testConstrainedReturnsCheapApproxPolicy() {
        settings.simulateLowPowerMode = true
        settings.simulateReduceTransparency = false
        settings.refractionPolicyOverride = nil
        XCTAssertEqual(settings.effectiveRefractionPolicy, .cheapApprox)
    }

    func testTierBasedPolicySelection() {
        settings.simulateLowPowerMode = false
        settings.simulateReduceTransparency = false
        settings.refractionPolicyOverride = nil

        settings.tierOverride = .tier0
        XCTAssertEqual(settings.effectiveRefractionPolicy, .cheapApprox)

        settings.tierOverride = .tier3
        XCTAssertEqual(settings.effectiveRefractionPolicy, .trueRefraction)
    }

    func testTier1PolicyDependsOnIOSVersion() {
        settings.simulateLowPowerMode = false
        settings.simulateReduceTransparency = false
        settings.tierOverride = .tier1
        settings.refractionPolicyOverride = nil

        settings.iosVersionOverride = 17
        XCTAssertEqual(settings.effectiveRefractionPolicy, .trueRefraction)

        settings.iosVersionOverride = 16
        XCTAssertEqual(settings.effectiveRefractionPolicy, .cheapApprox)
    }

    func testTier2PolicyDependsOnIOSVersion() {
        settings.simulateLowPowerMode = false
        settings.simulateReduceTransparency = false
        settings.tierOverride = .tier2
        settings.refractionPolicyOverride = nil

        settings.iosVersionOverride = 15
        XCTAssertEqual(settings.effectiveRefractionPolicy, .trueRefraction)

        settings.iosVersionOverride = 14
        XCTAssertEqual(settings.effectiveRefractionPolicy, .cheapApprox)
    }

    // MARK: - Quality Computation

    func testQualityByTier() {
        settings.simulateLowPowerMode = false
        settings.refractionQualityOverride = nil

        settings.tierOverride = .tier0
        XCTAssertEqual(settings.effectiveRefractionQuality, .low)

        settings.tierOverride = .tier1
        XCTAssertEqual(settings.effectiveRefractionQuality, .low)

        settings.tierOverride = .tier2
        XCTAssertEqual(settings.effectiveRefractionQuality, .medium)
    }

    func testTier3QualityDependsOnIOSVersion() {
        settings.simulateLowPowerMode = false
        settings.tierOverride = .tier3
        settings.refractionQualityOverride = nil

        settings.iosVersionOverride = 17
        XCTAssertEqual(settings.effectiveRefractionQuality, .high)

        settings.iosVersionOverride = 16
        XCTAssertEqual(settings.effectiveRefractionQuality, .medium)
    }

    func testConstrainedReturnsLowQuality() {
        settings.simulateLowPowerMode = true
        settings.refractionQualityOverride = nil
        XCTAssertEqual(settings.effectiveRefractionQuality, .low)
    }

    // MARK: - Component-Specific Policy

    func testComponentPolicyWhenBasePolicyIsOff() {
        settings.refractionPolicyOverride = .off
        XCTAssertEqual(settings.effectivePolicy(for: .tabBar), .off)
        XCTAssertEqual(settings.effectivePolicy(for: .button), .off)
        XCTAssertEqual(settings.effectivePolicy(for: .slider), .off)
    }

    func testTier0AlwaysReturnsCheapApproxForComponents() {
        settings.tierOverride = .tier0
        settings.refractionPolicyOverride = .trueRefraction
        XCTAssertEqual(settings.effectivePolicy(for: .tabBar), .cheapApprox)
        XCTAssertEqual(settings.effectivePolicy(for: .button), .cheapApprox)
    }

    func testTier1OnlyTabBarGetsBasePolicy() {
        settings.tierOverride = .tier1
        settings.refractionPolicyOverride = .trueRefraction
        XCTAssertEqual(settings.effectivePolicy(for: .tabBar), .trueRefraction)
        XCTAssertEqual(settings.effectivePolicy(for: .button), .cheapApprox)
        XCTAssertEqual(settings.effectivePolicy(for: .slider), .cheapApprox)
    }

    func testTier2TabBarAndSwitchGetBasePolicy() {
        settings.tierOverride = .tier2
        settings.refractionPolicyOverride = .trueRefraction
        XCTAssertEqual(settings.effectivePolicy(for: .tabBar), .trueRefraction)
        XCTAssertEqual(settings.effectivePolicy(for: .switch), .trueRefraction)
        XCTAssertEqual(settings.effectivePolicy(for: .button), .cheapApprox)
    }

    func testTier3AllComponentsGetBasePolicy() {
        settings.tierOverride = .tier3
        settings.refractionPolicyOverride = .trueRefraction
        XCTAssertEqual(settings.effectivePolicy(for: .tabBar), .trueRefraction)
        XCTAssertEqual(settings.effectivePolicy(for: .switch), .trueRefraction)
        XCTAssertEqual(settings.effectivePolicy(for: .button), .trueRefraction)
        XCTAssertEqual(settings.effectivePolicy(for: .slider), .trueRefraction)
        XCTAssertEqual(settings.effectivePolicy(for: .glassView), .trueRefraction)
    }

    // MARK: - Reset

    func testResetToDefaultsClearsAllOverrides() {
        settings.tierOverride = .tier3
        settings.iosVersionOverride = 17
        settings.refractionPolicyOverride = .trueRefraction
        settings.refractionQualityOverride = .high
        settings.forceFallback = true
        settings.simulateLowPowerMode = true
        settings.simulateReduceTransparency = true
        settings.simulateReduceMotion = true

        settings.resetToDefaults()

        XCTAssertNil(settings.tierOverride)
        XCTAssertNil(settings.iosVersionOverride)
        XCTAssertNil(settings.refractionPolicyOverride)
        XCTAssertNil(settings.refractionQualityOverride)
        XCTAssertFalse(settings.forceFallback)
        XCTAssertNil(settings.simulateLowPowerMode)
        XCTAssertNil(settings.simulateReduceTransparency)
        XCTAssertNil(settings.simulateReduceMotion)
    }

    // MARK: - Tint Spectrum (iOS 27 clear to tinted parity)

    func testTintSpectrumDefaultsToSystemMidpoint() {
        // Matches iOS 27's "Tint Amount" system default of 0.5
        XCTAssertEqual(settings.tintSpectrum, 0.5)
    }

    func testSystemTintFollowsTheTintAmountOnIOS27() {
        UserDefaults.standard.set(0.25, forKey: TheseusSettings.systemTintAmountKey)
        defer { UserDefaults.standard.removeObject(forKey: TheseusSettings.systemTintAmountKey) }
        settings.iosVersionOverride = 27
        XCTAssertEqual(settings.systemTintSpectrum ?? -1, 0.25, accuracy: 0.0001)
        XCTAssertEqual(settings.tintSpectrum, 0.25, accuracy: 0.0001)
        UserDefaults.standard.removeObject(forKey: TheseusSettings.systemTintAmountKey)
        XCTAssertEqual(settings.systemTintSpectrum ?? -1, 0.5, accuracy: 0.0001)
    }

    func testSystemTintReadsClearOrTintedOnIOS26() {
        UserDefaults.standard.set(1, forKey: TheseusSettings.systemGlassLegibilityKey)
        defer { UserDefaults.standard.removeObject(forKey: TheseusSettings.systemGlassLegibilityKey) }
        settings.iosVersionOverride = 26
        XCTAssertEqual(settings.systemTintSpectrum, 1)
        XCTAssertEqual(settings.tintSpectrum, 1)
        XCTAssertEqual(settings.effectiveGlassStyle, .iOS26)
        settings.iosVersionOverride = 25
        XCTAssertNil(settings.systemTintSpectrum)
        XCTAssertEqual(settings.effectiveGlassStyle, .iOS27)
    }

    func testSettingTheSpectrumStopsFollowingTheSystem() {
        XCTAssertTrue(settings.followsSystemTint)
        settings.tintSpectrum = 0.8
        XCTAssertFalse(settings.followsSystemTint)
        UserDefaults.standard.set(0.1, forKey: TheseusSettings.systemTintAmountKey)
        defer { UserDefaults.standard.removeObject(forKey: TheseusSettings.systemTintAmountKey) }
        settings.iosVersionOverride = 27
        XCTAssertEqual(settings.tintSpectrum, 0.8, accuracy: 0.0001)
        settings.followsSystemTint = true
        XCTAssertEqual(settings.tintSpectrum, 0.1, accuracy: 0.0001)
    }

    func testTintSpectrumClampsToUnitRange() {
        settings.tintSpectrum = 1.5
        XCTAssertEqual(settings.tintSpectrum, 1.0)

        settings.tintSpectrum = -0.5
        XCTAssertEqual(settings.tintSpectrum, 0.0)

        settings.tintSpectrum = 0.42
        XCTAssertEqual(settings.tintSpectrum, 0.42)
    }

    func testTintSpectrumPostsNotification() {
        let expectation = expectation(description: "Tint spectrum change notification")

        let observer = NotificationCenter.default.addObserver(
            forName: TheseusSettings.settingsDidChangeNotification,
            object: settings,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }

        settings.tintSpectrum = 0.3

        waitForExpectations(timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testTintSpectrumResetsToDefault() {
        settings.tintSpectrum = 0.2
        settings.resetToDefaults()
        XCTAssertEqual(settings.tintSpectrum, 0.5)
    }

    func testTintSpectrumPersistenceWritesAndLoads() {
        let suiteName = "TheseusSettingsTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create test defaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        settings.tintSpectrum = 0.75
        settings.enableTintSpectrumPersistence(in: defaults)
        XCTAssertEqual(defaults.double(forKey: TheseusSettings.tintSpectrumDefaultsKey), 0.75, accuracy: 0.0001)

        settings.tintSpectrum = 0.25
        XCTAssertEqual(defaults.double(forKey: TheseusSettings.tintSpectrumDefaultsKey), 0.25, accuracy: 0.0001)

        settings.disableTintSpectrumPersistence()
    }

    func testTintSpectrumPersistenceLoadsStoredValueOnEnable() {
        let suiteName = "TheseusSettingsTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create test defaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(0.6, forKey: TheseusSettings.tintSpectrumDefaultsKey)
        settings.enableTintSpectrumPersistence(in: defaults)
        XCTAssertEqual(settings.tintSpectrum, 0.6, accuracy: 0.0001)

        settings.disableTintSpectrumPersistence()
    }

    func testTintSpectrumPersistenceWithCustomKey() {
        let suiteName = "TheseusSettingsTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create test defaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        settings.tintSpectrum = 0.9
        settings.enableTintSpectrumPersistence(in: defaults, key: "CustomTintKey")
        XCTAssertEqual(defaults.double(forKey: "CustomTintKey"), 0.9, accuracy: 0.0001)

        settings.disableTintSpectrumPersistence()
    }

    func testTintSpectrumPersistenceObservesSecondDefaultsInstance() {
        let suiteName = "TheseusSettingsTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName),
              let otherInstance = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create test defaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        settings.tintSpectrum = 0.5
        settings.enableTintSpectrumPersistence(in: defaults)

        let updated = expectation(
            forNotification: TheseusSettings.settingsDidChangeNotification,
            object: settings
        ) { _ in
            TheseusSettings.shared.tintSpectrum == 0.15
        }

        otherInstance.set(0.15, forKey: TheseusSettings.tintSpectrumDefaultsKey)

        wait(for: [updated], timeout: 5.0)
        XCTAssertEqual(settings.tintSpectrum, 0.15, accuracy: 0.0001)

        settings.disableTintSpectrumPersistence()
    }

    func testDisablingPersistenceKeepsInMemoryValue() {
        let suiteName = "TheseusSettingsTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create test defaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        settings.enableTintSpectrumPersistence(in: defaults)
        settings.tintSpectrum = 0.5
        settings.disableTintSpectrumPersistence()

        settings.tintSpectrum = 0.1
        XCTAssertEqual(settings.tintSpectrum, 0.1)
        XCTAssertEqual(defaults.double(forKey: TheseusSettings.tintSpectrumDefaultsKey), 0.5, accuracy: 0.0001)
    }

    // MARK: - Notification

    func testSettingsChangePostsNotification() {
        let expectation = expectation(description: "Settings change notification")

        let observer = NotificationCenter.default.addObserver(
            forName: TheseusSettings.settingsDidChangeNotification,
            object: settings,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }

        settings.tierOverride = .tier2

        waitForExpectations(timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
}
