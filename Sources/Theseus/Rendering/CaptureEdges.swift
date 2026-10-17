import UIKit

/// Spreads a capture's edge pixels over the part of its region outside the
/// source view or the screen, so refraction there never reads transparent black.
enum CaptureEdges {
    static func visibleBounds(of sourceView: UIView) -> CGRect {
        var bounds = sourceView.bounds
        if let window = sourceView.window {
            bounds = bounds.intersection(window.convert(window.bounds, to: sourceView))
        }
        return bounds
    }

    static func extend(
        _ data: UnsafeMutableRawPointer,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        region: CGRect,
        visible: CGRect,
        scale: CGFloat
    ) {
        let covered = region.intersection(visible)
        guard !covered.isNull, covered.width > 0, covered.height > 0 else { return }
        let x0 = min(max(Int(ceil((covered.minX - region.minX) * scale)), 0), width - 1)
        let x1 = min(max(Int(floor((covered.maxX - region.minX) * scale)), x0 + 1), width)
        let y0 = min(max(Int(ceil((covered.minY - region.minY) * scale)), 0), height - 1)
        let y1 = min(max(Int(floor((covered.maxY - region.minY) * scale)), y0 + 1), height)
        guard x0 > 0 || y0 > 0 || x1 < width || y1 < height else { return }
        let pixels = data.assumingMemoryBound(to: UInt32.self)
        let rowPixels = bytesPerRow / 4
        for row in y0..<y1 {
            let base = row * rowPixels
            if x0 > 0 {
                let edge = pixels[base + x0]
                for column in 0..<x0 {
                    pixels[base + column] = edge
                }
            }
            if x1 < width {
                let edge = pixels[base + x1 - 1]
                for column in x1..<width {
                    pixels[base + column] = edge
                }
            }
        }
        for row in 0..<y0 {
            memcpy(data + row * bytesPerRow, data + y0 * bytesPerRow, width * 4)
        }
        for row in y1..<height {
            memcpy(data + row * bytesPerRow, data + (y1 - 1) * bytesPerRow, width * 4)
        }
    }
}
