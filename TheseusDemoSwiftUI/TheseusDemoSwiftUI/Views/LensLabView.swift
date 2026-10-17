import SwiftUI
import Theseus

/// Every knob is a `UserDefaults` key under `lens.`; `defaults write` changes it live.
struct LensLabView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @StateObject private var settings = LensLabSettings()
    @State private var selectedIndex = 0
    @State private var nativeSelectedIndex = 0
    @State private var showingKnobs = false

    private let tabItems = [
        TheseusTabBarItem(icon: UIImage(systemName: "doc.text.image"), title: "Today"),
        TheseusTabBarItem(icon: UIImage(systemName: "gamecontroller"), title: "Games"),
        TheseusTabBarItem(icon: UIImage(systemName: "square.stack.3d.up.fill"), title: "Apps"),
        TheseusTabBarItem(icon: UIImage(systemName: "dpad.fill"), title: "Arcade"),
        TheseusTabBarItem(icon: UIImage(systemName: "magnifyingglass"), title: "Search")
    ]

    var body: some View {
        ZStack {
            LabBackdrop()
            VStack(spacing: 28) {
                NativeTabBarRepresentable(selectedIndex: $nativeSelectedIndex, tintColor: .systemBlue)
                    .frame(height: 49)
                TheseusTabBarRepresentable(
                    items: tabItems,
                    selectedIndex: $selectedIndex,
                    selectedTintColor: .systemBlue,
                    lensMaterial: settings.material
                )
                .frame(height: 63)
                LensSweepGrid(settings: settings, isDark: isDarkMode)
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    Color(UIColor.systemBlue).frame(width: 40, height: 24)
                    Color(UIColor.systemBlue.withAlphaComponent(0.8)).frame(width: 40, height: 24).background(Color.black)
                    Color(UIColor.systemBlue.withAlphaComponent(0.8)).frame(width: 40, height: 24).background(Color.white)
                    Color(UIColor.systemGray).frame(width: 40, height: 24)
                    Color(UIColor.systemBackground).frame(width: 40, height: 24)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
        }
        .navigationTitle("Lens Lab")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { isDarkMode.toggle() }) {
                    Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                }
                Button(action: { showingKnobs = true }) {
                    Image(systemName: "slider.horizontal.3")
                }
            }
        }
        .sheet(isPresented: $showingKnobs) {
            LensKnobsSheet(settings: settings)
        }
    }
}

struct LabBackdrop: View {
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        let pattern = UserDefaults.standard.string(forKey: "rigPattern") ?? "hstripes"
        if pattern.hasPrefix("flat:"), let flat = flatColor(hex: String(pattern.dropFirst(5))) {
            flat.ignoresSafeArea()
        } else if pattern == "gradient" {
            GradientBackground(isDarkMode: isDarkMode)
        } else {
            StripePattern(vertical: pattern == "vstripes")
        }
    }
}

// MARK: - Settings

final class LensLabSettings: NSObject, ObservableObject {
    @Published private(set) var material: TheseusLensMaterial = .default

    struct Knob: Identifiable {
        let id: String
        let title: String
        let range: ClosedRange<Double>
        let get: (TheseusLensMaterial) -> CGFloat
        let set: (inout TheseusLensMaterial, CGFloat) -> Void
    }

