import Foundation
import UIKit

/// Global settings singleton for overriding device tier, quality, and accessibility behaviour.
public final class TheseusSettings {

    public static let shared = TheseusSettings()

    public static let settingsDidChangeNotification = Notification.Name("TheseusSettingsDidChange")

    public var tierOverride: DeviceTier? {
        didSet { postChange() }
    }

    public var effectiveTier: DeviceTier {
        tierOverride ?? TheseusCapability.deviceTier
    }

    public var iosVersionOverride: Int? {
        didSet {
            applySystemTint()
            postChange()
        }
    }

    public var effectiveIOSVersion: Int {
        iosVersionOverride ?? TheseusCapability.iosMajorVersion
    }

    public var refractionPolicyOverride: RefractionPolicy? {
        didSet { postChange() }
    }

    public var effectiveRefractionPolicy: RefractionPolicy {
        if let override = refractionPolicyOverride {
            return override
        }
        return computeRefractionPolicy()
    }

    public var refractionQualityOverride: RefractionQuality? {
        didSet { postChange() }
    }

    public var effectiveRefractionQuality: RefractionQuality {
        if let override = refractionQualityOverride {
            return override
        }
        return computeRefractionQuality()
    }

    public var respectsReduceMotion: Bool = true {
        didSet { postChange() }
    }

    public var respectsReduceTransparency: Bool = true {
        didSet { postChange() }
    }

    public var areMorphAnimationsEnabled: Bool {
        if respectsReduceMotion && isReduceMotionActive {
            return false
        }
        return true
    }

    public var areBlurEffectsEnabled: Bool {
        if respectsReduceTransparency && isReduceTransparencyActive {
            return false
        }
        return true
    }

    /// Clear (0) to tinted (1), clamped; iOS 27's Tint Amount or iOS 26's Clear/Tinted
    /// look. Setting it turns `followsSystemTint` off. Safe to set from any thread.
    public var tintSpectrum: CGFloat = 0.5 {
        didSet {
            if tintSpectrum < 0.0 { tintSpectrum = 0.0 }
            if tintSpectrum > 1.0 { tintSpectrum = 1.0 }
            if !isApplyingSystemTint && followsSystemTint {
                followsSystemTint = false
            }
            persistTintSpectrumIfEnabled()
            postChange()
        }
    }

    /// Which system's glass to draw: `iOS27` reads `tintSpectrum` as Tint Amount, `iOS26`
    /// as Clear (0) to Tinted (1); `automatic` picks `iOS26` on iOS 26, else `iOS27`.
    public enum GlassStyle: Hashable {
        case automatic
        case iOS26
        case iOS27
    }

    public var glassStyle: GlassStyle = .automatic {
        didSet { postChange() }
    }

    /// `glassStyle` with `automatic` resolved for the running system.
    public var effectiveGlassStyle: GlassStyle {
        if glassStyle != .automatic {
            return glassStyle
        }
        return effectiveIOSVersion == 26 ? .iOS26 : .iOS27
    }

    /// Whether `tintSpectrum` tracks the system's Liquid Glass setting. On by
    /// default; setting `tintSpectrum` or enabling its persistence turns it off.
    public var followsSystemTint = true {
        didSet {
            guard followsSystemTint != oldValue else { return }
            updateSystemTintObservation()
        }
    }

    /// The system's Liquid Glass setting as a spectrum value, or nil where there is
    /// none: iOS 27's Tint Amount (0.5 until moved), iOS 26's Clear (0) or Tinted (1).
    public var systemTintSpectrum: CGFloat? {
        let version = effectiveIOSVersion
        let defaults = UserDefaults.standard
        if version >= 27 {
            guard let amount = defaults.object(forKey: Self.systemTintAmountKey) as? NSNumber else { return 0.5 }
            return min(max(CGFloat(amount.doubleValue), 0.0), 1.0)
        }
        if version == 26 {
            return defaults.integer(forKey: Self.systemGlassLegibilityKey) == 1 ? 1.0 : 0.0
        }
        return nil
    }

    static let systemTintAmountKey = "UIViewGlassTintAmount"
    static let systemGlassLegibilityKey = "UIViewGlassLegibilitySetting"

    private var systemTintObservers: [TintSpectrumDefaultsObserver] = []
    private var isApplyingSystemTint = false

    private func updateSystemTintObservation() {
        systemTintObservers.forEach { $0.stop() }
        systemTintObservers = []
        guard followsSystemTint else { return }
        systemTintObservers = [Self.systemTintAmountKey, Self.systemGlassLegibilityKey].map { key in
            TintSpectrumDefaultsObserver(defaults: .standard, key: key) { [weak self] _ in
                self?.applySystemTint()
            }
        }
        applySystemTint()
    }

