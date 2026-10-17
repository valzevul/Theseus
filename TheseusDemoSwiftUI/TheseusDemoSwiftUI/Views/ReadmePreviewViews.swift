import SwiftUI
import UIKit
@_spi(Scripting) import Theseus

enum TouchScriptStep {
    case hold(TimeInterval)
    case move(by: CGPoint, duration: TimeInterval)
}

final class TouchScriptDriver {
    private var link: CADisplayLink?
    private var start: CFTimeInterval = 0
    private let delay: TimeInterval
    private let origin: CGPoint
    private let steps: [TouchScriptStep]
    private let began: (CGPoint) -> Void
    private let moved: (CGPoint, CGPoint) -> Void
    private let ended: (CGPoint) -> Void
    private var hasBegun = false
    private var lastPoint: CGPoint
    private var lastTime: CFTimeInterval = 0

    init(delay: TimeInterval, origin: CGPoint, steps: [TouchScriptStep], began: @escaping (CGPoint) -> Void, moved: @escaping (CGPoint, CGPoint) -> Void, ended: @escaping (CGPoint) -> Void) {
        self.delay = delay
        self.origin = origin
        self.steps = steps
        self.began = began
        self.moved = moved
        self.ended = ended
        self.lastPoint = origin
    }

    static func startIfRequested(delay: TimeInterval, origin: CGPoint, steps: [TouchScriptStep], began: @escaping (CGPoint) -> Void, moved: @escaping (CGPoint, CGPoint) -> Void, ended: @escaping (CGPoint) -> Void) -> TouchScriptDriver? {
        guard UserDefaults.standard.bool(forKey: "autodrag") else { return nil }
        let driver = TouchScriptDriver(delay: delay, origin: origin, steps: steps, began: began, moved: moved, ended: ended)
        driver.start = CACurrentMediaTime()
        driver.link = CADisplayLink(target: driver, selector: #selector(tick))
        driver.link?.preferredFramesPerSecond = 60
        driver.link?.add(to: .main, forMode: .common)
        return driver
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    private func point(at time: TimeInterval) -> CGPoint? {
        var t = time
        var position = origin
        for step in steps {
            switch step {
            case .hold(let duration):
                if t <= duration { return position }
                t -= duration
            case .move(let delta, let duration):
                if t <= duration {
                    let p = CGFloat(t / duration)
                    let eased = p * p * (3 - 2 * p)
                    return CGPoint(x: position.x + delta.x * eased, y: position.y + delta.y * eased)
                }
                t -= duration
                position = CGPoint(x: position.x + delta.x, y: position.y + delta.y)
            }
        }
        return nil
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        let t = now - start - delay
        guard t >= 0 else { return }
        if !hasBegun {
            hasBegun = true
            lastTime = now
            began(origin)
            return
        }
        guard let current = point(at: t) else {
            ended(lastPoint)
            stop()
            return
        }
        if current != lastPoint {
            let dt = max(now - lastTime, 1.0 / 120.0)
            moved(current, CGPoint(x: (current.x - lastPoint.x) / dt, y: (current.y - lastPoint.y) / dt))
            lastPoint = current
        }
        lastTime = now
    }
}

final class LensPathDriver {
    private var link: CADisplayLink?
    private var start: CFTimeInterval = 0
    private let delay: TimeInterval
    private let legs: [(to: CGPoint, duration: TimeInterval)]
    private let apply: (CGPoint) -> Void

    init(delay: TimeInterval, legs: [(to: CGPoint, duration: TimeInterval)], apply: @escaping (CGPoint) -> Void) {
        self.delay = delay
        self.legs = legs
        self.apply = apply
    }

    static func startIfRequested(delay: TimeInterval = 3.0, legs: [(to: CGPoint, duration: TimeInterval)], apply: @escaping (CGPoint) -> Void) -> LensPathDriver? {
        guard UserDefaults.standard.bool(forKey: "autodrag") else { return nil }
        let driver = LensPathDriver(delay: delay, legs: legs, apply: apply)
        driver.start = CACurrentMediaTime()
        driver.link = CADisplayLink(target: driver, selector: #selector(tick))
        driver.link?.preferredFramesPerSecond = 60
        driver.link?.add(to: .main, forMode: .common)
        return driver
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func tick() {
        var t = CACurrentMediaTime() - start - delay
        guard t >= 0 else { return }
        var from = CGPoint.zero
        for leg in legs {
            if t <= leg.duration {
                let p = CGFloat(t / leg.duration)
                let eased = p * p * (3 - 2 * p)
                apply(CGPoint(x: from.x + (leg.to.x - from.x) * eased, y: from.y + (leg.to.y - from.y) * eased))
                return
            }
            t -= leg.duration
            from = leg.to
        }
        apply(from)
        stop()
    }
}

struct HeroPreview: View {
    var body: some View {
        HeroContainerRepresentable()
            .frame(width: 400, height: 400)
    }
}

struct HeroContainerRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> HeroContainer {
        HeroContainer()
    }

    func updateUIView(_ uiView: HeroContainer, context: Context) {}
}

class HeroContainer: UIView {
    private let backgroundImageView = UIImageView()
    private var lens: TheseusView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        clipsToBounds = true
        backgroundColor = UIColor(white: 0.98, alpha: 1.0)
        backgroundImageView.contentMode = .scaleAspectFit
        addSubview(backgroundImageView)
    }

    private var autoDrag: LensPathDriver?

    private func startAutoDrag() {
        guard let lens = lens, autoDrag == nil else { return }
        let rest = lens.center
        autoDrag = LensPathDriver.startIfRequested(legs: [(CGPoint(x: -85, y: -70), 1.3), (CGPoint(x: 85, y: -75), 1.3), (CGPoint(x: 100, y: 70), 1.3), (CGPoint(x: -95, y: 70), 1.3), (CGPoint(x: 0, y: 0), 1.2)]) { [weak self] offset in
            guard let self = self, let lens = self.lens else { return }
            lens.center = CGPoint(x: rest.x + offset.x, y: rest.y + offset.y)
            lens.invalidateBackground()
            lens.renderNow()
        }
        if autoDrag != nil {
            lens.continuousUpdate = true
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundImageView.frame = bounds

        if lens == nil && bounds.width > 0 {
            setupBackground()
            setupLens()
            startAutoDrag()
        }
    }

    private func setupBackground() {
        if let logo = UIImage(named: "theseus_logo") {
            backgroundImageView.image = logo
        }
    }

    private func setupLens() {
        let lensSize: CGFloat = 140

        var config = TheseusConfiguration()
        config.blur.radius = 3.0
        config.shape.cornerRadius = lensSize / 2
        config.refraction.intensity = 1.42
        config.refraction.edgeWidth = 22.0
        config.refraction.dispersion = 4.0
        // Covers the ring's outward reach at this index (~23 pt).
        config.shape.padding = CGPoint(x: 24, y: 24)
        config.theme.tintColor = .clear
        config.edgeEffects.rimGlow = 1.0
        config.edgeEffects.glareIntensity = 0.8
        config.edgeEffects.glareFocus = 0.75
        config.edgeEffects.nearColor = .clear
        config.edgeEffects.farColor = .clear

        let glassLens = TheseusView(configuration: config)
        glassLens.sourceView = self
        glassLens.frame = CGRect(x: 0, y: 0, width: lensSize, height: lensSize)
        glassLens.center = CGPoint(x: bounds.midX, y: bounds.midY)
        addSubview(glassLens)
        lens = glassLens

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        glassLens.addGestureRecognizer(pan)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let lens = lens else { return }
        let translation = gesture.translation(in: self)
        lens.center = CGPoint(
            x: lens.center.x + translation.x,
            y: lens.center.y + translation.y
        )
        gesture.setTranslation(.zero, in: self)
        lens.invalidateBackground()
    }
}

struct SwitchPreview: View {
    var body: some View {
        SwitchDualContainerRepresentable()
            .frame(width: 400, height: 400)
    }
}

struct SwitchDualContainerRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> SwitchDualContainer {
        SwitchDualContainer()
    }

    func updateUIView(_ uiView: SwitchDualContainer, context: Context) {}
}

class SwitchDualContainer: UIView {
    private let darkBackground = UIImageView()
    private let lightBackground = UIImageView()
    private var darkSwitch: TheseusSwitch?
    private var lightSwitch: TheseusSwitch?

    private let onColor = UIColor(red: 0.259, green: 0.831, blue: 0.318, alpha: 1.0)
    private let offColor = UIColor(white: 0.878, alpha: 1.0)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        clipsToBounds = true
        addSubview(darkBackground)
        addSubview(lightBackground)
    }

    private var scripts: [TouchScriptDriver] = []

    private func startAutoDrag() {
        guard scripts.isEmpty, let dark = darkSwitch, let light = lightSwitch else { return }
        func script(_ control: TheseusSwitch, delay: TimeInterval, dx: CGFloat) -> TouchScriptDriver? {
            let origin = CGPoint(x: control.bounds.midX, y: control.bounds.midY)
            return TouchScriptDriver.startIfRequested(delay: delay, origin: origin, steps: [.hold(0.45), .move(by: CGPoint(x: dx, y: 0), duration: 0.9), .hold(0.35)], began: { [weak control] p in control?.scriptedTouchBegan(at: p) }, moved: { [weak control] p, _ in control?.scriptedTouchMoved(to: p) }, ended: { [weak control] _ in control?.scriptedTouchEnded() })
        }
        scripts = [script(dark, delay: 2.5, dx: -34), script(light, delay: 4.7, dx: -34), script(dark, delay: 6.9, dx: 34), script(light, delay: 9.1, dx: 34)].compactMap { $0 }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let halfHeight = bounds.height / 2
        darkBackground.frame = CGRect(x: 0, y: 0, width: bounds.width, height: halfHeight)
        lightBackground.frame = CGRect(x: 0, y: halfHeight, width: bounds.width, height: halfHeight)

        if darkSwitch == nil && bounds.width > 0 {
            setupBackgrounds()
            setupSwitches()
            startAutoDrag()
        }
    }

    private func setupBackgrounds() {
        darkBackground.image = renderGradient(isDark: true, size: darkBackground.bounds.size)
        lightBackground.image = renderGradient(isDark: false, size: lightBackground.bounds.size)
    }

    private func renderGradient(isDark: Bool, size: CGSize) -> UIImage {
        guard size.width > 0, size.height > 0 else { return UIImage() }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = CGRect(origin: .zero, size: size)
            if isDark {
                gradientLayer.colors = [
                    UIColor(red: 0.15, green: 0.15, blue: 0.20, alpha: 1.0).cgColor,
                    UIColor(red: 0.20, green: 0.18, blue: 0.25, alpha: 1.0).cgColor,
                    UIColor(red: 0.18, green: 0.20, blue: 0.28, alpha: 1.0).cgColor
                ]
            } else {
                gradientLayer.colors = [
                    UIColor(red: 0.95, green: 0.85, blue: 0.82, alpha: 1.0).cgColor,
                    UIColor(red: 0.92, green: 0.80, blue: 0.85, alpha: 1.0).cgColor,
                    UIColor(red: 0.88, green: 0.78, blue: 0.82, alpha: 1.0).cgColor
                ]
            }
            gradientLayer.startPoint = CGPoint(x: 0, y: 0)
            gradientLayer.endPoint = CGPoint(x: 1, y: 1)
            gradientLayer.render(in: ctx.cgContext)
        }
    }

