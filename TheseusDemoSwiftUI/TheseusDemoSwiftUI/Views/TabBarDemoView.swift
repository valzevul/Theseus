import Combine
import SwiftUI
import Theseus

struct TabBarDemoView: View {
    @StateObject private var lensSettings = LensLabSettings()
    @State private var selectedIndex = 0
    @State private var nativeSelectedIndex = 0
    @State private var showingSettings = false
    @AppStorage("isDarkMode") private var isDarkMode = false

    // Settings
    @State private var tintColorIndex = 0
    @State private var blurRadius: Float = 0.0
    @State private var cycleStep = 0
    private let cycleColors = (UserDefaults.standard.string(forKey: "rigCycle") ?? "").split(separator: ",").map(String.init)
    private let cycleTimer = Timer.publish(every: max(UserDefaults.standard.double(forKey: "rigCyclePeriod"), 0.5), on: .main, in: .common).autoconnect()

    private let tintColors: [Color] = [.blue, .purple, .pink, .orange]
    private let tintUIColors: [UIColor] = [.systemBlue, .systemPurple, .systemPink, .systemOrange]

    private var tabItems: [TheseusTabBarItem] {
        if let test = DemoTabIcon.image {
            return ["Today", "Games", "Apps", "Arcade", "Search"].map { TheseusTabBarItem(icon: test, title: $0) }
        }
        return [
            TheseusTabBarItem(icon: UIImage(systemName: "doc.text.image"), selectedIcon: UIImage(systemName: "doc.text.image.fill"), title: "Today"),
            TheseusTabBarItem(icon: UIImage(systemName: "gamecontroller"), selectedIcon: UIImage(systemName: "gamecontroller.fill"), title: "Games"),
            TheseusTabBarItem(icon: UIImage(systemName: "square.stack.3d.up.fill"), title: "Apps"),
            TheseusTabBarItem(icon: UIImage(systemName: "dpad.fill"), title: "Arcade"),
            TheseusTabBarItem(icon: UIImage(systemName: "magnifyingglass"), title: "Search")
        ]
    }