    private func applySystemTint() {
        let apply = { [weak self] in
            guard let self = self, self.followsSystemTint,
                  let value = self.systemTintSpectrum, value != self.tintSpectrum else { return }
            self.isApplyingSystemTint = true
            self.tintSpectrum = value
            self.isApplyingSystemTint = false
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    @objc private func applicationDidBecomeActive() {
        applySystemTint()
    }

    /// Default UserDefaults key used by `enableTintSpectrumPersistence(in:key:)`.
    public static let tintSpectrumDefaultsKey = "TheseusTintSpectrum"

    private var tintSpectrumDefaults: UserDefaults?
    private var tintSpectrumKey: String = TheseusSettings.tintSpectrumDefaultsKey
    private var tintSpectrumObserver: TintSpectrumDefaultsObserver?
    private var isWritingTintSpectrum = false

    /// Persists `tintSpectrum` in UserDefaults and observes the key through KVO,
    /// so other processes update it. `key` is a KVO key path: no periods.
    public func enableTintSpectrumPersistence(
        in defaults: UserDefaults = .standard,
        key: String = TheseusSettings.tintSpectrumDefaultsKey
    ) {
        followsSystemTint = false
        disableTintSpectrumPersistence()
        tintSpectrumDefaults = defaults
        tintSpectrumKey = key

        tintSpectrumObserver = TintSpectrumDefaultsObserver(defaults: defaults, key: key) { [weak self] stored in
            self?.applyStoredTintSpectrum(stored)
        }

        if defaults.object(forKey: key) == nil {
            persistTintSpectrumIfEnabled()
        }
    }

    /// Stops persisting `tintSpectrum`. The current in-memory value is kept.
    public func disableTintSpectrumPersistence() {
        tintSpectrumObserver?.stop()
        tintSpectrumObserver = nil
        tintSpectrumDefaults = nil
        tintSpectrumKey = TheseusSettings.tintSpectrumDefaultsKey
    }

    private func persistTintSpectrumIfEnabled() {
        guard let defaults = tintSpectrumDefaults, !isWritingTintSpectrum else { return }
        isWritingTintSpectrum = true
        defaults.set(Double(tintSpectrum), forKey: tintSpectrumKey)
        isWritingTintSpectrum = false
    }

    private func applyStoredTintSpectrum(_ stored: Double?) {
        guard !isWritingTintSpectrum, let stored = stored else { return }
        let apply = { [weak self] in
            guard let self = self, self.tintSpectrumDefaults != nil else { return }
            let value = CGFloat(stored)
            if value != self.tintSpectrum {
                self.tintSpectrum = value
            }
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    public var forceFallback: Bool = false {
        didSet { postChange() }
    }

    public var shouldUseFallback: Bool {
        if forceFallback { return true }
        if !TheseusCapability.isMetalAvailable { return true }
        if effectiveTier == .tier0 { return true }
        if effectiveRefractionPolicy == .off { return true }
        if !areBlurEffectsEnabled { return true }
        return false
    }

    public var simulateLowPowerMode: Bool? {
        didSet { postChange() }
    }

    public var simulateReduceTransparency: Bool? {
        didSet { postChange() }
    }

    public var simulateReduceMotion: Bool? {
        didSet { postChange() }
    }

    public var isLowPowerModeActive: Bool {
        simulateLowPowerMode ?? TheseusEnvironment.shared.isLowPowerModeEnabled
    }

    public var isReduceTransparencyActive: Bool {
        simulateReduceTransparency ?? TheseusEnvironment.shared.reduceTransparencyEnabled
    }

    public var isReduceMotionActive: Bool {
        simulateReduceMotion ?? TheseusEnvironment.shared.reduceMotionEnabled
    }

    public var isConstrained: Bool {
        isLowPowerModeActive || TheseusEnvironment.shared.thermalState == .serious ||
            TheseusEnvironment.shared.thermalState == .critical
    }

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(environmentDidChange),
            name: TheseusEnvironment.stateDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        tintSpectrum = systemTintSpectrum ?? 0.5
        updateSystemTintObservation()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func environmentDidChange() {
        postChange()
    }

    private func postChange() {
        let post = {
            NotificationCenter.default.post(
                name: Self.settingsDidChangeNotification,
                object: self
            )
        }
        if Thread.isMainThread {
            post()
        } else {
            DispatchQueue.main.async(execute: post)
        }
    }

    public func resetToDefaults() {
        tierOverride = nil
        iosVersionOverride = nil
        refractionPolicyOverride = nil
        refractionQualityOverride = nil
        forceFallback = false
        respectsReduceMotion = true
        respectsReduceTransparency = true
        simulateLowPowerMode = nil
        simulateReduceTransparency = nil
        simulateReduceMotion = nil
        disableTintSpectrumPersistence()
        glassStyle = .automatic
        tintSpectrum = 0.5
        followsSystemTint = true
    }

    private func computeRefractionPolicy() -> RefractionPolicy {
        if isReduceTransparencyActive {
            return .off
        }

        if isConstrained {
            return .cheapApprox
        }

        let tier = effectiveTier
        let ios = effectiveIOSVersion

        switch tier {
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

    private func computeRefractionQuality() -> RefractionQuality {
        if isConstrained {
            return .low
        }

        let tier = effectiveTier
        let ios = effectiveIOSVersion

        switch tier {
        case .tier0:
            return .low
        case .tier1:
            return .low
        case .tier2:
            return .medium
        case .tier3:
            return ios >= 17 ? .high : .medium
        }
    }

    public func effectivePolicy(for component: TheseusCapability.ComponentType) -> RefractionPolicy {
        let basePolicy = effectiveRefractionPolicy

        guard basePolicy != .off else { return .off }

        let tier = effectiveTier

        switch (tier, component) {
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
}

private final class TintSpectrumDefaultsObserver: NSObject {

    private static var context = 0

    private let defaults: UserDefaults
    private let key: String
    private let handler: (Double?) -> Void
    private var isObserving = false

    init(defaults: UserDefaults, key: String, handler: @escaping (Double?) -> Void) {
        self.defaults = defaults
        self.key = key
        self.handler = handler
        super.init()
        isObserving = true
        defaults.addObserver(
            self,
            forKeyPath: key,
            options: [.new, .initial],
            context: &TintSpectrumDefaultsObserver.context
        )
    }

    deinit {
        stop()
    }

    func stop() {
        guard isObserving else { return }
        isObserving = false
        defaults.removeObserver(self, forKeyPath: key, context: &TintSpectrumDefaultsObserver.context)
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard context == &TintSpectrumDefaultsObserver.context else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        handler((change?[.newKey] as? NSNumber)?.doubleValue)
    }
}