    static let knobs: [Knob] = [
        Knob(id: "bandWidth", title: "Band width (pt)", range: 4...60, get: { $0.bandWidth }, set: { $0.bandWidth = $1 }),
        Knob(id: "depth", title: "Depth (pt)", range: 0...20, get: { $0.depth }, set: { $0.depth = $1 }),
        Knob(id: "riseStart", title: "Rise start", range: 0...0.5, get: { $0.profile.riseStart }, set: { $0.profile.riseStart = $1 }),
        Knob(id: "riseEnd", title: "Rise end", range: 0.02...0.8, get: { $0.profile.riseEnd }, set: { $0.profile.riseEnd = $1 }),
        Knob(id: "fallStart", title: "Plateau end", range: 0.05...1, get: { $0.profile.fallStart }, set: { $0.profile.fallStart = $1 }),
        Knob(id: "fallLength", title: "Tail length", range: 0.01...1, get: { $0.profile.fallLength }, set: { $0.profile.fallLength = $1 }),
        Knob(id: "frost", title: "Frost", range: 0...1, get: { $0.profile.frost }, set: { $0.profile.frost = $1 }),
        Knob(id: "contour", title: "Contour darkening (dark)", range: 0...1, get: { $0.profile.contourDarkening }, set: { $0.profile.contourDarkening = $1 }),
        Knob(id: "contourLight", title: "Contour darkening (light)", range: 0...1, get: { $0.profile.contourDarkeningLight }, set: { $0.profile.contourDarkeningLight = $1 }),
        Knob(id: "highlight", title: "Highlight (dark)", range: 0...0.6, get: { $0.profile.highlight }, set: { $0.profile.highlight = $1 }),
        Knob(id: "highlightLight", title: "Highlight (light)", range: 0...0.6, get: { $0.profile.highlightLight }, set: { $0.profile.highlightLight = $1 }),
        Knob(id: "highlightSide", title: "Highlight on sides", range: 0...1, get: { $0.profile.highlightSide }, set: { $0.profile.highlightSide = $1 }),
        Knob(id: "highlightBottom", title: "Highlight at bottom", range: 0...1, get: { $0.profile.highlightBottom }, set: { $0.profile.highlightBottom = $1 }),
        Knob(id: "highlightWidth", title: "Highlight width (px)", range: 0...8, get: { $0.profile.highlightWidth }, set: { $0.profile.highlightWidth = $1 }),
        Knob(id: "highlightFade", title: "Highlight fade, dark (px)", range: 0.5...20, get: { $0.profile.highlightFade }, set: { $0.profile.highlightFade = $1 }),
        Knob(id: "highlightFadeLight", title: "Highlight fade, light (px)", range: 0.5...20, get: { $0.profile.highlightFadeLight }, set: { $0.profile.highlightFadeLight = $1 }),
        Knob(id: "shade", title: "Rim shading (light)", range: 0...0.3, get: { $0.profile.shade }, set: { $0.profile.shade = $1 }),
        Knob(id: "shadeDark", title: "Rim shading (dark)", range: 0...0.3, get: { $0.profile.shadeDark }, set: { $0.profile.shadeDark = $1 }),
        Knob(id: "shadeReach", title: "Shading reach (pt)", range: 2...60, get: { $0.profile.shadeReach }, set: { $0.profile.shadeReach = $1 }),
        Knob(id: "dispersion", title: "Dispersion", range: 0...30, get: { $0.dispersion }, set: { $0.dispersion = $1 }),
        Knob(id: "blur", title: "Lens blur (pt)", range: 0...20, get: { $0.blurRadius }, set: { $0.blurRadius = $1 }),
        Knob(id: "magnification", title: "Interior magnification", range: 0.5...1.5, get: { $0.magnification }, set: { $0.magnification = $1 }),
        Knob(id: "interiorDetail", title: "Interior detail", range: 0...1, get: { $0.interiorDetail }, set: { $0.interiorDetail = $1 }),
        Knob(id: "interiorAverage", title: "Interior average (pt)", range: 0...80, get: { $0.interiorAverage }, set: { $0.interiorAverage = $1 }),
        Knob(id: "rimDispersion", title: "Rim dispersion (pt)", range: 0...10, get: { $0.rimDispersion }, set: { $0.rimDispersion = $1 }),
        Knob(id: "rimDispersionDepth", title: "Rim dispersion depth (pt)", range: 0...30, get: { $0.rimDispersionDepth }, set: { $0.rimDispersionDepth = $1 }),
        Knob(id: "shadowOpacity", title: "Shadow opacity", range: 0...0.3, get: { $0.shadowOpacity }, set: { $0.shadowOpacity = $1 }),
        Knob(id: "shadowOffset", title: "Shadow offset (pt)", range: 0...20, get: { $0.shadowOffset }, set: { $0.shadowOffset = $1 }),
        Knob(id: "shadowRadius", title: "Shadow radius (pt)", range: 0...20, get: { $0.shadowRadius }, set: { $0.shadowRadius = $1 }),
        Knob(id: "lift", title: "Lift (light)", range: 0...0.3, get: { $0.lift }, set: { $0.lift = $1 }),
        Knob(id: "liftDark", title: "Lift (dark)", range: 0...0.3, get: { $0.liftDark }, set: { $0.liftDark = $1 }),
        Knob(id: "gain", title: "Pane gain (light)", range: 0.8...1.2, get: { $0.gain }, set: { $0.gain = $1 }),
        Knob(id: "gainDark", title: "Pane gain (dark)", range: 0.8...1.2, get: { $0.gainDark }, set: { $0.gainDark = $1 }),
        Knob(id: "itemScale", title: "Item scale", range: 1...1.6, get: { $0.itemScale }, set: { $0.itemScale = $1 }),
        Knob(id: "iconScale", title: "Icon scale", range: 1...1.8, get: { $0.iconScale }, set: { $0.iconScale = $1 }),
        Knob(id: "motionGain", title: "Motion gain", range: 0...6, get: { $0.motionGain }, set: { $0.motionGain = $1 }),
        Knob(id: "motionSpeed", title: "Motion speed (pt/s)", range: 100...2000, get: { $0.motionSpeed }, set: { $0.motionSpeed = $1 }),
        Knob(id: "motionDecay", title: "Motion decay (s)", range: 0.05...2, get: { $0.motionDecay }, set: { $0.motionDecay = $1 })
    ]