    private func setupSwitches() {
        let halfHeight = bounds.height / 2

        let dark = TheseusSwitch()
        dark.isOn = true
        dark.onTintColor = onColor
        dark.offTintColor = offColor
        dark.frame = CGRect(x: 0, y: 0, width: 63, height: 28)
        dark.center = CGPoint(x: bounds.midX, y: halfHeight / 2)
        addSubview(dark)
        darkSwitch = dark

        let light = TheseusSwitch()
        light.isOn = true
        light.onTintColor = onColor
        light.offTintColor = offColor
        light.frame = CGRect(x: 0, y: 0, width: 63, height: 28)
        light.center = CGPoint(x: bounds.midX, y: halfHeight + halfHeight / 2)
        addSubview(light)
        lightSwitch = light
    }
}

struct SliderPreview: View {
    var body: some View {
        SliderDualContainerRepresentable()
            .frame(width: 400, height: 400)
    }
}

struct SliderDualContainerRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> SliderDualContainer {
        SliderDualContainer()
    }

    func updateUIView(_ uiView: SliderDualContainer, context: Context) {}
}

class SliderDualContainer: UIView {
    private let darkBackground = UIImageView()
    private let lightBackground = UIImageView()
    private var darkSlider: TheseusSlider?
    private var lightSlider: TheseusSlider?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        clipsToBounds = true
        addSubview(darkBackground)
        addSubview(lightBackground)
    }

    private var scripts: [TouchScriptDriver] = []

    private func startAutoDrag() {
        guard scripts.isEmpty, let dark = darkSlider, let light = lightSlider else { return }
        func script(_ control: TheseusSlider, delay: TimeInterval) -> TouchScriptDriver? {
            let origin = CGPoint(x: control.bounds.midX, y: control.bounds.midY)
            return TouchScriptDriver.startIfRequested(delay: delay, origin: origin, steps: [.hold(0.4), .move(by: CGPoint(x: 124, y: 0), duration: 1.0), .hold(0.15), .move(by: CGPoint(x: -245, y: 0), duration: 1.3), .hold(0.15), .move(by: CGPoint(x: 121, y: 0), duration: 0.9), .hold(0.4)], began: { [weak control] p in control?.scriptedTouchBegan(at: p) }, moved: { [weak control] p, _ in control?.scriptedTouchMoved(to: p) }, ended: { [weak control] _ in control?.scriptedTouchEnded() })
        }
        scripts = [script(dark, delay: 2.5), script(light, delay: 7.3)].compactMap { $0 }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let halfHeight = bounds.height / 2
        darkBackground.frame = CGRect(x: 0, y: 0, width: bounds.width, height: halfHeight)
        lightBackground.frame = CGRect(x: 0, y: halfHeight, width: bounds.width, height: halfHeight)

        if darkSlider == nil && bounds.width > 0 {
            setupBackgrounds()
            setupSliders()
            startAutoDrag()
        }
    }

    private func setupBackgrounds() {
        darkBackground.image = renderGradient(isDark: true, size: darkBackground.bounds.size)
        lightBackground.image = renderGradient(isDark: false, size: lightBackground.bounds.size)
    }

    private func renderGradient(isDark: Bool, size: CGSize) -> UIImage {
        guard size.width > 0, size.height > 0 else { return UIImage() }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = CGRect(origin: .zero, size: size)
            if isDark {
                gradientLayer.colors = [
                    UIColor(red: 0.15, green: 0.15, blue: 0.20, alpha: 1.0).cgColor,
                    UIColor(red: 0.20, green: 0.18, blue: 0.25, alpha: 1.0).cgColor,
                    UIColor(red: 0.18, green: 0.20, blue: 0.28, alpha: 1.0).cgColor
                ]
            } else {
                gradientLayer.colors = [
                    UIColor(red: 0.95, green: 0.85, blue: 0.82, alpha: 1.0).cgColor,
                    UIColor(red: 0.92, green: 0.80, blue: 0.85, alpha: 1.0).cgColor,
                    UIColor(red: 0.88, green: 0.78, blue: 0.82, alpha: 1.0).cgColor
                ]
            }
            gradientLayer.startPoint = CGPoint(x: 0, y: 0)
            gradientLayer.endPoint = CGPoint(x: 1, y: 1)
            gradientLayer.render(in: ctx.cgContext)
        }
    }

    private func setupSliders() {
        let halfHeight = bounds.height / 2
        let sliderWidth: CGFloat = 300
        let sliderHeight: CGFloat = 44

        let dark = TheseusSlider()
        dark.minimumValue = 0
        dark.maximumValue = 100
        dark.setValue(50)
        dark.trackColor = .systemBlue
        dark.frame = CGRect(x: 0, y: 0, width: sliderWidth, height: sliderHeight)
        dark.center = CGPoint(x: bounds.midX, y: halfHeight / 2)
        addSubview(dark)
        darkSlider = dark

        let light = TheseusSlider()
        light.minimumValue = 0
        light.maximumValue = 100
        light.setValue(50)
        light.trackColor = .systemBlue
        light.frame = CGRect(x: 0, y: 0, width: sliderWidth, height: sliderHeight)
        light.center = CGPoint(x: bounds.midX, y: halfHeight + halfHeight / 2)
        addSubview(light)
        lightSlider = light
    }
}

