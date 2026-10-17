// Standalone native reference. Build for the simulator:
//   mkdir -p NativeRef.app  (Info.plist: CFBundleExecutable=NativeRef,
//   CFBundleIdentifier=com.example.NativeRef, UILaunchScreen={}, MinimumOSVersion=26.0)
//   xcrun -sdk iphonesimulator swiftc -target arm64-apple-ios26.0-simulator \
//     -parse-as-library -O NativeRef.swift -o NativeRef.app/NativeRef
//   xcrun simctl install <udid> NativeRef.app && xcrun simctl launch <udid> com.example.NativeRef

import SwiftUI

@main
struct NativeRefApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            ReferenceScreen()
                .tabItem { Label("Today", systemImage: "doc.text.image") }
            Color.clear
                .tabItem { Label("Games", systemImage: "gamecontroller") }
            Color.clear
                .tabItem { Label("Apps", systemImage: "square.stack.3d.up") }
            Color.clear
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
        }
    }
}

struct ReferenceScreen: View {
    @State private var toggleOn = true
    @State private var sliderValue = 0.6

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.92, green: 0.82, blue: 0.98),
                        Color(red: 0.82, green: 0.95, blue: 0.98),
                        Color(red: 0.98, green: 0.95, blue: 0.82),
                        Color(red: 0.98, green: 0.82, blue: 0.88)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 28) {
                    Spacer()

                    VStack(spacing: 20) {
                        Toggle("Native switch", isOn: $toggleOn)
                            .frame(width: 220)
                        Slider(value: $sliderValue)
                            .frame(width: 220)
                    }

                    Spacer()

                    VStack(spacing: 18) {
                        Text("Regular glass")
                            .padding(.horizontal, 36).padding(.vertical, 20)
                            .glassEffect()
                        Text("Tinted glass")
                            .padding(.horizontal, 36).padding(.vertical, 20)
                            .glassEffect(.regular.tint(.blue.opacity(0.8)))
                        Text("Clear glass")
                            .padding(.horizontal, 36).padding(.vertical, 20)
                            .glassEffect(.clear)
                    }

                    Spacer()

                    HStack(spacing: 16) {
                        Button("Action") {}
                            .buttonStyle(.glass)
                        Button("Primary") {}
                            .buttonStyle(.glassProminent)
                    }

                    Spacer()
                }
            }
            .navigationTitle("Native Ref")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { } label: { Image(systemName: "moon.fill") }
                    Button { } label: { Image(systemName: "gearshape.fill") }
                }
            }
        }
    }
}
