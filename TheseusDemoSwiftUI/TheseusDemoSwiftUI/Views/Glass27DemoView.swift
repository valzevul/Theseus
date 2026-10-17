import SwiftUI
import UIKit
import Theseus

// MARK: - iOS 27 Glass Demo

struct Glass27DemoView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var showingControls = false
    @State private var showingDimmingSheet = false

    @State private var tintColor: Color = Color(red: 0.0, green: 0.45, blue: 1.0)
    @State private var tintIntensity: Float = 0.8
    @State private var highlightPreservation: Float = 0.5
    @State private var usesClearPreset = false

    @State private var mergeSmoothing: Float = 24.0

    @State private var tintSpectrum: Double = Double(TheseusSettings.shared.tintSpectrum)

    var body: some View {
        ZStack {
            GlassDemoGradient(isDarkMode: isDarkMode)
                .ignoresSafeArea()

            Glass27ContainerRepresentable(
                isDarkMode: isDarkMode,
                tintColor: UIColor(tintColor),
                tintIntensity: CGFloat(tintIntensity),
                highlightPreservation: CGFloat(highlightPreservation),
                usesClearPreset: usesClearPreset,
                mergeSmoothing: CGFloat(mergeSmoothing)
            )
            .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 6) {
                    HStack(spacing: 12) {
                        Text("Clear")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: spectrumBinding, in: 0...1)
                            .accessibilityIdentifier("spectrumSlider")
                        Text("Tinted")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("iOS 27 appearance spectrum - drag the small circle into the card")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
        }
        .navigationTitle("iOS 27 Glass")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { isDarkMode.toggle() }) {
                    Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                }
                Button(action: { showingControls = true }) {
                    Image(systemName: "gearshape.fill")
                }
                .accessibilityIdentifier("glass27Controls")
            }
        }
        .sheet(isPresented: $showingControls) {
            Glass27SettingsSheet(
                tintColor: $tintColor,
                tintIntensity: $tintIntensity,
                highlightPreservation: $highlightPreservation,
                usesClearPreset: $usesClearPreset,
                mergeSmoothing: $mergeSmoothing,
                presentDimmingSheet: {
                    showingControls = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingDimmingSheet = true
                    }
                }
            )
        }
        .sheet(isPresented: $showingDimmingSheet) {
            DimmingInfoSheet()
                .modifier(MediumDetentIfAvailable())
        }
    }

    private var spectrumBinding: Binding<Double> {
        Binding(
            get: { tintSpectrum },
            set: { newValue in
                tintSpectrum = newValue
                TheseusSettings.shared.tintSpectrum = CGFloat(newValue)
            }
        )
    }
}

// MARK: - Dimming Sheet

struct MediumDetentIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.presentationDetents([.medium])
        } else {
            content
        }
    }
}

struct DimmingInfoSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.haze.fill")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("Tint dimming")
                .font(.headline)
            Text("While this sheet is up, UIKit sets tintAdjustmentMode to .dimmed on the views behind it. The glass tint desaturates to gray, the same way native tinted controls do, and restores when you dismiss.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 32)
    }
}

// MARK: - Settings Sheet

struct Glass27SettingsSheet: View {
    @Binding var tintColor: Color
    @Binding var tintIntensity: Float
    @Binding var highlightPreservation: Float
    @Binding var usesClearPreset: Bool
    @Binding var mergeSmoothing: Float
    var presentDimmingSheet: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    ColorPicker("Tint Color", selection: $tintColor, supportsOpacity: true)
                    VStack(alignment: .leading) {
                        Text("Intensity: \(String(format: "%.2f", tintIntensity))")
                        Slider(value: $tintIntensity, in: 0...1)
                    }
                    VStack(alignment: .leading) {
                        Text("Highlight Hue Retention: \(String(format: "%.2f", highlightPreservation))")
                        Slider(value: $highlightPreservation, in: 0...1)
                    }
                } header: {
                    Text("Per-View Tint")
                } footer: {
                    Text("Mirrors glassEffect(.regular.tint(...)). Highlight retention recolors rim and specular highlights in OKLab so lit tinted glass keeps its hue.")
                }

                Section {
                    Toggle("Clear preset (.clear)", isOn: $usesClearPreset)
                } footer: {
                    Text("Mirrors glassEffect(.clear): permanently more transparent, reduced edge effects.")
                }

                Section {
                    VStack(alignment: .leading) {
                        Text("Merge Smoothing: \(String(format: "%.0f", mergeSmoothing)) pt")
                        Slider(value: $mergeSmoothing, in: 2...40)
                    }
                } header: {
                    Text("Shape Merging")
                } footer: {
                    Text("The GlassEffectContainer analog. Drag the satellite circle on the demo - larger smoothing makes shapes melt together earlier.")
                }

                Section {
                    Button("Present a sheet (tint dimming)") {
                        presentDimmingSheet()
                    }
                } footer: {
                    Text("Glass tint desaturates behind sheets via tintAdjustmentMode, like native tinted controls.")
                }

                Section {
                    Button("Reset to Defaults", role: .destructive) {
                        tintColor = Color(red: 0.0, green: 0.45, blue: 1.0)
                        tintIntensity = 0.8
                        highlightPreservation = 0.5
                        usesClearPreset = false
                        mergeSmoothing = 24.0
                    }
                }
            }
            .navigationTitle("iOS 27 Glass")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Container

