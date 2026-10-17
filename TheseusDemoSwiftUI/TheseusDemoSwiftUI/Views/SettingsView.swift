import SwiftUI
import Theseus

struct SettingsView: View {
    @State private var tintSpectrum: Double = Double(TheseusSettings.shared.tintSpectrum)
    @State private var followsSystemTint = TheseusSettings.shared.followsSystemTint
    @State private var glassStyle = TheseusSettings.shared.glassStyle
    @State private var tierOverride: DeviceTier?
    @State private var iosVersionOverride: Int?
    @State private var policyOverride: RefractionPolicy?
    @State private var qualityOverride: RefractionQuality?
    @State private var forceFallback = false
    @State private var simulateLowPower: Bool?
    @State private var simulateReduceTransparency: Bool?
    @State private var simulateReduceMotion: Bool?

    private let settings = TheseusSettings.shared

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Device")
                        .font(.headline)

                    Group {
                        InfoRow(label: "Tier", value: settings.effectiveTier.description)
                        InfoRow(label: "iOS Version", value: "\(settings.effectiveIOSVersion)")
                        InfoRow(label: "Policy", value: settings.effectiveRefractionPolicy.description)
                        InfoRow(label: "Quality", value: settings.effectiveRefractionQuality.description)
                        InfoRow(label: "Fallback Active", value: settings.shouldUseFallback ? "Yes" : "No")
                    }
                }
            }

            Section {
                Toggle("Follow System Setting", isOn: followsSystemTintBinding)
                Picker("Style", selection: glassStyleBinding) {
                    Text("Automatic").tag(TheseusSettings.GlassStyle.automatic)
                    Text("iOS 26").tag(TheseusSettings.GlassStyle.iOS26)
                    Text("iOS 27").tag(TheseusSettings.GlassStyle.iOS27)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        Text("Clear")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: tintSpectrumBinding, in: 0...1)
                        Text("Tinted")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("The iOS 27 style reads this as Tint Amount; the iOS 26 style runs from Clear to Tinted. Moving the slider stops following the system setting.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Liquid Glass Appearance")
            }

            Section("Device Tier Override") {
                Picker("Tier", selection: tierBinding) {
                    Text("Auto-detect").tag(-1)
                    Text("Tier 0 (Basic)").tag(0)
                    Text("Tier 1 (Low)").tag(1)
                    Text("Tier 2 (Medium)").tag(2)
                    Text("Tier 3 (High)").tag(3)
                }
                .onChange(of: tierBinding.wrappedValue) { newValue in
                    settings.tierOverride = newValue == -1 ? nil : DeviceTier(rawValue: newValue)
                }
            }

            Section("iOS Version Override") {
                Picker("iOS Version", selection: iosBinding) {
                    Text("Auto-detect").tag(-1)
                    Text("iOS 13").tag(13)
                    Text("iOS 14").tag(14)
                    Text("iOS 15").tag(15)
                    Text("iOS 16").tag(16)
                    Text("iOS 17").tag(17)
                    Text("iOS 18").tag(18)
                    Text("iOS 26").tag(26)
                    Text("iOS 27").tag(27)
                }
                .onChange(of: iosBinding.wrappedValue) { newValue in
                    settings.iosVersionOverride = newValue == -1 ? nil : newValue
                }
            }

            Section("Refraction Policy Override") {
                Picker("Policy", selection: policyBinding) {
                    Text("Auto-select").tag(-1)
                    Text("Off").tag(0)
                    Text("Cheap Approximation").tag(1)
                    Text("True Refraction").tag(2)
                }
                .onChange(of: policyBinding.wrappedValue) { newValue in
                    settings.refractionPolicyOverride = newValue == -1 ? nil : RefractionPolicy(rawValue: newValue)
                }
            }

            Section("Refraction Quality Override") {
                Picker("Quality", selection: qualityBinding) {
                    Text("Auto-select").tag(-1)
                    Text("Low (15Hz)").tag(0)
                    Text("Medium (30Hz)").tag(1)
                    Text("High (60Hz)").tag(2)
                }
                .onChange(of: qualityBinding.wrappedValue) { newValue in
                    settings.refractionQualityOverride = newValue == -1 ? nil : RefractionQuality(rawValue: newValue)
                }
            }

            Section("Rendering") {
                Toggle("Force Fallback Mode", isOn: $forceFallback)
                    .onChange(of: forceFallback) { newValue in
                        settings.forceFallback = newValue
                    }
            }

            Section("Environment Simulation") {
                Toggle("Low Power Mode", isOn: lowPowerBinding)
                    .onChange(of: lowPowerBinding.wrappedValue) { newValue in
                        settings.simulateLowPowerMode = newValue ? true : nil
                    }

                Toggle("Reduce Transparency", isOn: reduceTransparencyBinding)
                    .onChange(of: reduceTransparencyBinding.wrappedValue) { newValue in
                        settings.simulateReduceTransparency = newValue ? true : nil
                    }

                Toggle("Reduce Motion", isOn: reduceMotionBinding)
                    .onChange(of: reduceMotionBinding.wrappedValue) { newValue in
                        settings.simulateReduceMotion = newValue ? true : nil
                    }
            }

            Section {
                Button("Reset to Defaults", role: .destructive) {
                    settings.resetToDefaults()
                    loadCurrentSettings()
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            loadCurrentSettings()
        }
    }

    private func loadCurrentSettings() {
        tintSpectrum = Double(settings.tintSpectrum)
        followsSystemTint = settings.followsSystemTint
        glassStyle = settings.glassStyle
        tierOverride = settings.tierOverride
        iosVersionOverride = settings.iosVersionOverride
        policyOverride = settings.refractionPolicyOverride
        qualityOverride = settings.refractionQualityOverride
        forceFallback = settings.forceFallback
        simulateLowPower = settings.simulateLowPowerMode
        simulateReduceTransparency = settings.simulateReduceTransparency
        simulateReduceMotion = settings.simulateReduceMotion
    }

    private var tintSpectrumBinding: Binding<Double> {
        Binding(
            get: { tintSpectrum },
            set: { newValue in
                tintSpectrum = newValue
                settings.tintSpectrum = CGFloat(newValue)
                followsSystemTint = settings.followsSystemTint
            }
        )
    }

    private var followsSystemTintBinding: Binding<Bool> {
        Binding(
            get: { followsSystemTint },
            set: { newValue in
                settings.followsSystemTint = newValue
                followsSystemTint = newValue
                tintSpectrum = Double(settings.tintSpectrum)
            }
        )
    }

    private var glassStyleBinding: Binding<TheseusSettings.GlassStyle> {
        Binding(
            get: { glassStyle },
            set: { newValue in
                settings.glassStyle = newValue
                glassStyle = newValue
            }
        )
    }

    private var tierBinding: Binding<Int> {
        Binding(
            get: { tierOverride?.rawValue ?? -1 },
            set: { tierOverride = $0 == -1 ? nil : DeviceTier(rawValue: $0) }
        )
    }

    private var iosBinding: Binding<Int> {
        Binding(
            get: { iosVersionOverride ?? -1 },
            set: { iosVersionOverride = $0 == -1 ? nil : $0 }
        )
    }

    private var policyBinding: Binding<Int> {
        Binding(
            get: { policyOverride?.rawValue ?? -1 },
            set: { policyOverride = $0 == -1 ? nil : RefractionPolicy(rawValue: $0) }
        )
    }

    private var qualityBinding: Binding<Int> {
        Binding(
            get: { qualityOverride?.rawValue ?? -1 },
            set: { qualityOverride = $0 == -1 ? nil : RefractionQuality(rawValue: $0) }
        )
    }

    private var lowPowerBinding: Binding<Bool> {
        Binding(
            get: { simulateLowPower == true },
            set: { simulateLowPower = $0 ? true : nil }
        )
    }

    private var reduceTransparencyBinding: Binding<Bool> {
        Binding(
            get: { simulateReduceTransparency == true },
            set: { simulateReduceTransparency = $0 ? true : nil }
        )
    }

    private var reduceMotionBinding: Binding<Bool> {
        Binding(
            get: { simulateReduceMotion == true },
            set: { simulateReduceMotion = $0 ? true : nil }
        )
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

#Preview {
    NavigationView {
        SettingsView()
    }
}
