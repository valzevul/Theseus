import UIKit
import QuartzCore

/// Handles pan gestures and applies morphing deformations to a TheseusView.
public final class TheseusGestureDeformer {

    public var onDragBegan: (() -> Void)?

    public var onDragEnded: ((_ velocity: CGPoint) -> Void)?

    public var positionProvider: ((_ translation: CGPoint, _ center: CGPoint, _ bounds: CGRect) -> CGPoint?)?

    public var isMorphingEnabled: Bool = true
    public private(set) var isDragging: Bool = false

    public var targetView: TheseusView? {
        return internalTargetView
    }

    private weak var internalTargetView: TheseusView?
    private var panGestureRecognizer: UIPanGestureRecognizer?
    private var previousTouchLocation: CGPoint = .zero
    private var previousTouchTimestamp: CFTimeInterval = 0

    private var stretchAnimator: TheseusStretchAnimator?

    public init(targetView: TheseusView) {
        self.internalTargetView = targetView
        configureStretchAnimator()
        configureGestureRecognizer()
    }

    deinit {
        stretchAnimator?.cancelAnimation()
        cleanupGesture()
    }

    private func configureStretchAnimator() {
        guard let morphConfig = internalTargetView?.morph else { return }

        var animatorConfig = TheseusStretchConfiguration()
        animatorConfig.sizeFactor = morphConfig.sizeFactor
        animatorConfig.tension = morphConfig.tension
        animatorConfig.friction = morphConfig.friction
        animatorConfig.squishFactor = morphConfig.squish

        let animator = TheseusStretchAnimator(configuration: animatorConfig)
        animator.stretchDidChange = { [weak self] stretch in
            self?.internalTargetView?.setMorphScale(stretch)
        }
        self.stretchAnimator = animator
    }

    private func configureGestureRecognizer() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        internalTargetView?.addGestureRecognizer(pan)
        panGestureRecognizer = pan
    }

    private func cleanupGesture() {
        guard let gesture = panGestureRecognizer else { return }
        gesture.view?.removeGestureRecognizer(gesture)
        panGestureRecognizer = nil
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let targetView = internalTargetView,
              let superview = targetView.superview else { return }

        let translation = gesture.translation(in: superview)
        let currentTime = CACurrentMediaTime()

        switch gesture.state {
        case .began:
            handleGestureBegan(gesture: gesture, in: superview, at: currentTime)

        case .changed:
            handleGestureChanged(
                gesture: gesture,
                translation: translation,
                targetView: targetView,
                superview: superview,
                currentTime: currentTime
            )

        case .ended, .cancelled:
            handleGestureEnded(gesture: gesture, in: superview)

        default:
            break
        }

        gesture.setTranslation(.zero, in: superview)
    }

    private func handleGestureBegan(gesture: UIPanGestureRecognizer, in superview: UIView, at currentTime: CFTimeInterval) {
        previousTouchLocation = gesture.location(in: superview)
        previousTouchTimestamp = currentTime
        isDragging = true

        internalTargetView?.continuousUpdate = true

        stretchAnimator?.beginInteraction()

        if isMorphingEnabled {
            let velocity = gesture.velocity(in: superview)
            stretchAnimator?.applyDragVelocity(velocity)
        }

        onDragBegan?()
    }

    private func handleGestureChanged(
        gesture: UIPanGestureRecognizer,
        translation: CGPoint,
        targetView: TheseusView,
        superview: UIView,
        currentTime: CFTimeInterval
    ) {
        let currentPosition = gesture.location(in: superview)
        let timeDelta = currentTime - previousTouchTimestamp

        let minTimeDelta: CFTimeInterval = 1.0 / 120.0

        if timeDelta > minTimeDelta && isMorphingEnabled {
            let velocity = CGPoint(
                x: (currentPosition.x - previousTouchLocation.x) / timeDelta,
                y: (currentPosition.y - previousTouchLocation.y) / timeDelta
            )
            stretchAnimator?.applyDragVelocity(velocity)
        }

        previousTouchLocation = currentPosition
        previousTouchTimestamp = currentTime

        if let newCenter = positionProvider?(translation, targetView.center, superview.bounds) {
            targetView.center = newCenter
        }
    }

    private func handleGestureEnded(gesture: UIPanGestureRecognizer, in superview: UIView) {
        isDragging = false

        internalTargetView?.continuousUpdate = false

        stretchAnimator?.endInteraction()
        onDragEnded?(gesture.velocity(in: superview))
    }

    public func clearDeformation() {
        stretchAnimator?.resetToNeutral()
    }

    public func disconnect() {
        stretchAnimator?.cancelAnimation()
        cleanupGesture()
        internalTargetView = nil
    }
}
