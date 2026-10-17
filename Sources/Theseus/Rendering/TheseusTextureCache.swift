import Metal
import Foundation

final class TexturePool {

    private let device: MTLDevice
    private var availableTextures: [TextureDimensions: [MTLTexture]] = [:]
    private let lock = NSLock()
    private let maxPooledPerDimension = 5

    struct TextureDimensions: Hashable {
        let width: Int
        let height: Int
        let format: MTLPixelFormat
        let mipmapped: Bool
    }

    init(device: MTLDevice) {
        self.device = device
    }

    func checkout(width: Int, height: Int, format: MTLPixelFormat = .bgra8Unorm, mipmapped: Bool = false) -> MTLTexture? {
        lock.lock()
        defer { lock.unlock() }

        let dims = TextureDimensions(width: width, height: height, format: format, mipmapped: mipmapped)

        if var pooled = availableTextures[dims], !pooled.isEmpty {
            let texture = pooled.removeLast()
            availableTextures[dims] = pooled
            return texture
        }

        return createTexture(dimensions: dims)
    }

    func checkin(_ texture: MTLTexture) {
        lock.lock()
        defer { lock.unlock() }

        let dims = TextureDimensions(
            width: texture.width,
            height: texture.height,
            format: texture.pixelFormat,
            mipmapped: texture.mipmapLevelCount > 1
        )

        guard (availableTextures[dims]?.count ?? 0) < maxPooledPerDimension else {
            return
        }

        availableTextures[dims, default: []].append(texture)
    }

    func drain() {
        lock.lock()
        defer { lock.unlock() }
        availableTextures.removeAll()
    }

    func trimExcess() {
        lock.lock()
        defer { lock.unlock() }

        for dims in availableTextures.keys {
            if let textures = availableTextures[dims], textures.count > 1 {
                availableTextures[dims] = Array(textures.suffix(1))
            }
        }
    }

    private func createTexture(dimensions dims: TextureDimensions) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: dims.format,
            width: dims.width,
            height: dims.height,
            mipmapped: dims.mipmapped
        )

        descriptor.storageMode = .private
        descriptor.usage = dims.mipmapped ? [.renderTarget, .shaderRead, .pixelFormatView] : [.renderTarget, .shaderRead]

        return device.makeTexture(descriptor: descriptor)
    }

}
