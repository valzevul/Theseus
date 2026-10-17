import SwiftUI
import Theseus

// MARK: - Balloon Configuration

struct BalloonConfig {
    let symbolName: String
    let tintColor: UIColor
    let size: CGFloat
    let targetAngle: CGFloat
    let targetRadius: CGFloat
}

struct BalloonPhysicsState {
    var velocity: CGPoint = .zero
    var targetVelocity: CGPoint = .zero
    var isReleased: Bool = false
    var isDragging: Bool = false
}

// MARK: - Glass View Demo

struct GlassViewDemoView: View {
    @State private var showingSettings = false
    @AppStorage("isDarkMode") private var isDarkMode = false

    // Settings - tuned for dramatic refraction
    @State private var blurRadius: Float = 2.0
    @State private var cornerRadius: Float = 40.0
    @State private var refractionFactor: Float = 1.8
    @State private var fresnelFactor: Float = 1.4
    @State private var continuousUpdate: Bool = false
    @State private var tintColor: Color = .clear
    @State private var tintIntensity: Float = 1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Colorful gradient background for refraction showcase
                GlassDemoGradient(isDarkMode: isDarkMode)
                    .ignoresSafeArea()

                // Glass demo container
                GlassDemoContainerRepresentable(
                    isDarkMode: isDarkMode,
                    blurRadius: CGFloat(blurRadius),
                    cornerRadius: CGFloat(cornerRadius),
                    refractionFactor: CGFloat(refractionFactor),
                    fresnelFactor: CGFloat(fresnelFactor),
                    continuousUpdate: continuousUpdate,
                    tintColor: UIColor(tintColor),
                    tintIntensity: CGFloat(tintIntensity)
                )
                .ignoresSafeArea()
            }
        }
        .navigationTitle("Glass View")
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
            GlassViewSettingsSheet(
                blurRadius: $blurRadius,
                cornerRadius: $cornerRadius,
                refractionFactor: $refractionFactor,
                fresnelFactor: $fresnelFactor,
                continuousUpdate: $continuousUpdate,
                tintColor: $tintColor,
                tintIntensity: $tintIntensity
            )
        }
    }
}

// MARK: - Gradient Background

struct GlassDemoGradient: View {
    var isDarkMode: Bool