final class TabBarScripts {
    private var drivers: [TouchScriptDriver] = []

    func start(_ bar: TheseusTabBar, delay: TimeInterval, startOffset: CGFloat, steps: [TouchScriptStep]) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak bar] in
            guard let self = self, let bar = bar else { return }
            let origin = CGPoint(x: bar.bounds.midX + startOffset, y: bar.bounds.midY)
            let driver = TouchScriptDriver.startIfRequested(delay: delay, origin: origin, steps: steps, began: { [weak bar] p in bar?.scriptedTouchBegan(at: p) }, moved: { [weak bar] p, v in bar?.scriptedTouchMoved(to: p, velocity: v) }, ended: { [weak bar] p in bar?.scriptedTouchEnded(at: p) })
            if let driver = driver { self.drivers.append(driver) }
        }
    }
}

struct TabBarPreview: View {
    @State private var selectedIndex = 0
    @State private var scripts = TabBarScripts()

    private let items = [
        TheseusTabBarItem(icon: UIImage(systemName: "doc.text.image"), selectedIcon: UIImage(systemName: "doc.text.image.fill"), title: "Today"),
        TheseusTabBarItem(icon: UIImage(systemName: "gamecontroller"), selectedIcon: UIImage(systemName: "gamecontroller.fill"), title: "Games"),
        TheseusTabBarItem(icon: UIImage(systemName: "square.stack.3d.up.fill"), title: "Apps"),
        TheseusTabBarItem(icon: UIImage(systemName: "dpad.fill"), title: "Arcade"),
        TheseusTabBarItem(icon: UIImage(systemName: "magnifyingglass"), title: "Search")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                GradientBackground(isDarkMode: true)
                VStack {
                    Spacer()
                    TheseusTabBarRepresentable(
                        items: items,
                        selectedIndex: $selectedIndex,
                        selectedTintColor: .systemBlue,
                        glassBlurRadius: 3.0,
                        onMake: { bar in
                            scripts.start(bar, delay: 2.0, startOffset: -120, steps: [.hold(0.5), .move(by: CGPoint(x: 240, y: 0), duration: 1.6), .hold(0.4), .move(by: CGPoint(x: -120, y: 0), duration: 1.2), .hold(0.6)])
                        }
                    )
                    .frame(height: 63)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .frame(height: 200)

            ZStack {
                GradientBackground(isDarkMode: false)
                VStack {
                    Spacer()
                    TheseusTabBarRepresentable(
                        items: items,
                        selectedIndex: $selectedIndex,
                        selectedTintColor: .systemBlue,
                        glassBlurRadius: 3.0,
                        onMake: { bar in
                            scripts.start(bar, delay: 7.5, startOffset: 0, steps: [.hold(0.5), .move(by: CGPoint(x: -120, y: 0), duration: 1.4), .hold(0.3), .move(by: CGPoint(x: 180, y: 0), duration: 1.4), .hold(0.6)])
                        }
                    )
                    .frame(height: 63)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .frame(height: 200)
        }
        .frame(width: 400, height: 400)
    }
}

struct GlassViewPreview: View {
    var body: some View {
        GlassDemoContainerRepresentable(
            isDarkMode: false,
            blurRadius: 12.0,
            cornerRadius: 40.0,
            refractionFactor: 1.8,
            fresnelFactor: 1.4,
            continuousUpdate: false
        )
        .frame(width: 400, height: 400)
    }
}

struct SettingsPreview: View {
    @State private var blurRadius: Float = 8.0
    @State private var refractionFactor: Float = 1.0
    @State private var cornerRadius: Float = 20.0
    @State private var animating = false

    var body: some View {
        HStack(spacing: 0) {
            SettingsLensContainerRepresentable(
                blurRadius: CGFloat(blurRadius),
                refractionFactor: CGFloat(refractionFactor),
                cornerRadius: CGFloat(cornerRadius)
            )
            .frame(width: 200)

            ZStack {
                Color(UIColor.systemGroupedBackground)

                VStack(spacing: 16) {
                    ParameterRow(label: "blur", value: blurRadius, range: 0...30)
                    ParameterRow(label: "refraction", value: refractionFactor, range: 0...3)
                    ParameterRow(label: "corner", value: cornerRadius, range: 0...50)
                }
                .padding()
            }
            .frame(width: 200)
        }
        .frame(width: 400, height: 400)
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 1.5)) {
                blurRadius = Float.random(in: 5...25)
                refractionFactor = Float.random(in: 0.8...2.5)
                cornerRadius = Float.random(in: 10...45)
            }
        }
    }
}

