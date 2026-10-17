import UIKit

extension CGRect {
    /// Origin and size rounded to whole device pixels at `scale`.
    func pixelAligned(scale: CGFloat) -> CGRect {
        guard scale > 0 else { return self }
        let x = (origin.x * scale).rounded() / scale
        let y = (origin.y * scale).rounded() / scale
        let w = (size.width * scale).rounded() / scale
        let h = (size.height * scale).rounded() / scale
        return CGRect(x: x, y: y, width: w, height: h)
    }
}