    var body: some View {
        LinearGradient(
            colors: isDarkMode
                ? [Color(red: 0.12, green: 0.10, blue: 0.28),
                   Color(red: 0.22, green: 0.12, blue: 0.22),
                   Color(red: 0.28, green: 0.18, blue: 0.12),
                   Color(red: 0.12, green: 0.22, blue: 0.28)]
                : [Color(red: 0.92, green: 0.82, blue: 0.98),
                   Color(red: 0.82, green: 0.95, blue: 0.98),
                   Color(red: 0.98, green: 0.95, blue: 0.82),
                   Color(red: 0.98, green: 0.82, blue: 0.88)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Glass Demo Container

struct GlassDemoContainerRepresentable: UIViewRepresentable {
    var isDarkMode: Bool
    var blurRadius: CGFloat
    var cornerRadius: CGFloat
    var refractionFactor: CGFloat
    var fresnelFactor: CGFloat
    var continuousUpdate: Bool
    var tintColor: UIColor = .clear
    var tintIntensity: CGFloat = 1.0

    func makeUIView(context: Context) -> GlassDemoContainer {
        let container = GlassDemoContainer()
        container.updateSettings(
            blurRadius: blurRadius,
            cornerRadius: cornerRadius,
            refractionFactor: refractionFactor,
            fresnelFactor: fresnelFactor,
            continuousUpdate: continuousUpdate,
            tintColor: tintColor,
            tintIntensity: tintIntensity
        )
        return container
    }

    func updateUIView(_ uiView: GlassDemoContainer, context: Context) {
        uiView.updateSettings(
            blurRadius: blurRadius,
            cornerRadius: cornerRadius,
            refractionFactor: refractionFactor,
            fresnelFactor: fresnelFactor,
            continuousUpdate: continuousUpdate,
            tintColor: tintColor,
            tintIntensity: tintIntensity
        )
        uiView.updateBackground(isDarkMode: isDarkMode)
    }
}

class GlassDemoContainer: UIView {

    // MARK: - Balloon Configs

    private let balloonConfigs: [BalloonConfig] = [
        BalloonConfig(symbolName: "heart.fill", tintColor: .systemPink, size: 60, targetAngle: -.pi * 0.85, targetRadius: 140),
        BalloonConfig(symbolName: "star.fill", tintColor: .systemYellow, size: 55, targetAngle: -.pi * 0.6, targetRadius: 170),
        BalloonConfig(symbolName: "bell.fill", tintColor: .systemBlue, size: 50, targetAngle: -.pi * 0.35, targetRadius: 155),
        BalloonConfig(symbolName: "bolt.fill", tintColor: .systemOrange, size: 58, targetAngle: -.pi * 0.1, targetRadius: 145),
        BalloonConfig(symbolName: "leaf.fill", tintColor: .systemGreen, size: 52, targetAngle: .pi * 0.1, targetRadius: 160),
        BalloonConfig(symbolName: "drop.fill", tintColor: .systemTeal, size: 56, targetAngle: .pi * 0.35, targetRadius: 150),
        BalloonConfig(symbolName: "flame.fill", tintColor: .systemRed, size: 54, targetAngle: .pi * 0.6, targetRadius: 165),
        BalloonConfig(symbolName: "sparkles", tintColor: .systemPurple, size: 60, targetAngle: .pi * 0.85, targetRadius: 145)
    ]

    // MARK: - Properties

    private let backgroundImageView = UIImageView()
    private var theseusView: TheseusView!
    private var gestureHandler: TheseusGestureDeformer?

    private var balloonViews: [TheseusView] = []
    private var balloonPhysics: [BalloonPhysicsState] = []
    private var balloonGestureHandlers: [TheseusGestureDeformer] = []
    private var displayLink: CADisplayLink?
    private var dragProgress: CGFloat = 0
    private var pulsePhase: CGFloat = 0
    private var lensRestingY: CGFloat = 0
    private var isDarkMode: Bool = false

    // Current settings
    private var currentBlurRadius: CGFloat = 2.0
    private var currentCornerRadius: CGFloat = 40.0
    private var currentRefractionFactor: CGFloat = 1.8
    private var currentFresnelFactor: CGFloat = 1.4
    private var currentContinuousUpdate: Bool = false
    private var currentTintColor: UIColor = .clear
    private var currentTintIntensity: CGFloat = 1.0

    // MARK: - Initialization

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

        // Background for gradient rendering
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(backgroundImageView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        backgroundImageView.frame = bounds

        if theseusView == nil && bounds.width > 0 {
            setupTheseusView()
            setupBalloonViews()
            startAnimationLoop()
            updateBackground(isDarkMode: isDarkMode)
            if UserDefaults.standard.bool(forKey: "autodrag") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.startAutoDragDemo()
                }
            }
        }
    }

    // MARK: - Background

    func updateBackground(isDarkMode: Bool) {
        self.isDarkMode = isDarkMode
        guard bounds.width > 0 else { return }

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
        let gradientImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        backgroundImageView.image = gradientImage
    }

    // MARK: - Settings

    func updateSettings(
        blurRadius: CGFloat,
        cornerRadius: CGFloat,
        refractionFactor: CGFloat,
        fresnelFactor: CGFloat,
        continuousUpdate: Bool,
        tintColor: UIColor = .clear,
        tintIntensity: CGFloat = 1.0
    ) {
        currentBlurRadius = blurRadius
        currentCornerRadius = cornerRadius
        currentRefractionFactor = refractionFactor
        currentFresnelFactor = fresnelFactor
        currentContinuousUpdate = continuousUpdate
        currentTintColor = tintColor
        currentTintIntensity = tintIntensity

        applySettings()
    }

    private func applySettings() {
        guard let theseusView = theseusView else { return }
        theseusView.blur.radius = currentBlurRadius
        theseusView.shape.cornerRadius = currentCornerRadius
        theseusView.refraction.intensity = currentRefractionFactor
        theseusView.edgeEffects.rimGlow = currentFresnelFactor
        theseusView.continuousUpdate = currentContinuousUpdate
        theseusView.theme.tintColor = currentTintColor
        theseusView.theme.tintOpacity = currentTintIntensity

        // Clear specular colors to prevent white edge artifacts
        theseusView.edgeEffects.nearColor = .clear
        theseusView.edgeEffects.farColor = .clear
    }

    // MARK: - Theseus View Setup

    private func setupTheseusView() {
        let lensSize: CGFloat = 80

        var config = TheseusConfiguration()
        config.blur.radius = currentBlurRadius
        config.shape.cornerRadius = lensSize / 2
        // Near-clear body whatever the global spectrum; 1.35 matches the native lens.
        config.theme.neutralBodyScale = 0.15
        config.refraction.magnification = 1.35
        config.refraction.intensity = currentRefractionFactor
        // Covers the ring's outward reach at this index (~34 pt at 1.8).
        config.shape.padding = CGPoint(x: 34, y: 34)
        config = config.tint(currentTintColor, intensity: currentTintIntensity)
        // Clear specular colors to prevent white edge artifacts
        config.edgeEffects.nearColor = .clear
        config.edgeEffects.farColor = .clear

        theseusView = TheseusView(configuration: config)
        theseusView.sourceView = self

        lensRestingY = bounds.height - 120
        theseusView.frame = CGRect(
            x: (bounds.width - lensSize) / 2,
            y: lensRestingY - lensSize / 2,
            width: lensSize,
            height: lensSize
        )
        addSubview(theseusView)

        setupGestureHandler()

        // Hand icon
        let handIcon = UIImageView(image: UIImage(systemName: "hand.point.up.fill"))
        handIcon.tintColor = .label
        handIcon.contentMode = .scaleAspectFit
        handIcon.translatesAutoresizingMaskIntoConstraints = false
        theseusView.addSubview(handIcon)

        NSLayoutConstraint.activate([
            handIcon.centerXAnchor.constraint(equalTo: theseusView.centerXAnchor),
            handIcon.centerYAnchor.constraint(equalTo: theseusView.centerYAnchor),
            handIcon.widthAnchor.constraint(equalToConstant: 28),
            handIcon.heightAnchor.constraint(equalToConstant: 28)
        ])

        // Double-tap to reset
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        theseusView.addGestureRecognizer(doubleTap)
    }

    @objc private func handleDoubleTap() {
        resetBalloons()
    }

    private func resetBalloons() {
        balloonGestureHandlers.removeAll()

        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: []) {
            for (index, balloon) in self.balloonViews.enumerated() {
                self.balloonPhysics[index] = BalloonPhysicsState()
                balloon.alpha = 0
                balloon.center = CGPoint(x: self.bounds.width / 2, y: self.lensRestingY)
                balloon.transform = .identity
            }
        }
    }

    // MARK: - Gesture Handler

    private func setupGestureHandler() {
        gestureHandler = TheseusGestureDeformer(targetView: theseusView)

        gestureHandler?.positionProvider = { [weak self] translation, currentCenter, bounds in
            guard let self = self else { return nil }

            var newY = currentCenter.y + translation.y
            let topY: CGFloat = 180
            let bottomY = self.lensRestingY

            newY = max(topY, min(bottomY, newY))

            self.dragProgress = 1.0 - (newY - topY) / (bottomY - topY)
            self.dragProgress = max(0, min(1, self.dragProgress))

            let scale = 1.0 + self.dragProgress * 0.6
            self.theseusView.transform = CGAffineTransform(scaleX: scale, y: scale)

            return CGPoint(x: bounds.width / 2, y: newY)
        }

        gestureHandler?.onDragBegan = { [weak self] in
            guard let self = self else { return }
            self.theseusView.continuousUpdate = true
            self.balloonViews.forEach { $0.continuousUpdate = true }
        }

        gestureHandler?.onDragEnded = { [weak self] velocity in
            guard let self = self else { return }

            if self.dragProgress > 0.2 {
                self.releaseBalloons()
            }

            let distanceToRest = self.lensRestingY - self.theseusView.center.y
            let springVelocity = distanceToRest != 0 ? abs(velocity.y / distanceToRest) * 0.3 : 0

            UIView.animate(
                withDuration: 1.0,
                delay: 0,
                usingSpringWithDamping: 0.65,
                initialSpringVelocity: springVelocity,
                options: [.allowUserInteraction]
            ) {
                self.theseusView.center = CGPoint(x: self.bounds.width / 2, y: self.lensRestingY)
                self.theseusView.transform = .identity
            }

            self.animateDragProgressToZero()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self.theseusView.continuousUpdate = false
                for (index, balloon) in self.balloonViews.enumerated() {
                    if !self.balloonPhysics[index].isReleased {
                        balloon.continuousUpdate = false
                    }
                }
            }
        }
    }

