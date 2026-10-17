import UIKit
import Theseus

// MARK: - Balloon Configuration

struct BalloonConfig {
    let symbolName: String
    let tintColor: UIColor  // For SF Symbol only, glass is clear
    let size: CGFloat
    let targetAngle: CGFloat
    let targetRadius: CGFloat
}

struct BalloonPhysicsState {
    var velocity: CGPoint = .zero
    var targetVelocity: CGPoint = .zero  // For smooth interpolation when following
    var isReleased: Bool = false
    var isDragging: Bool = false
}

class ViewDemoViewController: UIViewController {

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

    // Balloon views
    private var balloonViews: [TheseusView] = []
    private var balloonPhysics: [BalloonPhysicsState] = []
    private var balloonGestureHandlers: [TheseusGestureDeformer] = []
    private var displayLink: CADisplayLink?
    private var dragProgress: CGFloat = 0
    private var pulsePhase: CGFloat = 0
    private var lensRestingY: CGFloat = 0

    // Defaults tuned for dramatic refraction showcase
    private struct Defaults {
        static let blurRadius: Float = 12.0
        static let cornerRadius: Float = 40.0
        static let refractionFactor: Float = 1.8
        static let fresnelFactor: Float = 1.4
        static let tintColorIndex = 0
        static let continuousUpdate = false

