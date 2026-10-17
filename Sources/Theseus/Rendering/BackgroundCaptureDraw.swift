import Metal
import UIKit

/// Captures with `layer.render(in:)` into a reused bitmap, copied into one of
/// three textures so a frame still on the GPU never sees the next one's pixels.
final class BackgroundCaptureDraw {

    private let device: MTLDevice
    private var context: CGContext?
    private var textures: [MTLTexture] = []
    private var textureIndex = 0
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    init(device: MTLDevice) {
        self.device = device
    }

    deinit {
        invalidate()
    }

    func captureTexture(
        from sourceView: UIView,
        region: CGRect,
        scale: CGFloat = 1.0,
        excludedViews: [UIView] = []
    ) -> (texture: MTLTexture, meanColor: CaptureColor)? {
        let hiddenStates = excludedViews.map { $0.isHidden }
        excludedViews.forEach { $0.isHidden = true }

        // Must follow the exclusion hiding above so excluded subtrees are skipped.
        let compensation = CaptureCompensation.begin(in: sourceView)

        defer {
            CaptureCompensation.end(compensation)
            for (view, wasHidden) in zip(excludedViews, hiddenStates) {
                view.isHidden = wasHidden
            }
        }

        let screenScale = sourceView.window?.screen.scale ?? UIScreen.main.scale
        let effectiveScale = screenScale * scale
        let width = Int(ceil(region.width * effectiveScale - 0.001))
        let height = Int(ceil(region.height * effectiveScale - 0.001))
        guard width > 0, height > 0 else { return nil }

        if context?.width != width || context?.height != height {
            context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
            )
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            descriptor.usage = .shaderRead
            descriptor.storageMode = .shared
            textures = (0..<3).compactMap { _ in device.makeTexture(descriptor: descriptor) }
        }
        guard let ctx = context, let data = ctx.data, textures.count == 3 else { return nil }

        ctx.saveGState()
        ctx.clear(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: effectiveScale, y: -effectiveScale)
        ctx.translateBy(x: -region.origin.x, y: -region.origin.y)

        // layer.render(in:), not drawHierarchy: drawHierarchy snapshots the screen,
        // including this glass's own last frame, and feeds the glass back into itself.
        UIGraphicsPushContext(ctx)
        sourceView.layer.render(in: ctx)
        UIGraphicsPopContext()
        ctx.restoreGState()
        CaptureEdges.extend(
            data,
            width: width,
            height: height,
            bytesPerRow: ctx.bytesPerRow,
            region: region,
            visible: CaptureEdges.visibleBounds(of: sourceView),
            scale: effectiveScale
        )

        textureIndex = (textureIndex + 1) % 3
        let texture = textures[textureIndex]
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: data, bytesPerRow: ctx.bytesPerRow)
        return (texture, Self.meanColor(of: data, width: width, height: height, bytesPerRow: ctx.bytesPerRow))
    }

    /// Premultiplied average over a 16 x 16 grid of samples.
    private static func meanColor(of data: UnsafeMutableRawPointer, width: Int, height: Int, bytesPerRow: Int) -> CaptureColor {
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        var red = 0, green = 0, blue = 0, count = 0
        for row in 0..<16 {
            let y = min(height - 1, (row * 2 + 1) * height / 32)
            for column in 0..<16 {
                let x = min(width - 1, (column * 2 + 1) * width / 32)
                let offset = y * bytesPerRow + x * 4
                blue += Int(pixels[offset])
                green += Int(pixels[offset + 1])
                red += Int(pixels[offset + 2])
                count += 1
            }
        }
        let scale = CGFloat(count) * 255
        return CaptureColor(red: CGFloat(red) / scale, green: CGFloat(green) / scale, blue: CGFloat(blue) / scale)
    }

    func invalidate() {
        context = nil
        textures = []
    }
}
