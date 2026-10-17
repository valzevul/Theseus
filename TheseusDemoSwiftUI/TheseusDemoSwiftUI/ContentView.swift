import SwiftUI

struct ContentView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false

    // `-demo <tag>` deep-routes into a screen. Set from onAppear after a delay:
    // setting it before the NavigationView attaches fails silently on iOS 15/16.
    @State private var demoSelection: String?

    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: Glass27DemoView(), tag: "glass27", selection: $demoSelection) {
                    DemoRow(
                        icon: "sparkles",
                        title: "iOS 27 Glass",
                        description: "Tint, spectrum, shape merging, dimming"
                    )
                }

                NavigationLink(destination: TabBarDemoView(), tag: "tabbar", selection: $demoSelection) {
                    DemoRow(
                        icon: "rectangle.split.3x1",
                        title: "Tab Bar",
                        description: "Liquid glass tab bar component"
                    )
                }

                NavigationLink(destination: LensLabView(), tag: "lenslab", selection: $demoSelection) {
                    DemoRow(
                        icon: "slider.horizontal.3",
                        title: "Lens Lab",
                        description: "Tune the drag lens live against the native bar"
                    )
                }

                NavigationLink(destination: SwitchDemoView(), tag: "switch", selection: $demoSelection) {
                    DemoRow(
                        icon: "switch.2",
                        title: "Switch",
                        description: "Toggle switch with glass morphing"
                    )
                }

                NavigationLink(destination: SliderDemoView(), tag: "slider", selection: $demoSelection) {
                    DemoRow(
                        icon: "slider.horizontal.3",
                        title: "Slider",
                        description: "Slider with liquid glass knob"
                    )
                }

                NavigationLink(destination: GlassViewDemoView(), tag: "glassview", selection: $demoSelection) {
                    DemoRow(
                        icon: "rectangle.on.rectangle",
                        title: "Glass View",
                        description: "Custom glass effect view"
                    )
                }

                NavigationLink(destination: SettingsView(), tag: "settings", selection: $demoSelection) {
                    DemoRow(
                        icon: "gearshape.fill",
                        title: "Settings",
                        description: "Configure device tier and quality"
                    )
                }
            }
            .navigationTitle("Theseus Demo")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isDarkMode.toggle() }) {
                        Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear {
            guard let target = UserDefaults.standard.string(forKey: "demo"),
                  demoSelection == nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                demoSelection = target
            }
        }
    }
}

struct DemoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ContentView()
}
