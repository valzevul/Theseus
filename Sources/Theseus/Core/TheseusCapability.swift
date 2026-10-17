import UIKit
import Metal

/// System-level refraction policy based on device capabilities and power state.
public enum RefractionPolicy: Int, CaseIterable, Sendable {
    case off = 0
    case cheapApprox = 1
    case trueRefraction = 2

    public var description: String {
        switch self {
        case .off: return "Off"
        case .cheapApprox: return "Cheap Approximation"
        case .trueRefraction: return "True Refraction"
        }
    }
}

/// Frame rate and render scale for refraction effects.
public enum RefractionQuality: Int, CaseIterable, Sendable {
    case low = 0
    case medium = 1
    case high = 2

    public var frameRate: Int {
        switch self {
        case .low: return 15
        case .medium: return 30
        case .high: return 60
        }
    }

    public var renderScale: CGFloat {
        switch self {
        case .low: return 0.25
        case .medium: return 0.5
        case .high: return 1.0
        }
    }

    public var description: String {
        switch self {
        case .low: return "Low (15Hz, 0.25x)"
        case .medium: return "Medium (30Hz, 0.5x)"
        case .high: return "High (60Hz, 1.0x)"
        }
    }
}

/// Device performance classification based on RAM and processor count.
public enum DeviceTier: Int, Comparable, CaseIterable, Sendable {
    case tier0 = 0
    case tier1 = 1
    case tier2 = 2
    case tier3 = 3

    public static func < (lhs: DeviceTier, rhs: DeviceTier) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    public var description: String {
        switch self {
        case .tier0: return "Tier 0 (Basic)"
        case .tier1: return "Tier 1 (Low)"
        case .tier2: return "Tier 2 (Medium)"
        case .tier3: return "Tier 3 (High)"
        }
    }
}

/// Static utilities for detecting device capabilities and recommended settings.
public enum TheseusCapability {

    public static var deviceTier: DeviceTier {
        let memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)
        let processorCount = ProcessInfo.processInfo.processorCount

        if memoryGB >= 6.0 && processorCount >= 6 {
            return .tier3
        } else if memoryGB >= 4.0 && processorCount >= 6 {
            return .tier2
        } else if memoryGB >= 3.0 {
            return .tier1
        } else {
            return .tier0
        }
    }

    public static var physicalMemoryGB: Double {
        Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)
    }

    public static var processorCount: Int {
        ProcessInfo.processInfo.processorCount
    }

    @available(*, deprecated, message: "Unused; compose from deviceTier, physicalMemoryGB and processorCount.")
    public static var deviceInfoString: String {
        let tier = deviceTier
        let memoryGB = physicalMemoryGB
        let cores = processorCount
        return "\(tier.description) (\(String(format: "%.1f", memoryGB)) GB RAM, \(cores) cores)"
    }

    public static var iosMajorVersion: Int {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    }

    public static var iosVersionString: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion)"
    }

    @available(*, deprecated, message: "Unused; use TheseusSettings.shared.effectiveRefractionPolicy.")
    public static var recommendedRefractionPolicy: RefractionPolicy {
        let env = TheseusEnvironment.shared

        if env.reduceTransparencyEnabled {
            return .off
        }

        if env.isConstrained {
            return .cheapApprox
        }

        let ios = iosMajorVersion

        switch deviceTier {
        case .tier0:
            return .cheapApprox
        case .tier1:
            return ios >= 17 ? .trueRefraction : .cheapApprox
        case .tier2:
            return ios >= 15 ? .trueRefraction : .cheapApprox
        case .tier3:
            return .trueRefraction
        }
    }

    @available(*, deprecated, message: "Unused; use TheseusSettings.shared.effectiveRefractionQuality.")
    public static var recommendedRefractionQuality: RefractionQuality {
        let env = TheseusEnvironment.shared

        if env.isConstrained {
            return .low
        }

        switch deviceTier {
        case .tier0:
            return .low
        case .tier1:
            return .low
        case .tier2:
            return .medium
        case .tier3:
            return iosMajorVersion >= 17 ? .high : .medium
        }
    }

    @available(*, deprecated, message: "Unused; use TheseusSettings.shared.effectivePolicy(for:).")
    public static func recommendedPolicy(for component: ComponentType) -> RefractionPolicy {
        let basePolicy = recommendedRefractionPolicy

        guard basePolicy != .off else { return .off }

        switch (deviceTier, component) {
        case (.tier0, _):
            return .cheapApprox
        case (.tier1, .tabBar):
            return basePolicy
        case (.tier1, _):
            return .cheapApprox
        case (.tier2, .tabBar), (.tier2, .switch):
            return basePolicy
        case (.tier2, _):
            return .cheapApprox
        case (.tier3, _):
            return basePolicy
        }
    }

    public enum ComponentType {
        case tabBar
        case button
        case `switch`
        case slider
        case glassView
    }

    @available(*, deprecated, message: "Unused; compose from TheseusSettings.shared.effectiveRefractionPolicy and effectiveRefractionQuality.")
    public static var policyInfoString: String {
        let policy = recommendedRefractionPolicy
        let quality = recommendedRefractionQuality
        return "\(policy.description) @ \(quality.description)"
    }

    public static var isDeviceSupported: Bool {
        guard MTLCreateSystemDefaultDevice() != nil else {
            return false
        }

        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        return !isUnsupportedDevice(identifier: identifier)
    }

    public static var isMetalAvailable: Bool {
        MTLCreateSystemDefaultDevice() != nil
    }

    public static var recommendedQuality: QualityLevel {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return .low
        }

        if device.supportsFamily(.apple7) {
            return .ultra
        } else if device.supportsFamily(.apple5) {
            return .high
        } else if device.supportsFamily(.apple4) {
            return .medium
        } else if device.supportsFamily(.apple3) {
            return .medium
        }

        return .high
    }

    static func isUnsupportedDevice(identifier: String) -> Bool {
        // The trailing comma is load-bearing: "iPhone1," must not match
        // "iPhone10,x" to "iPhone19,x".
        let unsupportedPrefixes = [
            "iPod1,", "iPod2,", "iPod3,", "iPod4,", "iPod5,", "iPod7,", "iPod9,",
            "iPhone1,", "iPhone2,", "iPhone3,", "iPhone4,", "iPhone5,",
            "iPhone6,", "iPhone7,", "iPhone8,", "iPhone9,", "iPhone10,",
            "iPhone11,8"
        ]

        if unsupportedPrefixes.contains(where: { identifier.hasPrefix($0) }) {
            return true
        }

        let unsupportedModels = [
            "iPhone1,1", "iPhone1,2",
            "iPhone2,1",
            "iPhone3,1", "iPhone3,2", "iPhone3,3",
            "iPhone4,1",
            "iPhone5,1", "iPhone5,2", "iPhone5,3", "iPhone5,4",
            "iPhone6,1", "iPhone6,2",
            "iPhone7,1", "iPhone7,2",
            "iPhone8,1", "iPhone8,2", "iPhone8,4",
            "iPhone9,1", "iPhone9,2", "iPhone9,3", "iPhone9,4",
            "iPhone10,1", "iPhone10,2", "iPhone10,3", "iPhone10,4", "iPhone10,5", "iPhone10,6",
            "iPhone11,2", "iPhone11,4", "iPhone11,6", "iPhone11,8"
        ]

        return unsupportedModels.contains(identifier)
    }
}