private struct ParameterRow: View {
    let label: String
    let value: Float
    let range: ClosedRange<Float>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.blue)
                        .frame(width: geo.size.width * CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)))
                }
            }
            .frame(height: 8)

            Text(String(format: "%.1f", value))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
        }
        .frame(height: 60)
    }
}

struct SettingsLensContainerRepresentable: UIViewRepresentable {
    let blurRadius: CGFloat
    let refractionFactor: CGFloat
    let cornerRadius: CGFloat

    func makeUIView(context: Context) -> SettingsLensContainer {
        SettingsLensContainer()
    }

    func updateUIView(_ uiView: SettingsLensContainer, context: Context) {
        uiView.updateLens(
            blurRadius: blurRadius,
            refractionFactor: refractionFactor,
            cornerRadius: cornerRadius
        )
    }
}

class SettingsLensContainer: UIView {
    private let backgroundImageView = UIImageView()
    private var lens: TheseusView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        clipsToBounds = true
        backgroundImageView.contentMode = .scaleAspectFill
        addSubview(backgroundImageView)
    }

    private var autoDrag: LensPathDriver?

    private func startAutoDrag() {
        guard let lens = lens, autoDrag == nil else { return }
        let rest = lens.center
        autoDrag = LensPathDriver.startIfRequested(legs: [(CGPoint(x: -40, y: -120), 1.3), (CGPoint(x: 40, y: -30), 1.2), (CGPoint(x: -40, y: 80), 1.3), (CGPoint(x: 40, y: 130), 1.2), (CGPoint(x: 0, y: 0), 1.4)]) { [weak self] offset in
            guard let self = self, let lens = self.lens else { return }
            lens.center = CGPoint(x: rest.x + offset.x, y: rest.y + offset.y)
            lens.invalidateBackground()
            lens.renderNow()
        }
        if autoDrag != nil {
            lens.continuousUpdate = true
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundImageView.frame = bounds

        if lens == nil && bounds.width > 0 {
            setupBackground()
            setupLens()
            startAutoDrag()
        }
    }

    private func setupBackground() {
        guard bounds.width > 0, bounds.height > 0 else { return }

        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        let image = renderer.image { ctx in
            let colors = [
                UIColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0),
                UIColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 1.0),
                UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0),
                UIColor(red: 0.8, green: 0.4, blue: 1.0, alpha: 1.0)
            ]

            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = bounds
            gradientLayer.colors = colors.map { $0.cgColor }
            gradientLayer.startPoint = CGPoint(x: 0, y: 0)
            gradientLayer.endPoint = CGPoint(x: 1, y: 1)
            gradientLayer.render(in: ctx.cgContext)

            ctx.cgContext.setFillColor(UIColor.white.withAlphaComponent(0.3).cgColor)
            ctx.cgContext.fillEllipse(in: CGRect(x: 20, y: 50, width: 80, height: 80))
            ctx.cgContext.fillEllipse(in: CGRect(x: 100, y: 250, width: 60, height: 60))
            ctx.cgContext.fill(CGRect(x: 30, y: 300, width: 50, height: 50))
        }
        backgroundImageView.image = image
    }

    private func setupLens() {
        let lensSize: CGFloat = 100

        var config = TheseusConfiguration()
        config.blur.radius = 8
        config.shape.cornerRadius = 20
        config.refraction.intensity = 1.0
        config.shape.padding = CGPoint(x: 10, y: 10)
        config.theme.tintColor = .clear
        config.edgeEffects.nearColor = .clear
        config.edgeEffects.farColor = .clear

        let glassLens = TheseusView(configuration: config)
        glassLens.sourceView = self
        glassLens.frame = CGRect(x: 0, y: 0, width: lensSize, height: lensSize)
        glassLens.center = CGPoint(x: bounds.midX, y: bounds.midY)
        addSubview(glassLens)
        lens = glassLens

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        glassLens.addGestureRecognizer(pan)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let lens = lens else { return }
        let translation = gesture.translation(in: self)
        lens.center = CGPoint(
            x: lens.center.x + translation.x,
            y: lens.center.y + translation.y
        )
        gesture.setTranslation(.zero, in: self)
        lens.invalidateBackground()
    }

    func updateLens(blurRadius: CGFloat, refractionFactor: CGFloat, cornerRadius: CGFloat) {
        lens?.blur.radius = blurRadius
        lens?.refraction.intensity = refractionFactor
        lens?.shape.cornerRadius = cornerRadius
    }
}