    var body: some View {
        ZStack {
            if !cycleColors.isEmpty, let flat = flatColor(hex: cycleColors[cycleStep % cycleColors.count]) {
                flat.ignoresSafeArea()
            } else if let pattern = UserDefaults.standard.string(forKey: "rigPattern") {
                if pattern.hasPrefix("flat:"), let flat = flatColor(hex: String(pattern.dropFirst(5))) {
                    flat.ignoresSafeArea()
                } else if pattern == "noise" {
                    NoisePattern()
                } else if ["coord", "xcoord", "ycoord", "checker", "vstripes6", "hstripes6"].contains(pattern) {
                    CoordBackdrop(kind: pattern).ignoresSafeArea()
                } else {
                    StripePattern(vertical: pattern == "vstripes" || pattern == "gvstripes" || pattern == "gsteps", grey: pattern.hasPrefix("g"), steps: pattern == "gsteps")
                }
            } else {
                GradientBackground(isDarkMode: isDarkMode)
            }

            VStack(spacing: 40) {
                // Native TabBar
                VStack(alignment: .leading, spacing: 8) {
                    Text("Native UITabBar")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .offset(y: -17)

                    NativeTabBarRepresentable(
                        selectedIndex: $nativeSelectedIndex,
                        tintColor: tintUIColors[tintColorIndex]
                    )
                    .frame(height: 49)
                    .onChange(of: nativeSelectedIndex) { newValue in
                        selectedIndex = newValue
                    }
                }

                // Theseus TabBar
                VStack(alignment: .leading, spacing: 8) {
                    Text("TheseusTabBar")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)

                    TheseusTabBarRepresentable(
                        items: tabItems,
                        selectedIndex: $selectedIndex,
                        selectedTintColor: tintUIColors[tintColorIndex],
                        glassBlurRadius: CGFloat(blurRadius),
                        lensMaterial: lensSettings.material,
                        backdropVersion: cycleStep
                    )
                    .frame(height: 63)
                    .onChange(of: selectedIndex) { newValue in
                        nativeSelectedIndex = newValue
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .onReceive(cycleTimer) { _ in
            if !cycleColors.isEmpty {
                cycleStep += 1
            }
        }
        .navigationTitle("Tab Bar")
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
            TabBarSettingsSheet(
                tintColorIndex: $tintColorIndex,
                blurRadius: $blurRadius
            )
        }
    }
}

enum DemoTabIcon {
    static let image: UIImage? = {
        guard UserDefaults.standard.string(forKey: "tabIcon") == "bars" else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let size = CGSize(width: 28, height: 28)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            for index in 0..<4 {
                context.fill(CGRect(x: CGFloat(index) * 7.5, y: 0, width: 3.5, height: 28))
            }
        }.withRenderingMode(.alwaysTemplate)
    }()
}

struct NativeTabBarRepresentable: UIViewRepresentable {
    @Binding var selectedIndex: Int
    var tintColor: UIColor

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITabBar {
        let tabBar = UITabBar()
        if let test = DemoTabIcon.image {
            tabBar.items = ["Today", "Games", "Apps", "Arcade", "Search"].enumerated().map { UITabBarItem(title: $0.element, image: test, tag: $0.offset) }
        } else {
        tabBar.items = [
            UITabBarItem(title: "Today", image: UIImage(systemName: "doc.text.image"), selectedImage: UIImage(systemName: "doc.text.image.fill")),
            UITabBarItem(title: "Games", image: UIImage(systemName: "gamecontroller"), selectedImage: UIImage(systemName: "gamecontroller.fill")),
            UITabBarItem(title: "Apps", image: UIImage(systemName: "square.stack.3d.up.fill"), tag: 2),
            UITabBarItem(title: "Arcade", image: UIImage(systemName: "dpad.fill"), tag: 3),
            UITabBarItem(title: "Search", image: UIImage(systemName: "magnifyingglass"), tag: 4)
        ]
        }
        tabBar.selectedItem = tabBar.items?[selectedIndex]
        tabBar.tintColor = tintColor
        tabBar.delegate = context.coordinator
        return tabBar
    }

    func updateUIView(_ uiView: UITabBar, context: Context) {
        uiView.selectedItem = uiView.items?[selectedIndex]
        uiView.tintColor = tintColor
    }

    class Coordinator: NSObject, UITabBarDelegate {
        var parent: NativeTabBarRepresentable

        init(_ parent: NativeTabBarRepresentable) {
            self.parent = parent
        }

        func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
            if let index = tabBar.items?.firstIndex(of: item) {
                parent.selectedIndex = index
            }
        }
    }
}


struct CoordBackdrop: UIViewRepresentable {
    var kind: String
    func makeUIView(context: Context) -> CoordBackdropView { CoordBackdropView(kind: kind) }
    func updateUIView(_ uiView: CoordBackdropView, context: Context) {}
}

final class CoordBackdropView: UIImageView {
    private let kind: String
    private var builtSize: CGSize = .zero
    init(kind: String) {
        self.kind = kind
        super.init(frame: .zero)
        layer.magnificationFilter = .nearest
        layer.minificationFilter = .nearest
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let window = window, bounds.size != builtSize, bounds.width > 0 else { return }
        builtSize = bounds.size
        let scale = window.screen.scale
        let origin = convert(CGPoint.zero, to: window)
        let width = Int(bounds.width * scale), height = Int(bounds.height * scale)
        let ox = Int((origin.x * scale).rounded()), oy = Int((origin.y * scale).rounded())
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let gx = x + ox, gy = y + oy, i = (y * width + x) * 4
                var r: UInt8 = 0, g: UInt8 = 0, b: UInt8 = 0
                switch kind {
                case "coord": r = UInt8(gx & 255); g = UInt8(gy & 255)
                case "xcoord": r = UInt8(gx & 255); g = r; b = r
                case "ycoord": r = UInt8(gy & 255); g = r; b = r
                case "checker": r = ((gx / 24) + (gy / 24)) % 2 == 0 ? 255 : 0; g = r; b = r
                case "vstripes6": r = (gx / 6) % 2 == 0 ? 255 : 0; g = r; b = r
                default: r = (gy / 6) % 2 == 0 ? 255 : 0; g = r; b = r
                }
                bytes[i] = r; bytes[i + 1] = g; bytes[i + 2] = b; bytes[i + 3] = 255
            }
        }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
              let cgImage = context.makeImage() else { return }
        image = UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}

