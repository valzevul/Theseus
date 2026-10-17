import Metal
import MetalKit
import UIKit
import IOSurface
import CoreVideo

struct CaptureResult {
    let texture: MTLTexture
    let surface: IOSurface
    let meanColor: CaptureColor
}

struct CaptureColor: Equatable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat

    var luminance: CGFloat { 0.2126 * red + 0.7152 * green + 0.0722 * blue }

    static func grey(_ value: CGFloat) -> CaptureColor {
        CaptureColor(red: value, green: value, blue: value)
    }
}

enum CaptureStatistics {
    static func meanColor(of image: CGImage) -> CaptureColor {
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return .grey(0.5) }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return CaptureColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255, blue: CGFloat(pixel[2]) / 255)
    }
}

private final class SurfacePool {
    private var cache: [SurfaceDimensions: [IOSurface]] = [:]
    private let lock = NSLock()
    private let maxSurfacesPerSize = 5

    struct SurfaceDimensions: Hashable {
        let width: Int
        let height: Int
    }

    func requestSurface(dimensions: SurfaceDimensions) -> IOSurface? {
        lock.lock()
        defer { lock.unlock() }

        if var available = cache[dimensions], !available.isEmpty {
            let surface = available.removeLast()
            cache[dimensions] = available
            return surface
        }

        return makeSurface(dimensions: dimensions)
    }

    func returnSurface(_ surface: IOSurface) {
        lock.lock()
        defer { lock.unlock() }

        let dims = SurfaceDimensions(
            width: IOSurfaceGetWidth(surface),
            height: IOSurfaceGetHeight(surface)
        )

        guard (cache[dims]?.count ?? 0) < maxSurfacesPerSize else {
            return
        }

        cache[dims, default: []].append(surface)
    }

    func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }

    private func makeSurface(dimensions: SurfaceDimensions) -> IOSurface? {
        // Metal wants 16-byte row alignment
        let rowAlignment = 16
        let bytesPerPixel = 4
        let bytesPerRow = ((dimensions.width * bytesPerPixel) + rowAlignment - 1) & ~(rowAlignment - 1)

        let props: [IOSurfacePropertyKey: Any] = [
            .width: dimensions.width,
            .height: dimensions.height,
            .bytesPerElement: bytesPerPixel,
            .bytesPerRow: bytesPerRow,
            .allocSize: bytesPerRow * dimensions.height,
            .pixelFormat: kCVPixelFormatType_32BGRA
        ]
        return IOSurfaceCreate(props as CFDictionary)
    }
}

final class ViewLayerCapture {

    private let device: MTLDevice
    private let surfacePool = SurfacePool()

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
    ) -> CaptureResult? {
        let previousVisibility = excludedViews.map { $0.isHidden }
        excludedViews.forEach { $0.isHidden = true }

        // Must follow the exclusion hiding above so excluded subtrees are skipped.
        let compensation = CaptureCompensation.begin(in: sourceView)

        defer {
            CaptureCompensation.end(compensation)
            for (view, wasHidden) in zip(excludedViews, previousVisibility) {
                view.isHidden = wasHidden
            }
        }

        let screenScale = sourceView.window?.screen.scale ?? UIScreen.main.scale
        let renderScale = screenScale * scale

        guard region.width > 0 && region.height > 0 else { return nil }

        let pixelWidth = Int(ceil(region.width * renderScale - 0.001))
        let pixelHeight = Int(ceil(region.height * renderScale - 0.001))

        guard pixelWidth > 0 && pixelHeight > 0 else { return nil }

        let dims = SurfacePool.SurfaceDimensions(width: pixelWidth, height: pixelHeight)
        guard let surface = surfacePool.requestSurface(dimensions: dims) else {
            return nil
        }

        guard IOSurfaceLock(surface, [], nil) == 0 else {
            surfacePool.returnSurface(surface)
            return nil
        }

        defer {
            IOSurfaceUnlock(surface, [], nil)
        }

        let bytesPerRow = IOSurfaceGetBytesPerRow(surface)
        let baseAddress = IOSurfaceGetBaseAddress(surface)

        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let ctx = CGContext(
            data: baseAddress,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else {
            surfacePool.returnSurface(surface)
            return nil
        }

        ctx.clear(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        ctx.translateBy(x: 0, y: CGFloat(pixelHeight))
        ctx.scaleBy(x: renderScale, y: -renderScale)
        ctx.translateBy(x: -region.origin.x, y: -region.origin.y)

        sourceView.layer.render(in: ctx)
        CaptureEdges.extend(
            baseAddress,
            width: pixelWidth,
            height: pixelHeight,
            bytesPerRow: bytesPerRow,
            region: region,
            visible: CaptureEdges.visibleBounds(of: sourceView),
            scale: renderScale
        )
        let meanColor = ctx.makeImage().map(CaptureStatistics.meanColor(of:)) ?? .grey(0.5)

        let texDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: pixelWidth,
            height: pixelHeight,
            mipmapped: false
        )
        texDesc.usage = [.shaderRead]
        texDesc.storageMode = .shared

        guard let texture = device.makeTexture(
            descriptor: texDesc,
            iosurface: surface,
            plane: 0
        ) else {
            surfacePool.returnSurface(surface)
            return nil
        }

        return CaptureResult(texture: texture, surface: surface, meanColor: meanColor)
    }

    func recycleSurface(_ surface: IOSurface) {
        surfacePool.returnSurface(surface)
    }

    func invalidate() {
        surfacePool.clearCache()
    }
}
