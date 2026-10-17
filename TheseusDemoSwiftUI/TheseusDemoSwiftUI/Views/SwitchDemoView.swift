import SwiftUI
import Theseus

struct SwitchDemoView: View {
    @State private var isOn = false
    @State private var showingSettings = false
    @AppStorage("isDarkMode") private var isDarkMode = false

    // Settings
    @State private var onColorIndex = 0
    @State private var offColorIndex = 0
    @State private var thumbColorIndex = 0

    private let onColors: [UIColor] = [
        UIColor(red: 0.259, green: 0.831, blue: 0.318, alpha: 1.0),
        .systemBlue,
        .systemPurple,
        .systemOrange
    ]

    private let offColors: [UIColor?] = [
        nil,
        UIColor(red: 1.0, green: 0.8, blue: 0.8, alpha: 1.0),
        UIColor(red: 1.0, green: 0.85, blue: 0.9, alpha: 1.0),
        UIColor(red: 0.85, green: 0.78, blue: 0.72, alpha: 1.0)
    ]

    private let thumbColors: [UIColor] = [
        .white,
        UIColor(white: 0.15, alpha: 1.0),
        UIColor(red: 1.0, green: 0.98, blue: 0.94, alpha: 1.0),
        UIColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1.0)
    ]

    var body: some View {
        ZStack {
            if let pattern = UserDefaults.standard.string(forKey: "rigPattern"),
               pattern.hasPrefix("flat:"), let flat = flatColor(hex: String(pattern.dropFirst(5))) {
                flat.ignoresSafeArea()
            } else {
                GradientBackground(isDarkMode: isDarkMode)
            }

            VStack(spacing: 50) {
                // Native Switch
                HStack {
                    Text("Native UISwitch")
                        .font(.system(size: 16, weight: .medium))
                    Spacer()
                    Toggle("", isOn: $isOn)
                        .tint(Color(onColors[onColorIndex]))
                        .labelsHidden()
                }
                .frame(width: 280)

                // Theseus Switch
                HStack {
                    Text("TheseusSwitch")
                        .font(.system(size: 16, weight: .medium))
                    Spacer()
                    TheseusSwitchRepresentable(
                        isOn: $isOn,
                        onTintColor: onColors[onColorIndex],
                        offTintColor: offColors[offColorIndex],
                        thumbTintColor: thumbColors[thumbColorIndex]
                    )
                    .frame(width: 63, height: 28)
                    .offset(x: 2)
                }
                .frame(width: 280)
            }
        }
        .navigationTitle("Switch")
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
            SwitchSettingsSheet(
                onColorIndex: $onColorIndex,
                offColorIndex: $offColorIndex,
                thumbColorIndex: $thumbColorIndex
            )
        }
    }
}

struct SwitchSettingsSheet: View {
    @Binding var onColorIndex: Int
    @Binding var offColorIndex: Int
    @Binding var thumbColorIndex: Int
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("On Color") {
                    Picker("On Color", selection: $onColorIndex) {
                        Text("Green").tag(0)
                        Text("Blue").tag(1)
                        Text("Purple").tag(2)
                        Text("Orange").tag(3)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Off Color") {
                    Picker("Off Color", selection: $offColorIndex) {
                        Text("Default").tag(0)
                        Text("Red").tag(1)
                        Text("Pink").tag(2)
                        Text("Brown").tag(3)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Thumb Color") {
                    Picker("Thumb Color", selection: $thumbColorIndex) {
                        Text("White").tag(0)
                        Text("Black").tag(1)
                        Text("Cream").tag(2)
                        Text("Silver").tag(3)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button("Reset to Defaults", role: .destructive) {
                        onColorIndex = 0
                        offColorIndex = 0
                        thumbColorIndex = 0
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
        SwitchDemoView()
    }
}