        static let tintColors: [UIColor] = [
            .clear,
            UIColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 0.3),
            UIColor(red: 0.9, green: 0.5, blue: 0.6, alpha: 0.3),
            UIColor(red: 0.9, green: 0.8, blue: 0.4, alpha: 0.3)
        ]
    }

    // Current settings
    private var currentBlurRadius = Defaults.blurRadius
    private var currentCornerRadius = Defaults.cornerRadius
    private var currentRefractionFactor = Defaults.refractionFactor
    private var currentFresnelFactor = Defaults.fresnelFactor
    private var currentTintColorIndex = Defaults.tintColorIndex
    private var currentContinuousUpdate = Defaults.continuousUpdate

    private var isDarkMode: Bool {
        get { AppearanceManager.shared.isDarkMode }
        set { AppearanceManager.shared.isDarkMode = newValue }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupBackground()
        setupNavigationBar()
        setupTheseusView()
        setupBalloonViews()
        applyDefaults()
        startAnimationLoop()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateAppearance()
    }

    private func setupBackground() {
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.frame = view.bounds
        backgroundImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(backgroundImageView)

        updateBackground()
    }

    private func updateBackground() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = view.bounds

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

        UIGraphicsBeginImageContextWithOptions(view.bounds.size, true, 0)
        if let context = UIGraphicsGetCurrentContext() {
            gradientLayer.render(in: context)
        }
        let gradientImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        backgroundImageView.image = gradientImage
        backgroundImageView.subviews.forEach { $0.removeFromSuperview() }
    }

    private func setupNavigationBar() {
        title = "Glass View"

        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gearshape.fill"),
            style: .plain,
            target: self,
            action: #selector(showSettings)
        )

        let darkModeButton = UIBarButtonItem(
            image: UIImage(systemName: "moon.fill"),
            style: .plain,
            target: self,
            action: #selector(toggleDarkMode)
        )

        navigationItem.rightBarButtonItems = [darkModeButton, settingsButton]
    }

    @objc private func toggleDarkMode() {
        isDarkMode.toggle()
        updateAppearance()
    }

    private func updateAppearance() {
        if let items = navigationItem.rightBarButtonItems, items.count > 0 {
            items[0].image = UIImage(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
        }

        updateBackground()
    }

    @objc private func showSettings() {
        let settingsVC = GlassViewSettingsViewController(
            blurRadius: currentBlurRadius,
            cornerRadius: currentCornerRadius,
            refractionFactor: currentRefractionFactor,
            fresnelFactor: currentFresnelFactor,
            tintColorIndex: currentTintColorIndex,
            continuousUpdate: currentContinuousUpdate
        )
        settingsVC.delegate = self

        let nav = UINavigationController(rootViewController: settingsVC)
        if #available(iOS 15.0, *) {
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
            }
        }
        present(nav, animated: true)
    }

    private func applyDefaults() {
        currentBlurRadius = Defaults.blurRadius
        currentCornerRadius = Defaults.cornerRadius
        currentRefractionFactor = Defaults.refractionFactor
        currentFresnelFactor = Defaults.fresnelFactor
        currentTintColorIndex = Defaults.tintColorIndex
        currentContinuousUpdate = Defaults.continuousUpdate

        applySettings()
    }

    private func applySettings() {
        theseusView.blur.radius = CGFloat(currentBlurRadius)
        theseusView.shape.cornerRadius = CGFloat(currentCornerRadius)
        theseusView.refraction.intensity = CGFloat(currentRefractionFactor)
        theseusView.edgeEffects.rimGlow = CGFloat(currentFresnelFactor)
        theseusView.theme.tintColor = Defaults.tintColors[currentTintColorIndex]
        theseusView.continuousUpdate = currentContinuousUpdate

        // Clear specular colors to prevent white edge artifacts
        theseusView.edgeEffects.nearColor = .clear
        theseusView.edgeEffects.farColor = .clear
    }

    private func setupTheseusView() {
        let lensSize: CGFloat = 80

        var config = TheseusConfiguration()
        config.blur.radius = CGFloat(Defaults.blurRadius)
        config.shape.cornerRadius = lensSize / 2  // Perfect circle
        config.refraction.intensity = CGFloat(Defaults.refractionFactor)
        // Covers the ring's outward reach at this index (~34 pt).
        config.shape.padding = CGPoint(x: 34, y: 34)
        config.theme.tintColor = .clear  // Transparent liquid glass
        // Clear specular colors to prevent white edge artifacts
        config.edgeEffects.nearColor = .clear
        config.edgeEffects.farColor = .clear

        theseusView = TheseusView(configuration: config)
        theseusView.sourceView = view  // Use view for mutual refraction with other glass

        // Position at bottom center
        lensRestingY = view.bounds.height - 120
        theseusView.frame = CGRect(
            x: (view.bounds.width - lensSize) / 2,
            y: lensRestingY - lensSize / 2,
            width: lensSize,
            height: lensSize
        )
        view.addSubview(theseusView)

        setupGestureHandler()

        // Hand icon instead of text
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

        // Double-tap to reset balloons
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        theseusView.addGestureRecognizer(doubleTap)
    }

    @objc private func handleDoubleTap() {
        resetBalloons()
    }

    private func resetBalloons() {
        // Remove all balloon gesture handlers
        balloonGestureHandlers.removeAll()

        // Animate balloons back to hidden state
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: []) {
            for (index, balloon) in self.balloonViews.enumerated() {
                self.balloonPhysics[index] = BalloonPhysicsState()
                balloon.alpha = 0
                balloon.center = CGPoint(x: self.view.bounds.width / 2, y: self.lensRestingY)
                balloon.transform = .identity
            }
        }
    }

    private func setupGestureHandler() {
        gestureHandler = TheseusGestureDeformer(targetView: theseusView)

        // Lock horizontal movement - only vertical dragging
        gestureHandler?.positionProvider = { [weak self] translation, currentCenter, bounds in
            guard let self = self else { return nil }

            // Only allow vertical movement
            var newY = currentCenter.y + translation.y

            // Constrain vertical movement
            let topY: CGFloat = 180
            let bottomY = self.lensRestingY

            newY = max(topY, min(bottomY, newY))

            // Calculate drag progress (0 at bottom, 1 at top)
            self.dragProgress = 1.0 - (newY - topY) / (bottomY - topY)
            self.dragProgress = max(0, min(1, self.dragProgress))

            // Scale lens based on drag progress
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

            // Release balloons into physics mode if they were dragged up
            if self.dragProgress > 0.2 {
                self.releaseBalloons()
            }

            // Calculate spring velocity from gesture for fluid feel
            let distanceToRest = self.lensRestingY - self.theseusView.center.y
            let springVelocity = distanceToRest != 0 ? abs(velocity.y / distanceToRest) * 0.3 : 0

            // Animate lens back with smooth fluid spring
            UIView.animate(
                withDuration: 1.0,
                delay: 0,
                usingSpringWithDamping: 0.65,
                initialSpringVelocity: springVelocity,
                options: [.allowUserInteraction]
            ) {
                self.theseusView.center = CGPoint(x: self.view.bounds.width / 2, y: self.lensRestingY)
                self.theseusView.transform = .identity
            }

            // Animate dragProgress back to 0
            self.animateDragProgressToZero()

            // Disable continuous update after animation fully settles
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self.theseusView.continuousUpdate = false
                // Keep released balloons updating for a bit longer
                for (index, balloon) in self.balloonViews.enumerated() {
                    if !self.balloonPhysics[index].isReleased {
                        balloon.continuousUpdate = false
                    }
                }
            }
        }
    }

    private func animateDragProgressToZero() {
        // Smoothly animate progress back - synced with spring duration
        let startProgress = dragProgress
        let duration: Double = 1.0
        let startTime = CACurrentMediaTime()

        let animator = CADisplayLink(target: self, selector: #selector(animateProgressTick))
        animator.add(to: .main, forMode: .common)

        // Store animation state
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

        // Smooth ease-in-out curve to match spring feel
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
            balloonConfig.blur.radius = 10  // More blur for dramatic refraction
            balloonConfig.refraction.intensity = 1.6  // More dramatic refraction
            balloonConfig.theme.tintColor = .clear  // Transparent liquid glass
            // Covers the ring's outward reach at this index (~28 pt).
            balloonConfig.shape.padding = CGPoint(x: 28, y: 28)
            // Clear specular colors to prevent white edge artifacts
            balloonConfig.edgeEffects.nearColor = .clear
            balloonConfig.edgeEffects.farColor = .clear

            let balloon = TheseusView(configuration: balloonConfig)
            balloon.sourceView = view  // Use view for mutual refraction with other glass
            balloon.frame = CGRect(x: 0, y: 0, width: config.size, height: config.size)
            balloon.center = CGPoint(x: view.bounds.width / 2, y: lensRestingY)
            balloon.alpha = 0

            // SF Symbol inside (colored for visual distinction)
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

            view.insertSubview(balloon, belowSubview: theseusView)
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
                // Physics mode: gravity + velocity + bounce
                balloonPhysics[index].velocity.y += 0.4  // Gravity
                balloonPhysics[index].velocity.x *= 0.98  // Air resistance
                balloonPhysics[index].velocity.y *= 0.98

                var newCenter = balloon.center
                newCenter.x += balloonPhysics[index].velocity.x
                newCenter.y += balloonPhysics[index].velocity.y

                // Floor bounce with strong friction
                let floorY = view.bounds.height - balloon.bounds.height / 2 - 20
                if newCenter.y >= floorY {
                    newCenter.y = floorY
                    balloonPhysics[index].velocity.y = -balloonPhysics[index].velocity.y * 0.4
                    // Strong horizontal friction on ground to stop rolling
                    balloonPhysics[index].velocity.x *= 0.85

                    // Stop completely if moving very slowly
                    if abs(balloonPhysics[index].velocity.y) < 0.5 {
                        balloonPhysics[index].velocity.y = 0
                    }
                    if abs(balloonPhysics[index].velocity.x) < 0.3 {
                        balloonPhysics[index].velocity.x = 0
                    }
                }

                // Wall bounce
                let minX = balloon.bounds.width / 2
                let maxX = view.bounds.width - balloon.bounds.width / 2
                if newCenter.x < minX {
                    newCenter.x = minX
                    balloonPhysics[index].velocity.x = -balloonPhysics[index].velocity.x * 0.5
                } else if newCenter.x > maxX {
                    newCenter.x = maxX
                    balloonPhysics[index].velocity.x = -balloonPhysics[index].velocity.x * 0.5
                }

                // Ceiling bounce
                let minY: CGFloat = 100
                if newCenter.y < minY {
                    newCenter.y = minY
                    balloonPhysics[index].velocity.y = -balloonPhysics[index].velocity.y * 0.5
                }

                balloon.center = newCenter
            } else if !balloonPhysics[index].isReleased {
                // Normal drag-follow behavior with velocity smoothing
                let radius = config.targetRadius * dragProgress
                let targetX = lensCenter.x + cos(config.targetAngle) * radius
                let targetY = lensCenter.y + sin(config.targetAngle) * radius - 40 * dragProgress

                // Velocity-based smoothing for fluid following
                let springFactor: CGFloat = 0.08  // Slower, smoother
                let dampingFactor: CGFloat = 0.85  // Velocity damping

                let dx = targetX - balloon.center.x
                let dy = targetY - balloon.center.y

                balloonPhysics[index].targetVelocity.x = balloonPhysics[index].targetVelocity.x * dampingFactor + dx * springFactor
                balloonPhysics[index].targetVelocity.y = balloonPhysics[index].targetVelocity.y * dampingFactor + dy * springFactor

                balloon.center.x += balloonPhysics[index].targetVelocity.x
                balloon.center.y += balloonPhysics[index].targetVelocity.y

                // Alpha based on progress (staggered appearance) - slower interpolation
                let appearThreshold = CGFloat(index) * 0.06
                let targetAlpha = max(0, min(1, (dragProgress - appearThreshold) * 4))
                balloon.alpha += (targetAlpha - balloon.alpha) * 0.1
            }
        }
    }

    private func updatePulseAnimation() {
        // Only pulse non-released balloons during drag
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

    // MARK: - Balloon Gesture Handlers

    private func setupBalloonGesture(for balloon: TheseusView, at index: Int) {
        let handler = TheseusGestureDeformer(targetView: balloon)

        handler.positionProvider = { [weak self] translation, currentCenter, bounds in
            guard self != nil else { return nil }

            var newCenter = CGPoint(
                x: currentCenter.x + translation.x,
                y: currentCenter.y + translation.y
            )

            // Keep within screen bounds
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
            // Apply throw velocity
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
            // Only release visible balloons
            if balloon.alpha > 0.3 && !balloonPhysics[index].isReleased {
                balloonPhysics[index].isReleased = true
                // Give initial velocity based on their spread position
                let config = balloonConfigs[index]
                balloonPhysics[index].velocity = CGPoint(
                    x: cos(config.targetAngle) * 2 + CGFloat.random(in: -1...1),
                    y: CGFloat.random(in: (-4)...(-1))
                )
                // Setup gesture handler for this balloon
                setupBalloonGesture(for: balloon, at: index)
            }
        }
    }

}