    static func key(_ id: String) -> String { "lens." + id }

    private let defaults = UserDefaults.standard
    private var context = 0

    override init() {
        super.init()
        for knob in Self.knobs {
            defaults.addObserver(self, forKeyPath: Self.key(knob.id), options: [.new], context: &context)
        }
        reload()
    }

    deinit {
        for knob in Self.knobs {
            defaults.removeObserver(self, forKeyPath: Self.key(knob.id), context: &context)
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard context == &self.context else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        DispatchQueue.main.async { [weak self] in self?.reload() }
    }

    func value(_ knob: Knob) -> Double { Double(knob.get(material)) }

    func set(_ knob: Knob, to value: Double) {
        defaults.set(value, forKey: Self.key(knob.id))
    }

    func reset() {
        for knob in Self.knobs { defaults.removeObject(forKey: Self.key(knob.id)) }
    }

    func material(overriding id: String, with value: CGFloat) -> TheseusLensMaterial {
        var result = material
        if let knob = Self.knobs.first(where: { $0.id == id }) { knob.set(&result, value) }
        return result
    }

    private func reload() {
        var result = TheseusLensMaterial.default
        for knob in Self.knobs where defaults.object(forKey: Self.key(knob.id)) != nil {
            knob.set(&result, CGFloat(defaults.double(forKey: Self.key(knob.id))))
        }
        if result != material { material = result }
    }
}

// MARK: - Knobs sheet

struct LensKnobsSheet: View {
    @ObservedObject var settings: LensLabSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                ForEach(LensLabSettings.knobs) { knob in
                    Section(knob.title + ": " + String(format: "%.2f", settings.value(knob))) {
                        Slider(
                            value: Binding(get: { settings.value(knob) }, set: { settings.set(knob, to: $0) }),
                            in: knob.range
                        )
                    }
                }
                Section {
                    Button("Reset to defaults", role: .destructive) { settings.reset() }
                }
            }
            .navigationTitle("Lens knobs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}

// MARK: - Sweep grid

struct LensSweepGrid: View {
    @ObservedObject var settings: LensLabSettings
    var isDark: Bool

    private var knob: String { UserDefaults.standard.string(forKey: "labKnob") ?? "depth" }
    private var values: [CGFloat] {
        let raw = UserDefaults.standard.string(forKey: "labValues") ?? "2,3,4,5,6,8"
        return raw.split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespaces)).map { CGFloat($0) } ?? -1 }
    }

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                VStack(spacing: 4) {
                    LensTileRepresentable(material: settings.material(overriding: knob, with: value), isDark: isDark, showsLens: value >= 0)
                        .frame(width: 150, height: 110)
                    Text(value >= 0 ? knob + " " + String(format: "%g", Double(value)) : "no lens")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
        }
    }
}