struct FallbackPreview: View {
    @State private var currentMode = 0
    private let modes = ["Metal", "Approx", "Fallback"]
    private let tiers = ["Tier 3", "Tier 2", "Tier 1", "Tier 0"]
    @State private var currentTier = 0

    var body: some View {
        HStack(spacing: 0) {
            FallbackLensContainerRepresentable(
                useFallback: currentMode == 2,
                tier: currentTier
            )
            .frame(width: 200)

            ZStack {
                Color(UIColor.systemGroupedBackground)

                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("Rendering")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(modes[currentMode])
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(currentMode == 2 ? .orange : .blue)
                    }

                    Divider()

                    VStack(spacing: 8) {
                        Text("Device")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(tiers[currentTier])
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }

                    Divider()

                    VStack(spacing: 8) {
                        Text("iOS")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("iOS \(13 + currentTier)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                }
                .padding()
            }
            .frame(width: 200)
        }
        .frame(width: 400, height: 400)
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentMode = (currentMode + 1) % modes.count
                currentTier = (currentTier + 1) % tiers.count
            }
        }
    }
}

struct FallbackLensContainerRepresentable: UIViewRepresentable {
    let useFallback: Bool
    let tier: Int

    func makeUIView(context: Context) -> FallbackLensContainer {
        FallbackLensContainer()
    }

    func updateUIView(_ uiView: FallbackLensContainer, context: Context) {
        uiView.updateMode(useFallback: useFallback, tier: tier)
    }
}