// MARK: - Settings Delegate

extension ViewDemoViewController: GlassViewSettingsDelegate {
    func settingsDidChange(blurRadius: Float, cornerRadius: Float, refractionFactor: Float, fresnelFactor: Float, tintColorIndex: Int, continuousUpdate: Bool) {
        currentBlurRadius = blurRadius
        currentCornerRadius = cornerRadius
        currentRefractionFactor = refractionFactor
        currentFresnelFactor = fresnelFactor
        currentTintColorIndex = tintColorIndex
        currentContinuousUpdate = continuousUpdate
        applySettings()
    }

    func settingsDidReset() {
        applyDefaults()
    }
}

// MARK: - Settings View Controller

protocol GlassViewSettingsDelegate: AnyObject {
    func settingsDidChange(blurRadius: Float, cornerRadius: Float, refractionFactor: Float, fresnelFactor: Float, tintColorIndex: Int, continuousUpdate: Bool)
    func settingsDidReset()
}

class GlassViewSettingsViewController: UIViewController {

    weak var delegate: GlassViewSettingsDelegate?

    private let blurSlider = UISlider()
    private let blurValueLabel = UILabel()
    private let cornerRadiusSlider = UISlider()
    private let cornerRadiusValueLabel = UILabel()
    private let refractionSlider = UISlider()
    private let refractionValueLabel = UILabel()
    private let fresnelSlider = UISlider()
    private let fresnelValueLabel = UILabel()
    private let tintSegment = UISegmentedControl(items: ["None", "Blue", "Pink", "Gold"])
    private let continuousToggle = UISwitch()