/// Monitors system state: Low Power Mode, thermal state, and accessibility settings.
public final class TheseusEnvironment {

    public static let shared = TheseusEnvironment()

    public static let stateDidChangeNotification = Notification.Name("TheseusEnvironmentStateDidChange")

    public private(set) var isLowPowerModeEnabled: Bool = false

    public private(set) var thermalState: ProcessInfo.ThermalState = .nominal

    public var isConstrained: Bool {
        isLowPowerModeEnabled || thermalState == .serious || thermalState == .critical
    }

    public private(set) var reduceTransparencyEnabled: Bool = false

    public private(set) var reduceMotionEnabled: Bool = false

    public private(set) var increaseContrastEnabled: Bool = false

    @available(*, deprecated, message: "Unused; use TheseusSettings.shared.areBlurEffectsEnabled.")
    public var shouldUseBlur: Bool {
        !reduceTransparencyEnabled
    }

    @available(*, deprecated, message: "Unused; use TheseusSettings.shared.areMorphAnimationsEnabled.")
    public var shouldUseSpringAnimations: Bool {
        !reduceMotionEnabled
    }

    public var stateDescription: String {
        var flags: [String] = []
        if isLowPowerModeEnabled { flags.append("LowPower") }
        if thermalState != .nominal { flags.append("Thermal:\(thermalStateString)") }
        if reduceTransparencyEnabled { flags.append("ReduceTransparency") }
        if reduceMotionEnabled { flags.append("ReduceMotion") }
        if increaseContrastEnabled { flags.append("HighContrast") }
        return flags.isEmpty ? "Normal" : flags.joined(separator: ", ")
    }

    private var thermalStateString: String {
        switch thermalState {
        case .nominal: return "Normal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    private init() {
        refreshState()
        setupObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func refreshState() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        thermalState = ProcessInfo.processInfo.thermalState
        reduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        reduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        increaseContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
    }

    private func setupObservers() {
        let nc = NotificationCenter.default

        nc.addObserver(
            self,
            selector: #selector(powerStateDidChange),
            name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(thermalStateDidChange),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )

        nc.addObserver(
            self,
            selector: #selector(accessibilityDidChange),
            name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(accessibilityDidChange),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(accessibilityDidChange),
            name: UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            object: nil
        )
    }

    @objc private func powerStateDidChange() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        postStateChange()
    }

    @objc private func thermalStateDidChange() {
        thermalState = ProcessInfo.processInfo.thermalState
        postStateChange()
    }

    @objc private func accessibilityDidChange() {
        reduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        reduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        increaseContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
        postStateChange()
    }

    private func postStateChange() {
        let post = {
            NotificationCenter.default.post(
                name: Self.stateDidChangeNotification,
                object: self
            )
        }
        if Thread.isMainThread {
            post()
        } else {
            DispatchQueue.main.async(execute: post)
        }
    }
}

/// Metal GPU family-based quality presets affecting blur radius and render scale.
public enum QualityLevel: Int, CaseIterable, Sendable {
    case low = 0
    case medium = 1
    case high = 2
    case ultra = 3

    public var maxBlurRadius: Int {
        switch self {
        case .low: return 16
        case .medium: return 32
        case .high: return 64
        case .ultra: return 100
        }
    }

    public var renderScale: CGFloat {
        switch self {
        case .low: return 0.5
        case .medium: return 0.75
        case .high: return 1.0
        case .ultra: return 1.0
        }
    }

    public var description: String {
        switch self {
        case .low: return "Low (iPhone 6s/7)"
        case .medium: return "Medium (iPhone 8/X)"
        case .high: return "High (iPhone 11+)"
        case .ultra: return "Ultra (iPhone 12 Pro+)"
        }
    }
}