struct LensTileRepresentable: UIViewRepresentable {
    var material: TheseusLensMaterial
    var isDark: Bool
    var showsLens: Bool = true

    func makeUIView(context: Context) -> LensTile {
        let tile = LensTile(material: material, isDark: isDark)
        tile.showsLens = showsLens
        return tile
    }

    func updateUIView(_ uiView: LensTile, context: Context) {
        uiView.update(material: material, isDark: isDark)
        uiView.showsLens = showsLens
    }
}

/// Two bar icons under a stationary drag lens, for reading the rim off a still.
final class LensTile: UIView {
    static let lensSize = CGSize(width: 101, height: 74)
    static let barHeight: CGFloat = 63

    private let content = UIView()
    private let backdrop = UIImageView()
    private var backdropKey = ""
    private let chrome: TheseusView
    private let lens: TheseusView
    private let leftIcon = UIImageView(image: UIImage(systemName: "gamecontroller"))
    private let rightIcon = UIImageView(image: UIImage(systemName: "dpad.fill"))
    private var material: TheseusLensMaterial
    private var isDark: Bool

    var showsLens = true {
        didSet { lens.isHidden = !showsLens }
    }

    init(material: TheseusLensMaterial, isDark: Bool) {
        self.material = material
        self.isDark = isDark
        chrome = TheseusView(configuration: LensTile.chromeConfiguration(isDark: isDark))
        lens = TheseusView(configuration: LensTile.lensConfiguration(material: material, isDark: isDark))
        super.init(frame: .zero)
        clipsToBounds = true
        addSubview(content)
        content.addSubview(backdrop)
        content.addSubview(chrome)
        chrome.isHidden = UserDefaults.standard.object(forKey: "labChrome").map { _ in !UserDefaults.standard.bool(forKey: "labChrome") } ?? false
        chrome.layer.cornerRadius = LensTile.barHeight / 2
        for icon in [leftIcon, rightIcon] {
            icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
            icon.contentMode = .scaleAspectFit
            icon.tintColor = isDark ? .white : .black
            content.addSubview(icon)
        }
        lens.sourceView = content
        addSubview(lens)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(material: TheseusLensMaterial, isDark: Bool) {
        if self.material != material {
            self.material = material
            lens.configuration = LensTile.lensConfiguration(material: material, isDark: isDark)
        }
        if self.isDark != isDark {
            self.isDark = isDark
            chrome.configuration = LensTile.chromeConfiguration(isDark: isDark)
            leftIcon.tintColor = isDark ? .white : .black
            rightIcon.tintColor = isDark ? .white : .black
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        content.frame = bounds
        backdrop.frame = bounds
        let origin = convert(CGPoint.zero, to: nil)
        let key = "\(bounds.size)-\(Int(origin.x))-\(Int(origin.y))"
        if key != backdropKey, bounds.width > 0 {
            backdropKey = key
            backdrop.image = LensTile.backdropImage(size: bounds.size, originInWindow: origin, isDark: isDark)
        }
        let mid = bounds.midY
        chrome.frame = CGRect(x: -40, y: mid - LensTile.barHeight / 2, width: bounds.width + 80, height: LensTile.barHeight)
        leftIcon.frame = CGRect(x: bounds.midX - 60 - 14, y: mid - 22, width: 28, height: 28)
        rightIcon.frame = CGRect(x: bounds.midX + 60 - 14, y: mid - 22, width: 28, height: 28)
        lens.frame = CGRect(
            x: bounds.midX - LensTile.lensSize.width / 2,
            y: mid - LensTile.lensSize.height / 2,
            width: LensTile.lensSize.width,
            height: LensTile.lensSize.height
        )
        lens.shape.cornerRadius = -LensTile.lensSize.height / 2
    }

    static let palette: [UIColor] = [
        UIColor(red: 0.90, green: 0.20, blue: 0.20, alpha: 1),
        UIColor(red: 0.95, green: 0.80, blue: 0.20, alpha: 1),
        UIColor(red: 0.20, green: 0.75, blue: 0.30, alpha: 1),
        UIColor(red: 0.20, green: 0.80, blue: 0.90, alpha: 1),
        UIColor(red: 0.20, green: 0.35, blue: 0.90, alpha: 1),
        UIColor(red: 0.85, green: 0.25, blue: 0.85, alpha: 1)
    ]

    /// The screen backdrop redrawn inside the tile; `originInWindow` keeps the band phase.
    static func backdropImage(size: CGSize, originInWindow: CGPoint, isDark: Bool) -> UIImage {
        let pattern = UserDefaults.standard.string(forKey: "rigPattern") ?? "hstripes"
        let configured = UserDefaults.standard.double(forKey: "rigStripe")
        let stripe = configured > 0 ? CGFloat(configured) : 3
        return UIGraphicsImageRenderer(size: size).image { context in
            if pattern.hasPrefix("flat:"), let flat = flatColor(hex: String(pattern.dropFirst(5))) {
                UIColor(flat).setFill()
                context.fill(CGRect(origin: .zero, size: size))
                return
            }
            if pattern == "gradient" {
                let colors = isDark
                    ? [UIColor(red: 0.15, green: 0.15, blue: 0.20, alpha: 1), UIColor(red: 0.18, green: 0.20, blue: 0.28, alpha: 1)]
                    : [UIColor(red: 0.95, green: 0.85, blue: 0.82, alpha: 1), UIColor(red: 0.88, green: 0.78, blue: 0.82, alpha: 1)]
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: [0, 1])!
                context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
                return
            }
            let vertical = pattern == "vstripes" || pattern == "gvstripes"
            let greys = [UIColor(white: 0.35, alpha: 1), UIColor(white: 0.75, alpha: 1)]
            let colours = pattern.hasPrefix("g") ? greys : palette
            let phase = CGFloat(UserDefaults.standard.double(forKey: "rigPhase")).truncatingRemainder(dividingBy: stripe * CGFloat(colours.count))
            let offset = (vertical ? originInWindow.x : originInWindow.y) + phase
            let extent = vertical ? size.width : size.height
            let first = floor(offset / stripe)
            var index = Int(first)
            var position = first * stripe - offset
            while position < extent {
                colours[((index % colours.count) + colours.count) % colours.count].setFill()
                let rect = vertical
                    ? CGRect(x: position, y: 0, width: stripe, height: size.height)
                    : CGRect(x: 0, y: position, width: size.width, height: stripe)
                context.fill(rect)
                position += stripe
                index += 1
            }
        }
    }

    static func chromeConfiguration(isDark: Bool) -> TheseusConfiguration {
        var config = TheseusConfiguration.regular
        config.captureMethod = .layerRendering
        config.blur.radius = 18
        config.refraction.edgeWidth = 0
        config.edgeEffects.rimGlow = 0
        config.edgeEffects.glareIntensity = 0
        config.theme.neutralBodyScale = 1.0
        config.theme.backdropGain = isDark ? 1.02 : 1.0
        config.theme.luminanceLift = isDark ? 0.047 : 0.024
        config.shape.cornerRadius = LensTile.barHeight / 2
        return config
    }

    static func lensConfiguration(material: TheseusLensMaterial, isDark: Bool) -> TheseusConfiguration {
        var config = TheseusConfiguration.lens
        config.captureMethod = .layerRendering
        config.shape.padding = CGPoint(x: 44, y: 44)
        config.refraction.magnification = 1.0
        config.refraction.magnificationCenterY = 0
        config.refraction.intensity = 1.1
        config.refraction.edgeWidth = material.bandWidth
        config.refraction.thickness = material.depth
        config.refraction.dispersion = material.dispersion
        config.refraction.lensProfile = material.profile
        config.theme.luminanceLift = isDark ? material.liftDark : material.lift
        config.theme.backdropGain = isDark ? material.gainDark : material.gain
        config.theme.tintColor = .clear
        config.blur.radius = material.blurRadius
        config.edgeEffects.rimGlow = 0
        config.edgeEffects.glareIntensity = 0
        config.shape.cornerRadius = -lensSize.height / 2
        return config
    }
}
