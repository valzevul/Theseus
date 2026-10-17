import UIKit

/// `layer.render(in:)` draws `UIVisualEffectView` blur as transparent. During a
/// capture each visible effect view wears a flat veil; the swap never reaches a commit.
enum CaptureCompensation {

    /// Flat stand-ins for the system materials, matched to the live bar.
    static let lightVeil = UIColor(white: 0.97, alpha: 0.75)
    static let darkVeil = UIColor(white: 0.20, alpha: 0.75)

    struct Entry {
        let view: UIView
        let originalColor: UIColor?
        let metalHost: UIView?
        let metalHostWasHidden: Bool
        let imageView: UIImageView?
        let originalImage: UIImage?
        var snapshotLayer: CALayer? = nil
    }

    /// Call immediately ahead of `layer.render(in:)` and always pair with `end`.
    static func begin(in root: UIView) -> [Entry] {
        var entries: [Entry] = []
        apply(to: root, entries: &entries)
        return entries
    }

    static func end(_ entries: [Entry]) {
        for entry in entries {
            if let imageView = entry.imageView {
                imageView.image = entry.originalImage
                continue
            }
            entry.view.backgroundColor = entry.originalColor
            if let host = entry.metalHost {
                host.isHidden = entry.metalHostWasHidden
            }
            entry.snapshotLayer?.removeFromSuperlayer()
        }
    }

    private static func apply(to view: UIView, entries: inout [Entry]) {
        guard !view.isHidden, view.alpha > 0.01 else { return }

        if let effectView = view as? UIVisualEffectView, effectView.effect != nil {
            entries.append(Entry(
                view: effectView,
                originalColor: effectView.backgroundColor,
                metalHost: nil,
                metalHostWasHidden: false,
                imageView: nil,
                originalImage: nil
            ))
            let isDark = effectView.traitCollection.userInterfaceStyle == .dark
            effectView.backgroundColor = isDark ? Self.darkVeil : Self.lightVeil
        }

        // `layer.render` cannot read a CAMetalLayer, so the host is hidden and
        // a veil (or the glass's own snapshot) stands in.
        if let glass = view as? TheseusView, let host = glass.captureMetalHost {
            var entry = Entry(
                view: glass,
                originalColor: glass.backgroundColor,
                metalHost: host,
                metalHostWasHidden: host.isHidden,
                imageView: nil,
                originalImage: nil
            )
            host.isHidden = true
            if let snapshot = glass.captureSnapshot, !entry.metalHostWasHidden {
                let layer = CALayer()
                layer.contents = glass.captureSnapshotOverride?.image ?? snapshot
                layer.contentsGravity = .resize
                layer.frame = glass.captureSnapshotOverride?.frame ?? glass.captureSnapshotFrame
                glass.layer.addSublayer(layer)
                entry.snapshotLayer = layer
            } else {
                glass.backgroundColor = glass.captureVeilColor
            }
            entries.append(entry)
        }

        // `layer.render(in:)` applies template tints at display time, not into
        // `layer.contents`, so a pre-tinted `.alwaysOriginal` bitmap stands in.
        if #available(iOS 13.0, *),
           let imageView = view as? UIImageView,
           let image = imageView.image,
           image.renderingMode == .alwaysTemplate {
            entries.append(Entry(
                view: imageView,
                originalColor: nil,
                metalHost: nil,
                metalHostWasHidden: false,
                imageView: imageView,
                originalImage: image
            ))
            imageView.image = image.withTintColor(
                imageView.tintColor ?? .black, renderingMode: .alwaysOriginal)
        }

        for subview in view.subviews {
            apply(to: subview, entries: &entries)
        }
    }
}