    // MARK: - Scripted Drag (capture_assets.sh)

    // `-autodrag 1` replays the lens pull; the simulator HID stack cannot
    // emit touch-move events.
    private var autoDragLink: CADisplayLink?
    private var autoDragStart: CFTimeInterval = 0

    func startAutoDragDemo() {
        guard autoDragLink == nil, theseusView != nil else { return }
        theseusView.continuousUpdate = true
        balloonViews.forEach { $0.continuousUpdate = true }
        autoDragStart = CACurrentMediaTime()
        autoDragLink = CADisplayLink(target: self, selector: #selector(stepAutoDrag))
        autoDragLink?.add(to: .main, forMode: .common)
    }

    @objc private func stepAutoDrag() {
        let t = CACurrentMediaTime() - autoDragStart
        let topY: CGFloat = 180
        let bottomY = lensRestingY

        let pullStart = 0.6
        let pullDuration = 1.8
        let holdEnd = 4.0

        if t < pullStart {
            return
        } else if t < pullStart + pullDuration {
            let p = (t - pullStart) / pullDuration
            let eased = 0.5 - 0.5 * cos(p * .pi)
            let newY = bottomY + (topY - bottomY) * eased
            dragProgress = max(0, min(1, 1.0 - (newY - topY) / (bottomY - topY)))
            let scale = 1.0 + dragProgress * 0.6
            theseusView.transform = CGAffineTransform(scaleX: scale, y: scale)
            theseusView.center = CGPoint(x: bounds.width / 2, y: newY)
        } else if t < holdEnd {
            // Hold at the top; balloons keep springing via the animation loop.
        } else {
            autoDragLink?.invalidate()
            autoDragLink = nil
            endAutoDrag()
        }
    }

    private func endAutoDrag() {
        // Keep in step with onDragEnded.
        if dragProgress > 0.2 {
            releaseBalloons()
        }
        UIView.animate(
            withDuration: 1.0,
            delay: 0,
            usingSpringWithDamping: 0.65,
            initialSpringVelocity: 0.3,
            options: [.allowUserInteraction]
        ) {
            self.theseusView.center = CGPoint(x: self.bounds.width / 2, y: self.lensRestingY)
            self.theseusView.transform = .identity
        }
        animateDragProgressToZero()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self else { return }
            self.theseusView.continuousUpdate = false
            for (index, balloon) in self.balloonViews.enumerated() {
                if !self.balloonPhysics[index].isReleased {
                    balloon.continuousUpdate = false
                }
            }
        }
    }