struct TabBarSettingsSheet: View {
    @Binding var tintColorIndex: Int
    @Binding var blurRadius: Float
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Tab Tint Color") {
                    Picker("Color", selection: $tintColorIndex) {
                        Text("Blue").tag(0)
                        Text("Purple").tag(1)
                        Text("Pink").tag(2)
                        Text("Orange").tag(3)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Blur Radius: \(String(format: "%.1f", blurRadius))") {
                    Slider(value: $blurRadius, in: 0...15)
                }

                Section {
                    Button("Reset to Defaults", role: .destructive) {
                        tintColorIndex = 0
                        blurRadius = 0.0
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
  NativeTabBarRepresentable(
    selectedIndex: .constant(1),
    tintColor: .blue
  )
}

func flatColor(hex: String) -> Color? {
    guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
    return Color(
        red: Double((value >> 16) & 0xFF) / 255,
        green: Double((value >> 8) & 0xFF) / 255,
        blue: Double(value & 0xFF) / 255
    )
}

/// Non-repeating grey blocks, so a refracted patch matches one place only.
struct NoisePattern: View {
    var body: some View {
        Canvas { context, size in
            let configured = UserDefaults.standard.double(forKey: "rigStripe")
            let cell: CGFloat = configured > 0 ? CGFloat(configured) : 4
            var state: UInt64 = 0x9E3779B97F4A7C15
            for row in 0..<Int(ceil(size.height / cell)) {
                for column in 0..<Int(ceil(size.width / cell)) {
                    state = state &* 6364136223846793005 &+ 1442695040888963407
                    let value = 0.3 + 0.5 * Double(state >> 40) / Double(1 << 24)
                    let rect = CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                    context.fill(Path(rect), with: .color(Color(white: value)))
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct StripePattern: View {
    var vertical: Bool
    var grey = false
    var steps = false
    private static let greys: [Color] = [Color(white: 0.35), Color(white: 0.75)]
    private static let greySteps: [Color] = [0x10, 0x30, 0x50, 0x70, 0x90, 0xB0, 0xD0, 0xF0].map { Color(white: Double($0) / 255) }
    private var colors: [Color] { steps ? Self.greySteps : grey ? Self.greys : Self.palette }
    private static let palette: [Color] = [
        Color(red: 0.90, green: 0.20, blue: 0.20),
        Color(red: 0.95, green: 0.80, blue: 0.20),
        Color(red: 0.20, green: 0.75, blue: 0.30),
        Color(red: 0.20, green: 0.80, blue: 0.90),
        Color(red: 0.20, green: 0.35, blue: 0.90),
        Color(red: 0.85, green: 0.25, blue: 0.85)
    ]

    var body: some View {
        Canvas { context, size in
            let configured = UserDefaults.standard.double(forKey: "rigStripe")
            let stripe: CGFloat = configured > 0 ? CGFloat(configured) : 3
            let phase = CGFloat(UserDefaults.standard.double(forKey: "rigPhase"))
            let count = Int(ceil((vertical ? size.width : size.height) / stripe)) + 1
            for index in 0..<count {
                let offset = CGFloat(index) * stripe - phase.truncatingRemainder(dividingBy: stripe * CGFloat(colors.count))
                let rect = vertical
                    ? CGRect(x: offset, y: 0, width: stripe, height: size.height)
                    : CGRect(x: 0, y: offset, width: size.width, height: stripe)
                context.fill(Path(rect), with: .color(colors[index % colors.count]))
            }
        }
        .ignoresSafeArea()
    }
}