struct Glass27ContainerRepresentable: UIViewRepresentable {
    var isDarkMode: Bool
    var tintColor: UIColor
    var tintIntensity: CGFloat
    var highlightPreservation: CGFloat
    var usesClearPreset: Bool
    var mergeSmoothing: CGFloat

    func makeUIView(context: Context) -> Glass27Container {
        let container = Glass27Container()
        container.updateSettings(
            tintColor: tintColor,
            tintIntensity: tintIntensity,
            highlightPreservation: highlightPreservation,
            usesClearPreset: usesClearPreset,
            mergeSmoothing: mergeSmoothing
        )
        container.updateBackground(isDarkMode: isDarkMode)
        return container
    }

    func updateUIView(_ uiView: Glass27Container, context: Context) {
        uiView.updateSettings(
            tintColor: tintColor,
            tintIntensity: tintIntensity,
            highlightPreservation: highlightPreservation,
            usesClearPreset: usesClearPreset,
            mergeSmoothing: mergeSmoothing
        )
        uiView.updateBackground(isDarkMode: isDarkMode)
    }
}

class Glass27Container: UIView {

    // Satellite travel margin around the card; also the shape padding, so
    // the shader can draw there.
    private static let apron: CGFloat = 80

    private let backgroundImageView = UIImageView()
    private var glass: TheseusView?
    private var satelliteCenter = CGPoint.zero   // in the glass view's coordinates
    private var satelliteRadius: CGFloat = 34
    private var isDraggingSatellite = false
    private var isDarkMode = false

    private var currentTintColor: UIColor = .systemBlue
    private var currentTintIntensity: CGFloat = 0.8
    private var currentHighlightPreservation: CGFloat = 0.5
    private var currentUsesClearPreset = false
    private var currentMergeSmoothing: CGFloat = 24.0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        backgroundColor = .clear
        clipsToBounds = true

        // The glass captures from this container; a SwiftUI background behind
        // the representable would be invisible to it.
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(backgroundImageView)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundImageView.frame = bounds