    private func animateDragProgressToZero() {
        let startProgress = dragProgress
        let duration: Double = 1.0
        let startTime = CACurrentMediaTime()

        let animator = CADisplayLink(target: self, selector: #selector(animateProgressTick))
        animator.add(to: .main, forMode: .common)

        objc_setAssociatedObject(self, "progressAnimator", animator, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, "startProgress", startProgress, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, "animStartTime", startTime, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, "animDuration", duration, .OBJC_ASSOCIATION_RETAIN)
    }

    @objc private func animateProgressTick() {
        guard let animator = objc_getAssociatedObject(self, "progressAnimator") as? CADisplayLink,
              let startProgress = objc_getAssociatedObject(self, "startProgress") as? CGFloat,
              let startTime = objc_getAssociatedObject(self, "animStartTime") as? Double,
              let duration = objc_getAssociatedObject(self, "animDuration") as? Double else { return }

        let elapsed = CACurrentMediaTime() - startTime
        let t = min(1.0, elapsed / duration)

        let eased: CGFloat
        if t < 0.5 {
            eased = 2.0 * t * t
        } else {
            eased = 1.0 - pow(-2.0 * t + 2.0, 2) / 2.0
        }
        dragProgress = startProgress * (1.0 - eased)

        if t >= 1.0 {
            dragProgress = 0
            animator.invalidate()
            objc_setAssociatedObject(self, "progressAnimator", nil, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    // MARK: - Balloon Views

    private func setupBalloonViews() {
        for config in balloonConfigs {
            var balloonConfig = TheseusConfiguration()
            balloonConfig.shape.cornerRadius = config.size / 2
            balloonConfig.blur.radius = 10
            balloonConfig.refraction.intensity = 1.6
            balloonConfig.theme.neutralBodyScale = 0.15
            balloonConfig.theme.tintColor = .clear
            // Covers the ring's outward reach at this index (~28 pt).
            balloonConfig.shape.padding = CGPoint(x: 28, y: 28)
            // Clear specular colors to prevent white edge artifacts
            balloonConfig.edgeEffects.nearColor = .clear
            balloonConfig.edgeEffects.farColor = .clear

            let balloon = TheseusView(configuration: balloonConfig)
            balloon.sourceView = self
            balloon.frame = CGRect(x: 0, y: 0, width: config.size, height: config.size)
            balloon.center = CGPoint(x: bounds.width / 2, y: lensRestingY)
            balloon.alpha = 0

            let symbol = UIImageView(image: UIImage(systemName: config.symbolName))
            symbol.tintColor = config.tintColor
            symbol.contentMode = .scaleAspectFit
            symbol.translatesAutoresizingMaskIntoConstraints = false
            balloon.addSubview(symbol)

            NSLayoutConstraint.activate([
                symbol.centerXAnchor.constraint(equalTo: balloon.centerXAnchor),
                symbol.centerYAnchor.constraint(equalTo: balloon.centerYAnchor),
                symbol.widthAnchor.constraint(equalToConstant: config.size * 0.45),
                symbol.heightAnchor.constraint(equalToConstant: config.size * 0.45)
            ])

            insertSubview(balloon, belowSubview: theseusView)
            balloonViews.append(balloon)
            balloonPhysics.append(BalloonPhysicsState())
        }
    }

    // MARK: - Animation Loop

    private func startAnimationLoop() {
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(updateAnimations))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopAnimationLoop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func updateAnimations() {
        updateBalloonPositions()
        updatePulseAnimation()
    }

    private func updateBalloonPositions() {
        let lensCenter = theseusView.center

        for (index, balloon) in balloonViews.enumerated() {
            let config = balloonConfigs[index]

            if balloonPhysics[index].isReleased && !balloonPhysics[index].isDragging {
                balloonPhysics[index].velocity.y += 0.4
                balloonPhysics[index].velocity.x *= 0.98
                balloonPhysics[index].velocity.y *= 0.98

                var newCenter = balloon.center
                newCenter.x += balloonPhysics[index].velocity.x
                newCenter.y += balloonPhysics[index].velocity.y

                let floorY = bounds.height - balloon.bounds.height / 2 - 20
                if newCenter.y >= floorY {
                    newCenter.y = floorY
                    balloonPhysics[index].velocity.y = -balloonPhysics[index].velocity.y * 0.4
                    balloonPhysics[index].velocity.x *= 0.85

                    if abs(balloonPhysics[index].velocity.y) < 0.5 {
                        balloonPhysics[index].velocity.y = 0
                    }
                    if abs(balloonPhysics[index].velocity.x) < 0.3 {
                        balloonPhysics[index].velocity.x = 0
                    }
                }

                let minX = balloon.bounds.width / 2
                let maxX = bounds.width - balloon.bounds.width / 2
                if newCenter.x < minX {
                    newCenter.x = minX
                    balloonPhysics[index].velocity.x = -balloonPhysics[index].velocity.x * 0.5
                } else if newCenter.x > maxX {
                    newCenter.x = maxX
                    balloonPhysics[index].velocity.x = -balloonPhysics[index].velocity.x * 0.5
                }

                let minY = balloon.bounds.height / 2
                if newCenter.y < minY {
                    newCenter.y = minY
                    balloonPhysics[index].velocity.y = -balloonPhysics[index].velocity.y * 0.5
                }

                balloon.center = newCenter
            } else if !balloonPhysics[index].isReleased {
                let radius = config.targetRadius * dragProgress
                let targetX = lensCenter.x + cos(config.targetAngle) * radius
                let targetY = lensCenter.y + sin(config.targetAngle) * radius - 40 * dragProgress

                let springFactor: CGFloat = 0.08
                let dampingFactor: CGFloat = 0.85

                let dx = targetX - balloon.center.x
                let dy = targetY - balloon.center.y

                balloonPhysics[index].targetVelocity.x = balloonPhysics[index].targetVelocity.x * dampingFactor + dx * springFactor
                balloonPhysics[index].targetVelocity.y = balloonPhysics[index].targetVelocity.y * dampingFactor + dy * springFactor

                var newX = balloon.center.x + balloonPhysics[index].targetVelocity.x
                var newY = balloon.center.y + balloonPhysics[index].targetVelocity.y

                let padding = balloon.bounds.width / 2
                newX = max(padding, min(bounds.width - padding, newX))
                newY = max(padding, min(bounds.height - padding, newY))

                balloon.center.x = newX
                balloon.center.y = newY

                let appearThreshold = CGFloat(index) * 0.06
                let targetAlpha = max(0, min(1, (dragProgress - appearThreshold) * 4))
                balloon.alpha += (targetAlpha - balloon.alpha) * 0.1
            }
        }
    }

    private func updatePulseAnimation() {
        guard dragProgress > 0.05 else {
            for (index, balloon) in balloonViews.enumerated() {
                if !balloonPhysics[index].isReleased {
                    balloon.transform = .identity
                }
            }
            return
        }

        pulsePhase += 0.04

        for (index, balloon) in balloonViews.enumerated() {
            if !balloonPhysics[index].isReleased {
                let phaseOffset = CGFloat(index) * 0.5
                let pulseAmount = 0.08 * dragProgress
                let pulse = 1.0 + sin(pulsePhase + phaseOffset) * pulseAmount
                balloon.transform = CGAffineTransform(scaleX: pulse, y: pulse)
            }
        }
    }

    // MARK: - Balloon Gestures

    private func setupBalloonGesture(for balloon: TheseusView, at index: Int) {
        let handler = TheseusGestureDeformer(targetView: balloon)

        handler.positionProvider = { [weak self] translation, currentCenter, bounds in
            guard self != nil else { return nil }

            var newCenter = CGPoint(
                x: currentCenter.x + translation.x,
                y: currentCenter.y + translation.y
            )

            let size = balloon.bounds.size
            newCenter.x = max(size.width / 2, min(bounds.width - size.width / 2, newCenter.x))
            newCenter.y = max(100, min(bounds.height - size.height / 2 - 20, newCenter.y))

            return newCenter
        }

        handler.onDragBegan = { [weak self] in
            guard let self = self else { return }
            self.balloonPhysics[index].isDragging = true
            self.balloonPhysics[index].velocity = .zero
            balloon.continuousUpdate = true
        }

        handler.onDragEnded = { [weak self] velocity in
            guard let self = self else { return }
            self.balloonPhysics[index].isDragging = false
            self.balloonPhysics[index].velocity = CGPoint(
                x: velocity.x * 0.08,
                y: velocity.y * 0.08
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                balloon.continuousUpdate = false
            }
        }

        balloonGestureHandlers.append(handler)
    }

    private func releaseBalloons() {
        for (index, balloon) in balloonViews.enumerated() {
            if balloon.alpha > 0.3 && !balloonPhysics[index].isReleased {
                balloonPhysics[index].isReleased = true
                let config = balloonConfigs[index]
                balloonPhysics[index].velocity = CGPoint(
                    x: cos(config.targetAngle) * 2 + CGFloat.random(in: -1...1),
                    y: CGFloat.random(in: (-4)...(-1))
                )
                setupBalloonGesture(for: balloon, at: index)
            }
        }
    }

    deinit {
        stopAnimationLoop()
    }
}

// MARK: - Settings Sheet

struct GlassViewSettingsSheet: View {
    @Binding var blurRadius: Float
    @Binding var cornerRadius: Float
    @Binding var refractionFactor: Float
    @Binding var fresnelFactor: Float
    @Binding var continuousUpdate: Bool
    @Binding var tintColor: Color
    @Binding var tintIntensity: Float
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Blur Radius: \(String(format: "%.0f", blurRadius))") {
                    Slider(value: $blurRadius, in: 0...30)
                }

                Section("Corner Radius: \(String(format: "%.0f", cornerRadius))") {
                    Slider(value: $cornerRadius, in: 0...75)
                }

                Section("Refraction Factor: \(String(format: "%.2f", refractionFactor))") {
                    Slider(value: $refractionFactor, in: 0...2.5)
                }

                Section("Fresnel Factor: \(String(format: "%.1f", fresnelFactor))") {
                    Slider(value: $fresnelFactor, in: 0...2)
                }

                Section {
                    ColorPicker("Tint Color", selection: $tintColor, supportsOpacity: true)
                    VStack(alignment: .leading) {
                        Text("Intensity: \(String(format: "%.2f", tintIntensity))")
                        Slider(value: $tintIntensity, in: 0...1)
                    }
                } header: {
                    Text("Glass Tint")
                } footer: {
                    Text("Mirrors glassEffect(.regular.tint(...)). The global Clear to Tinted spectrum in Settings fades it out toward the clear end.")
                }

                Section {
                    Toggle("Continuous Update", isOn: $continuousUpdate)
                }

                Section {
                    Button("Reset to Defaults", role: .destructive) {
                        blurRadius = 12.0
                        cornerRadius = 40.0
                        refractionFactor = 1.8
                        fresnelFactor = 1.4
                        continuousUpdate = false
                        tintColor = .clear
                        tintIntensity = 1.0
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
        GlassViewDemoView()
    }
}