class FallbackLensContainer: UIView {
    private let backgroundImageView = UIImageView()
    private var lens: TheseusView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        clipsToBounds = true
        backgroundImageView.contentMode = .scaleAspectFill
        addSubview(backgroundImageView)
    }

    private var autoDrag: LensPathDriver?

    private func startAutoDrag() {
        guard let lens = lens, autoDrag == nil else { return }
        let rest = lens.center
        autoDrag = LensPathDriver.startIfRequested(legs: [(CGPoint(x: 40, y: -120), 1.3), (CGPoint(x: -40, y: -30), 1.2), (CGPoint(x: 40, y: 80), 1.3), (CGPoint(x: -40, y: 130), 1.2), (CGPoint(x: 0, y: 0), 1.4)]) { [weak self] offset in
            guard let self = self, let lens = self.lens else { return }
            lens.center = CGPoint(x: rest.x + offset.x, y: rest.y + offset.y)
            lens.invalidateBackground()
            lens.renderNow()
        }
        if autoDrag != nil {
            lens.continuousUpdate = true
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundImageView.frame = bounds

        if lens == nil && bounds.width > 0 {
            setupBackground()
            setupLens()
            startAutoDrag()
        }
    }

    private func setupBackground() {
        guard bounds.width > 0, bounds.height > 0 else { return }

        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        let image = renderer.image { ctx in
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = bounds
            gradientLayer.colors = [
                UIColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1.0).cgColor,
                UIColor(red: 0.8, green: 0.3, blue: 0.6, alpha: 1.0).cgColor,
                UIColor(red: 0.9, green: 0.7, blue: 0.2, alpha: 1.0).cgColor
            ]
            gradientLayer.startPoint = CGPoint(x: 0, y: 0)
            gradientLayer.endPoint = CGPoint(x: 1, y: 1)
            gradientLayer.render(in: ctx.cgContext)

            ctx.cgContext.setFillColor(UIColor.white.withAlphaComponent(0.3).cgColor)
            ctx.cgContext.fillEllipse(in: CGRect(x: 15, y: 40, width: 70, height: 70))
            ctx.cgContext.fillEllipse(in: CGRect(x: 90, y: 220, width: 50, height: 50))
            ctx.cgContext.fill(CGRect(x: 25, y: 280, width: 45, height: 45))
            ctx.cgContext.fillEllipse(in: CGRect(x: 120, y: 100, width: 40, height: 40))
        }
        backgroundImageView.image = image
    }

    private func setupLens() {
        let lensSize: CGFloat = 100

        var config = TheseusConfiguration()
        config.blur.radius = 12
        config.shape.cornerRadius = lensSize / 2
        config.refraction.intensity = 1.6
        // Covers the ring's outward reach at this index (~28 pt).
        config.shape.padding = CGPoint(x: 28, y: 28)
        config.theme.tintColor = .clear
        config.edgeEffects.nearColor = .clear
        config.edgeEffects.farColor = .clear

        let glassLens = TheseusView(configuration: config)
        glassLens.sourceView = self
        glassLens.frame = CGRect(x: 0, y: 0, width: lensSize, height: lensSize)
        glassLens.center = CGPoint(x: bounds.midX, y: bounds.midY)
        addSubview(glassLens)
        lens = glassLens

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        glassLens.addGestureRecognizer(pan)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let lens = lens else { return }
        let translation = gesture.translation(in: self)
        lens.center = CGPoint(
            x: lens.center.x + translation.x,
            y: lens.center.y + translation.y
        )
        gesture.setTranslation(.zero, in: self)
        lens.invalidateBackground()
    }

    func updateMode(useFallback: Bool, tier: Int) {
        let settings = TheseusSettings.shared
        let tiers: [DeviceTier] = [.tier3, .tier2, .tier1, .tier0]
        settings.tierOverride = tiers[min(tier, 3)]

        if useFallback {
            settings.refractionPolicyOverride = .off
        } else {
            settings.refractionPolicyOverride = .trueRefraction
        }

        lens?.invalidateBackground()
    }
}

// MARK: - iOS 27 Tint Preview (regular / tinted / clear)

struct TintPreview: View {
    var body: some View {
        TintTrioContainerRepresentable()
            .frame(width: 400, height: 400)
    }
}

struct TintTrioContainerRepresentable: UIViewRepresentable {
    var includeNative = false

    func makeUIView(context: Context) -> TintTrioContainer {
        let container = TintTrioContainer()
        container.includeNative = includeNative
        return container
    }

    func updateUIView(_ uiView: TintTrioContainer, context: Context) {}
}

struct NativeComparePreview: View {
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        TintTrioContainerRepresentable(includeNative: true)
            .frame(width: 400, height: 400)
            .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

class TintTrioContainer: UIView {
    var includeNative = false
    private let backgroundImageView = UIImageView()
    private var didSetup = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        backgroundImageView.contentMode = .scaleAspectFill
        addSubview(backgroundImageView)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        clipsToBounds = true
        backgroundImageView.contentMode = .scaleAspectFill
        addSubview(backgroundImageView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundImageView.frame = bounds

        if !didSetup && bounds.width > 0 {
            didSetup = true
            renderGradientBackground()
            setupPills()
        }
    }

