import SwiftUI
import Theseus

struct SliderDemoView: View {
    @State private var value: CGFloat = 50
    @State private var nativeValue: Double = 50
    @State private var showingSettings = false
    @AppStorage("isDarkMode") private var isDarkMode = false

    // Settings
    @State private var trackColorIndex = 0
    @State private var positionsCount = 0

    private let trackColors: [UIColor] = [
        .systemBlue,
        .systemGreen,
        .systemPurple,
        .systemOrange
    ]

    private let trackSwiftUIColors: [Color] = [.blue, .green, .purple, .orange]

    var body: some View {
        ZStack {
            if let pattern = UserDefaults.standard.string(forKey: "rigPattern"),
               pattern.hasPrefix("flat:"), let flat = flatColor(hex: String(pattern.dropFirst(5))) {
                flat.ignoresSafeArea()
            } else {
                GradientBackground(isDarkMode: isDarkMode)
            }

            VStack(spacing: 50) {
                // Value display
                Text("Value: \(Int(value))")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()

                VStack(spacing: 40) {
                    // Native Slider
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Native UISlider")
                            .font(.system(size: 14, weight: .medium))

                        Slider(value: $nativeValue, in: 0...100)
                            .tint(trackSwiftUIColors[trackColorIndex])
                            .onChange(of: nativeValue) { newValue in
                                value = CGFloat(newValue)
                            }
                    }

                    // Theseus Slider
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TheseusSlider")
                            .font(.system(size: 14, weight: .medium))

                        TheseusSliderRepresentable(
                            value: $value,
                            minimumValue: 0,
                            maximumValue: 100,
                            trackColor: trackColors[trackColorIndex],
                            positionsCount: positionsCount
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        .onChange(of: value) { newValue in
                            nativeValue = Double(newValue)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle("Slider")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { isDarkMode.toggle() }) {
                    Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                }
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SliderSettingsSheet(
                trackColorIndex: $trackColorIndex,
                positionsCount: $positionsCount
            )
        }
    }
}

struct SliderSettingsSheet: View {
    @Binding var trackColorIndex: Int
    @Binding var positionsCount: Int
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Track Color") {
                    Picker("Color", selection: $trackColorIndex) {
                        Text("Blue").tag(0)
                        Text("Green").tag(1)
                        Text("Purple").tag(2)
                        Text("Orange").tag(3)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Discrete Positions") {
                    Picker("Positions", selection: $positionsCount) {
                        Text("Continuous").tag(0)
                        Text("5 Steps").tag(5)
                        Text("10 Steps").tag(10)
                        Text("20 Steps").tag(20)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button("Reset to Defaults", role: .destructive) {
                        trackColorIndex = 0
                        positionsCount = 0
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        SliderDemoView()
    }
}