        if glass == nil && bounds.width > 0 {
            setupGlass()
            updateBackground(isDarkMode: isDarkMode)
            if UserDefaults.standard.bool(forKey: "autodrag") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.startAutoDragDemo()
                }
            }
        }
    }

    func updateBackground(isDarkMode: Bool) {
        let needsRender = self.isDarkMode != isDarkMode || backgroundImageView.image == nil
        self.isDarkMode = isDarkMode
        guard bounds.width > 0, needsRender else { return }

        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = bounds
        if isDarkMode {
            gradientLayer.colors = [
                UIColor(red: 0.12, green: 0.10, blue: 0.28, alpha: 1.0).cgColor,
                UIColor(red: 0.22, green: 0.12, blue: 0.22, alpha: 1.0).cgColor,
                UIColor(red: 0.28, green: 0.18, blue: 0.12, alpha: 1.0).cgColor,
                UIColor(red: 0.12, green: 0.22, blue: 0.28, alpha: 1.0).cgColor
            ]
        } else {
            gradientLayer.colors = [
                UIColor(red: 0.92, green: 0.82, blue: 0.98, alpha: 1.0).cgColor,
                UIColor(red: 0.82, green: 0.95, blue: 0.98, alpha: 1.0).cgColor,
                UIColor(red: 0.98, green: 0.95, blue: 0.82, alpha: 1.0).cgColor,
                UIColor(red: 0.98, green: 0.82, blue: 0.88, alpha: 1.0).cgColor
            ]
        }
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)

        UIGraphicsBeginImageContextWithOptions(bounds.size, true, 0)
        if let context = UIGraphicsGetCurrentContext() {
            gradientLayer.render(in: context)
        }
        backgroundImageView.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        glass?.invalidateBackground()
    }

    private func setupGlass() {
        let cardSize = CGSize(
            width: min(bounds.width - 2 * Self.apron - 40, 230),
            height: 170
        )

        let glassView = TheseusView()
        glassView.frame = CGRect(
            x: (bounds.width - cardSize.width) / 2,
            y: (bounds.height - cardSize.height) / 2 - 60,
            width: cardSize.width,
            height: cardSize.height
        )
        glassView.sourceView = self
        addSubview(glassView)
        glass = glassView

        satelliteCenter = CGPoint(x: cardSize.width + 8, y: cardSize.height / 2)

        applySettings()
    }

    func updateSettings(
        tintColor: UIColor,
        tintIntensity: CGFloat,
        highlightPreservation: CGFloat,
        usesClearPreset: Bool,
        mergeSmoothing: CGFloat
    ) {
        currentTintColor = tintColor
        currentTintIntensity = tintIntensity
        currentHighlightPreservation = highlightPreservation
        currentUsesClearPreset = usesClearPreset
        currentMergeSmoothing = mergeSmoothing
        applySettings()
    }

    private func applySettings() {
        guard let glass = glass else { return }

        var config: TheseusConfiguration = currentUsesClearPreset ? .clear : .regular
        config = config.tint(currentTintColor, intensity: currentTintIntensity)
        config.theme.highlightTintPreservation = currentHighlightPreservation
        config.shape.cornerRadius = 28
        config.shape.padding = CGPoint(x: Self.apron, y: Self.apron)
        config.shape.mergedShapes = [satelliteShape()]
        config.shape.mergeSmoothing = currentMergeSmoothing
        config.captureMethod = .layerRendering
        // Speculars keep their defaults; without them the tinted card reads as a flat slab.

        glass.configuration = config
    }

    private func satelliteShape() -> TheseusMergedShape {
        TheseusMergedShape(
            frame: CGRect(
                x: satelliteCenter.x - satelliteRadius,
                y: satelliteCenter.y - satelliteRadius,
                width: satelliteRadius * 2,
                height: satelliteRadius * 2
            ),
            cornerRadius: satelliteRadius
        )
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let glass = glass else { return }

        let locationInGlass = gesture.location(in: glass)

        switch gesture.state {
        case .began:
            let grabRadius = satelliteRadius + 30
            let dx = locationInGlass.x - satelliteCenter.x
            let dy = locationInGlass.y - satelliteCenter.y
            isDraggingSatellite = (dx * dx + dy * dy) <= grabRadius * grabRadius
            if isDraggingSatellite {
                glass.continuousUpdate = true
            }

        case .changed:
            guard isDraggingSatellite else { return }
            let minX = -Self.apron + satelliteRadius + 4
            let maxX = glass.bounds.width + Self.apron - satelliteRadius - 4
            let minY = -Self.apron + satelliteRadius + 4
            let maxY = glass.bounds.height + Self.apron - satelliteRadius - 4
            satelliteCenter = CGPoint(
                x: max(minX, min(maxX, locationInGlass.x)),
                y: max(minY, min(maxY, locationInGlass.y))
            )
            applySettings()

        case .ended, .cancelled, .failed:
            if isDraggingSatellite {
                glass.continuousUpdate = false
            }
            isDraggingSatellite = false

        default:
            break
        }
    }

    // MARK: - Scripted Drag (capture_assets.sh)

    // `-autodrag 1` replays the pan path; the simulator HID stack cannot
    // emit touch-move events.
    private var autoDragLink: CADisplayLink?
    private var autoDragStart: CFTimeInterval = 0

    func startAutoDragDemo() {
        guard autoDragLink == nil, let glass = glass else { return }
        glass.continuousUpdate = true
        autoDragStart = CACurrentMediaTime()
        autoDragLink = CADisplayLink(target: self, selector: #selector(stepAutoDrag))
        autoDragLink?.add(to: .main, forMode: .common)
    }

    @objc private func stepAutoDrag() {
        guard let glass = glass else { return }
        let t = CACurrentMediaTime() - autoDragStart
        let w = glass.bounds.width
        let h = glass.bounds.height
        let home = CGPoint(x: w + 8, y: h / 2)
        let inside = CGPoint(x: w * 0.4, y: h / 2)
        let outside = CGPoint(x: w + 42, y: h / 2 + 26)

        let segments: [(start: Double, duration: Double, from: CGPoint, to: CGPoint)] = [
            (0.6, 1.6, home, inside),
            (2.8, 1.8, inside, outside),
            (5.2, 1.2, outside, home)
        ]

        var position = home
        for seg in segments {
            if t >= seg.start + seg.duration {
                position = seg.to
            } else if t >= seg.start {
                let p = (t - seg.start) / seg.duration
                let eased = 0.5 - 0.5 * cos(p * .pi)
                position = CGPoint(
                    x: seg.from.x + (seg.to.x - seg.from.x) * eased,
                    y: seg.from.y + (seg.to.y - seg.from.y) * eased
                )
            }
        }

        satelliteCenter = position
        applySettings()

        if t > 6.8 {
            autoDragLink?.invalidate()
            autoDragLink = nil
            glass.continuousUpdate = false
        }
    }
}

#Preview {
    NavigationView {
        Glass27DemoView()
    }
}