    private var initialBlurRadius: Float
    private var initialCornerRadius: Float
    private var initialRefractionFactor: Float
    private var initialFresnelFactor: Float
    private var initialTintColorIndex: Int
    private var initialContinuousUpdate: Bool

    init(blurRadius: Float, cornerRadius: Float, refractionFactor: Float, fresnelFactor: Float, tintColorIndex: Int, continuousUpdate: Bool) {
        self.initialBlurRadius = blurRadius
        self.initialCornerRadius = cornerRadius
        self.initialRefractionFactor = refractionFactor
        self.initialFresnelFactor = fresnelFactor
        self.initialTintColorIndex = tintColorIndex
        self.initialContinuousUpdate = continuousUpdate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Settings"

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissSettings)
        )

        setupControls()
    }

    @objc private func dismissSettings() {
        dismiss(animated: true)
    }

    private func setupControls() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        // Blur Radius
        blurValueLabel.text = String(format: "%.0f", initialBlurRadius)
        blurSlider.minimumValue = 0
        blurSlider.maximumValue = 30
        blurSlider.value = initialBlurRadius
        blurSlider.addTarget(self, action: #selector(blurChanged), for: .valueChanged)
        contentStack.addArrangedSubview(createSliderRow(label: "Blur Radius", valueLabel: blurValueLabel, slider: blurSlider))

        // Corner Radius
        cornerRadiusValueLabel.text = String(format: "%.0f", initialCornerRadius)
        cornerRadiusSlider.minimumValue = 0
        cornerRadiusSlider.maximumValue = 75
        cornerRadiusSlider.value = initialCornerRadius
        cornerRadiusSlider.addTarget(self, action: #selector(cornerRadiusChanged), for: .valueChanged)
        contentStack.addArrangedSubview(createSliderRow(label: "Corner Radius", valueLabel: cornerRadiusValueLabel, slider: cornerRadiusSlider))

        // Refraction Factor
        refractionValueLabel.text = String(format: "%.2f", initialRefractionFactor)
        refractionSlider.minimumValue = 0
        refractionSlider.maximumValue = 2.5
        refractionSlider.value = initialRefractionFactor
        refractionSlider.addTarget(self, action: #selector(refractionChanged), for: .valueChanged)
        contentStack.addArrangedSubview(createSliderRow(label: "Refraction Factor", valueLabel: refractionValueLabel, slider: refractionSlider))

        // Fresnel Factor
        fresnelValueLabel.text = String(format: "%.1f", initialFresnelFactor)
        fresnelSlider.minimumValue = 0
        fresnelSlider.maximumValue = 2
        fresnelSlider.value = initialFresnelFactor
        fresnelSlider.addTarget(self, action: #selector(fresnelChanged), for: .valueChanged)
        contentStack.addArrangedSubview(createSliderRow(label: "Fresnel Factor", valueLabel: fresnelValueLabel, slider: fresnelSlider))

        // Tint Color
        let tintLabel = createLabel("Tint Color")
        tintSegment.selectedSegmentIndex = initialTintColorIndex
        tintSegment.addTarget(self, action: #selector(settingsChanged), for: .valueChanged)
        contentStack.addArrangedSubview(createSettingRow(label: tintLabel, control: tintSegment))

        // Continuous Update Toggle
        let continuousLabel = createLabel("Continuous Update")
        continuousToggle.isOn = initialContinuousUpdate
        continuousToggle.addTarget(self, action: #selector(settingsChanged), for: .valueChanged)

        let continuousRow = UIStackView(arrangedSubviews: [continuousLabel, continuousToggle])
        continuousRow.axis = .horizontal
        continuousRow.alignment = .center
        continuousRow.distribution = .equalSpacing
        contentStack.addArrangedSubview(continuousRow)

        // Reset Button
        let resetButton = UIButton(type: .system)
        resetButton.setTitle("Reset to Defaults", for: .normal)
        resetButton.setTitleColor(.systemRed, for: .normal)
        resetButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        resetButton.addTarget(self, action: #selector(resetToDefaults), for: .touchUpInside)
        contentStack.addArrangedSubview(resetButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }

    private func createLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .label
        return label
    }

    private func createSettingRow(label: UILabel, control: UIView) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: [label, control])
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }

    private func createSliderRow(label: String, valueLabel: UILabel, slider: UISlider) -> UIStackView {
        let titleLabel = createLabel(label)
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        valueLabel.textColor = .secondaryLabel

        let headerStack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        headerStack.axis = .horizontal
        headerStack.distribution = .equalSpacing

        let stack = UIStackView(arrangedSubviews: [headerStack, slider])
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }

    @objc private func blurChanged() {
        blurValueLabel.text = String(format: "%.0f", blurSlider.value)
        notifyDelegate()
    }

    @objc private func cornerRadiusChanged() {
        cornerRadiusValueLabel.text = String(format: "%.0f", cornerRadiusSlider.value)
        notifyDelegate()
    }

    @objc private func refractionChanged() {
        refractionValueLabel.text = String(format: "%.2f", refractionSlider.value)
        notifyDelegate()
    }

    @objc private func fresnelChanged() {
        fresnelValueLabel.text = String(format: "%.1f", fresnelSlider.value)
        notifyDelegate()
    }

    @objc private func settingsChanged() {
        notifyDelegate()
    }

    private func notifyDelegate() {
        delegate?.settingsDidChange(
            blurRadius: blurSlider.value,
            cornerRadius: cornerRadiusSlider.value,
            refractionFactor: refractionSlider.value,
            fresnelFactor: fresnelSlider.value,
            tintColorIndex: tintSegment.selectedSegmentIndex,
            continuousUpdate: continuousToggle.isOn
        )
    }

    @objc private func resetToDefaults() {
        blurSlider.value = 10.0
        blurValueLabel.text = "10"
        cornerRadiusSlider.value = 40.0
        cornerRadiusValueLabel.text = "40"
        refractionSlider.value = 1.42
        refractionValueLabel.text = "1.42"
        fresnelSlider.value = 1.0
        fresnelValueLabel.text = "1.0"
        tintSegment.selectedSegmentIndex = 0
        continuousToggle.isOn = false

        delegate?.settingsDidReset()
    }
}