    private func renderGradientBackground() {
        let backdrop = UserDefaults.standard.string(forKey: "rigBackdrop") ?? "light"
        if backdrop.hasPrefix("hex:"), let flat = Self.color(hex: String(backdrop.dropFirst(4))) {
            UIGraphicsBeginImageContextWithOptions(bounds.size, true, 0)
            flat.setFill()
            UIRectFill(CGRect(origin: .zero, size: bounds.size))
            backgroundImageView.image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return
        }
        if backdrop == "ramp" {
            let scale = window?.screen.scale ?? 3
            let width = Int(bounds.width * scale)
            let height = Int(bounds.height * scale)
            var pixels = [UInt8](repeating: 255, count: width * height * 4)
            for column in 0..<width {
                let x = CGFloat(column) / scale
                let grey = UInt8(min(max((x - 11) / 170, 0), 1) * 255 + 0.5)
                for row in 0..<height {
                    let index = (row * width + column) * 4
                    pixels[index] = grey
                    pixels[index + 1] = grey
                    pixels[index + 2] = grey
                }
            }
            let space = CGColorSpace(name: CGColorSpace.sRGB)!
            if let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue), let image = context.makeImage() {
                backgroundImageView.image = UIImage(cgImage: image, scale: scale, orientation: .up)
            }
            return
        }
        if backdrop == "xcoord" || backdrop == "ycoord" {
            let scale = window?.screen.scale ?? 3
            let width = Int(bounds.width * scale)
            let height = Int(bounds.height * scale)
            var pixels = [UInt8](repeating: 255, count: width * height * 4)
            let alongX = backdrop == "xcoord"
            for row in 0..<height {
                for column in 0..<width {
                    let v = alongX ? column : row
                    let index = (row * width + column) * 4
                    pixels[index] = UInt8(v & 255)
                    pixels[index + 1] = UInt8(min((v >> 8) * 50, 255))
                    pixels[index + 2] = 0
                }
            }
            let space = CGColorSpace(name: CGColorSpace.sRGB)!
            if let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue), let image = context.makeImage() {
                backgroundImageView.image = UIImage(cgImage: image, scale: scale, orientation: .up)
            }
            return
        }
        if backdrop.hasPrefix("hstripes:") || backdrop.hasPrefix("vstripes:"), let period = Double(backdrop.split(separator: ":").last ?? ""), period > 0 {
            let horizontal = backdrop.hasPrefix("hstripes:")
            UIGraphicsBeginImageContextWithOptions(bounds.size, true, 0)
            UIColor(white: 0.95, alpha: 1).setFill()
            UIRectFill(CGRect(origin: .zero, size: bounds.size))
            UIColor(white: 0.25, alpha: 1).setFill()
            var offset: CGFloat = 0
            let extent = horizontal ? bounds.height : bounds.width
            while offset < extent {
                UIRectFill(horizontal
                    ? CGRect(x: 0, y: offset, width: bounds.width, height: CGFloat(period) / 2)
                    : CGRect(x: offset, y: 0, width: CGFloat(period) / 2, height: bounds.height))
                offset += CGFloat(period)
            }
            backgroundImageView.image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return
        }
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = bounds
        let darkBackdrop = backdrop == "dark"
        gradientLayer.colors = darkBackdrop
            ? [
                UIColor(red: 0.15, green: 0.15, blue: 0.20, alpha: 1.0).cgColor,
                UIColor(red: 0.20, green: 0.18, blue: 0.25, alpha: 1.0).cgColor,
                UIColor(red: 0.18, green: 0.20, blue: 0.28, alpha: 1.0).cgColor
            ]
            : [
                UIColor(red: 0.92, green: 0.82, blue: 0.98, alpha: 1.0).cgColor,
                UIColor(red: 0.82, green: 0.95, blue: 0.98, alpha: 1.0).cgColor,
                UIColor(red: 0.98, green: 0.95, blue: 0.82, alpha: 1.0).cgColor,
                UIColor(red: 0.98, green: 0.82, blue: 0.88, alpha: 1.0).cgColor
            ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)

        UIGraphicsBeginImageContextWithOptions(bounds.size, true, 0)
        if let context = UIGraphicsGetCurrentContext() {
            gradientLayer.render(in: context)
        }
        backgroundImageView.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }

    static var rigTint: UIColor {
        if let hex = UserDefaults.standard.string(forKey: "rigTintHex"), let color = color(hex: hex) {
            return color
        }
        switch UserDefaults.standard.string(forKey: "rigTint") {
        case "red": return .systemRed
        case "green": return .systemGreen
        case "orange": return .systemOrange
        case "purple": return .systemPurple
        default: return .systemBlue
        }
    }

    static var rigTintAlpha: CGFloat {
        let value = UserDefaults.standard.double(forKey: "rigTintAlpha")
        return value > 0 ? min(value, 1) : 0.8
    }

    private static func color(hex: String) -> UIColor? {
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        return UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    func setupPills() {
        let defaults = UserDefaults.standard
        let pillSize = includeNative
            ? CGSize(
                width: defaults.double(forKey: "rigPillWidth") > 0 ? defaults.double(forKey: "rigPillWidth") : 170,
                height: defaults.double(forKey: "rigPillHeight") > 0 ? defaults.double(forKey: "rigPillHeight") : 70
            )
            : CGSize(width: 260, height: 84)
        let kinds = (defaults.string(forKey: "rigKinds") ?? "012").compactMap { Int(String($0)) }.filter { (0...2).contains($0) }
        let spacing: CGFloat = 24
        let totalHeight = pillSize.height * CGFloat(kinds.count) + spacing * CGFloat(max(kinds.count - 1, 0))
        var y = (bounds.height - totalHeight) / 2
        let columnGap: CGFloat = 40
        let theseusX = includeNative
            ? bounds.width / 2 + columnGap / 2
            : (bounds.width - pillSize.width) / 2
        let nativeX = bounds.width / 2 - columnGap / 2 - pillSize.width

        var regular = TheseusConfiguration.regular
        regular.captureMethod = .layerRendering
        var tinted = TheseusConfiguration.regular.tint(Self.rigTint, intensity: Self.rigTintAlpha)
        tinted.captureMethod = .layerRendering
        var clear = TheseusConfiguration.clear
        clear.captureMethod = .layerRendering

        let configurations = [regular, tinted, clear]
        for kind in kinds {
            let frame = CGRect(x: theseusX, y: y, width: pillSize.width, height: pillSize.height)
            addPill(configuration: configurations[kind], frame: frame)
            if includeNative {
                addNativePill(
                    kind: kind,
                    frame: CGRect(x: nativeX, y: y, width: pillSize.width, height: pillSize.height)
                )
            }
            y += pillSize.height + spacing
        }
    }

    private func addNativePill(kind: Int, frame: CGRect) {
        guard #available(iOS 26.0, *) else { return }
        let effect = kind == 2 ? UIGlassEffect(style: .clear) : UIGlassEffect(style: .regular)
        if kind == 1 {
            effect.tintColor = Self.rigTint.withAlphaComponent(Self.rigTintAlpha)
        }
        let view = UIVisualEffectView(effect: effect)
        view.frame = frame
        view.cornerConfiguration = .capsule()
        addSubview(view)
    }

    func addPill(configuration: TheseusConfiguration, frame: CGRect) {
        var config = configuration
        config.shape.cornerRadius = frame.height / 2
        // Covers the ring's outward reach at the default index.
        let padding = UserDefaults.standard.double(forKey: "rigPadding") > 0 ? UserDefaults.standard.double(forKey: "rigPadding") : 24
        config.shape.padding = CGPoint(x: padding, y: padding)
        config.edgeEffects.nearColor = .clear
        config.edgeEffects.farColor = .clear

        let pill = TheseusView(configuration: config)
        pill.frame = frame
        pill.sourceView = backgroundImageView
        addSubview(pill)
    }
}

// MARK: - Parameter Diagnostic (temporary; not a README scene)

struct DiagPreview: View {
    var body: some View {
        DiagContainerRepresentable()
            .frame(width: 400, height: 500)
    }
}

struct DiagContainerRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> DiagContainer { DiagContainer() }
    func updateUIView(_ uiView: DiagContainer, context: Context) {}
}

class DiagContainer: TintTrioContainer {

    override func setupPills() {
        let pillSize = CGSize(width: 280, height: 70)
        let spacing: CGFloat = 18

        var opacity08 = TheseusConfiguration.regular
        opacity08.opacity = 0.8

        var opacity099 = TheseusConfiguration.regular
        opacity099.opacity = 0.99

        var opacityTinted = TheseusConfiguration.regular.tint(.systemBlue, intensity: 1.0)
        opacityTinted.opacity = 0.8

        // addPill forces .layerRendering; setupPills restores .surfaceBased for this variant.
        var opacitySurface = TheseusConfiguration.regular
        opacitySurface.opacity = 0.8
        opacitySurface.captureMethod = .surfaceBased

        var control = TheseusConfiguration.regular
        control.captureMethod = .layerRendering
        opacity099.captureMethod = .layerRendering
        opacity08.captureMethod = .layerRendering
        opacityTinted.captureMethod = .layerRendering

        let variants: [TheseusConfiguration] = [
            control,
            opacity099,
            opacity08,
            opacityTinted,
            opacitySurface
        ]

        let totalHeight = pillSize.height * CGFloat(variants.count) + spacing * CGFloat(variants.count - 1)
        var y = (bounds.height - totalHeight) / 2

        for variant in variants {
            addPill(configuration: variant, frame: CGRect(
                x: (bounds.width - pillSize.width) / 2, y: y,
                width: pillSize.width, height: pillSize.height
            ))
            y += pillSize.height + spacing
        }
    }
}

// MARK: - iOS 27 Shape Merging Preview

struct Glass27Preview: View {
    var body: some View {
        Glass27PreviewContainerRepresentable()
            .frame(width: 400, height: 400)
    }
}

struct Glass27PreviewContainerRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> Glass27Container {
        let container = Glass27Container()
        container.updateSettings(
            tintColor: .systemBlue,
            tintIntensity: 0.7,
            highlightPreservation: 0.5,
            usesClearPreset: false,
            mergeSmoothing: 18.0
        )
        return container
    }

    func updateUIView(_ uiView: Glass27Container, context: Context) {}
}

// MARK: - Preview Host (scripted capture entry point)

/// One README capture scene, full-screen; chosen at launch with `-preview <scene>`.
struct ReadmePreviewHost: View {
    let scene: String

    var body: some View {
        ZStack {
            Color(white: 0.98).ignoresSafeArea()
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch scene.lowercased() {
        case "hero": HeroPreview()
        case "switch": SwitchPreview()
        case "slider": SliderPreview()
        case "tabbar": TabBarPreview()
        case "glassview": GlassViewPreview()
        case "settings": SettingsPreview()
        case "fallback": FallbackPreview()
        case "tint27": TintPreview()
        case "native27": NativeComparePreview()
        case "diag": DiagPreview()
        case "glass27", "merge": Glass27Preview()
        default:
            Text("Unknown preview scene: \(scene)")
                .foregroundColor(.secondary)
        }
    }
}

#Preview("Hero") {
  HeroPreview()
}

#Preview("Switch") {
    SwitchPreview()
}

#Preview("Slider") {
    SliderPreview()
}

#Preview("TabBar") {
    TabBarPreview()
}

#Preview("GlassView") {
    GlassViewPreview()
}

#Preview("Settings") {
    SettingsPreview()
}

#Preview("Fallback") {
    FallbackPreview()
}

#Preview("Tint27") {
    TintPreview()
}

#Preview("Glass27") {
    Glass27Preview()
}
