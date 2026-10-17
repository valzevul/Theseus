import Metal
import UIKit

final class MetalContext {

    static let shared: MetalContext? = {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("MetalContext: cannot MTLCreateSystemDefaultDevice")
            return nil
        }
        return MetalContext(device: device)
    }()

    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let library: MTLLibrary

    private(set) var horizontalBlurPipelineState: MTLRenderPipelineState!
    private(set) var verticalBlurPipelineState: MTLRenderPipelineState!
    private(set) var refractionCompositePipelineState: MTLRenderPipelineState!

    private(set) var quadVertexBuffer: MTLBuffer!

    let recommendedQuality: QualityLevel

    let eventListener: MTLSharedEventListener
    private let eventNotificationQueue: DispatchQueue

    static func prewarm() {
        _ = prewarmOnce
    }

    private static let prewarmOnce: Void = {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = MetalContext.shared
        }
    }()

    private init?(device: MTLDevice) {
        self.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = commandQueue

        guard let library = MetalContext.loadMetalLibrary(device: device) else {
            print("MetalContext: cannot load Metal library")
            return nil
        }
        self.library = library

        self.recommendedQuality = Self.detectQualityLevel(device: device)

        self.eventNotificationQueue = DispatchQueue(
            label: "com.theseus.sync",
            qos: .userInitiated
        )
        self.eventListener = MTLSharedEventListener(
            dispatchQueue: self.eventNotificationQueue
        )

        do {
            try setupPipelineStates()
            setupQuadVertexBuffer()
        } catch {
            print("MetalContext: Failed to setup pipeline states: \(error)")
            return nil
        }
    }

    private static func loadMetalLibrary(device: MTLDevice) -> MTLLibrary? {
        let bundle = Bundle.module

        if let libraryURL = bundle.url(forResource: "default", withExtension: "metallib") {
            do {
                return try device.makeLibrary(URL: libraryURL)
            } catch {
                print("MetalContext: Failed to load metallib from URL: \(error)")
            }
        }

        do {
            return try device.makeDefaultLibrary(bundle: bundle)
        } catch {
            print("MetalContext: Failed to make default library from bundle: \(error)")
        }

        if let resourcePath = bundle.resourcePath {
            let fileManager = FileManager.default
            if let enumerator = fileManager.enumerator(atPath: resourcePath) {
                while let filename = enumerator.nextObject() as? String {
                    if filename.hasSuffix(".metallib") {
                        let fullPath = (resourcePath as NSString).appendingPathComponent(filename)
                        do {
                            return try device.makeLibrary(filepath: fullPath)
                        } catch {
                            print("MetalContext: Failed to load metallib at \(fullPath): \(error)")
                        }
                    }
                }
            }
        }

        return nil
    }

    private func setupPipelineStates() throws {
        let vertexFunction = library.makeFunction(name: "vertexPassthrough")
        let horizontalBlurFunction = library.makeFunction(name: "gaussianBlurHorizontal")
        let verticalBlurFunction = library.makeFunction(name: "gaussianBlurVertical")

        let blurPipelineDescriptor = MTLRenderPipelineDescriptor()
        blurPipelineDescriptor.vertexFunction = vertexFunction
        blurPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        blurPipelineDescriptor.fragmentFunction = horizontalBlurFunction
        horizontalBlurPipelineState = try device.makeRenderPipelineState(descriptor: blurPipelineDescriptor)

        blurPipelineDescriptor.fragmentFunction = verticalBlurFunction
        verticalBlurPipelineState = try device.makeRenderPipelineState(descriptor: blurPipelineDescriptor)

        let refractionCompositeFunction = library.makeFunction(name: "glassRenderFragment")

        let refractionPipelineDescriptor = MTLRenderPipelineDescriptor()
        refractionPipelineDescriptor.vertexFunction = vertexFunction
        refractionPipelineDescriptor.fragmentFunction = refractionCompositeFunction
        refractionPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        refractionPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        refractionPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        refractionPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        refractionPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        // Alpha accumulates as coverage (a, not a^2): with .sourceAlpha the drawable's
        // alpha understates coverage and Core Animation adds background on top.
        refractionPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        refractionPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        refractionPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        refractionCompositePipelineState = try device.makeRenderPipelineState(descriptor: refractionPipelineDescriptor)
    }

    private func setupQuadVertexBuffer() {
        let vertices: [QuadVertex] = [
            QuadVertex(position: SIMD2<Float>(-1, -1), texCoord: SIMD2<Float>(0, 1)),
            QuadVertex(position: SIMD2<Float>( 1, -1), texCoord: SIMD2<Float>(1, 1)),
            QuadVertex(position: SIMD2<Float>(-1,  1), texCoord: SIMD2<Float>(0, 0)),
            QuadVertex(position: SIMD2<Float>( 1,  1), texCoord: SIMD2<Float>(1, 0)),
        ]

        quadVertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<QuadVertex>.stride * vertices.count,
            options: .storageModeShared
        )
    }

    private static func detectQualityLevel(device: MTLDevice) -> QualityLevel {
        if device.supportsFamily(.apple7) {
            return .ultra  // A14 Bionic and later (iPhone 12+)
        } else if device.supportsFamily(.apple5) {
            return .high   // A12 Bionic and later (iPhone XS+)
        } else if device.supportsFamily(.apple4) {
            return .medium // A11 (iPhone 8/X)
        } else if device.supportsFamily(.apple3) {
            return .medium // A9/A10 (iPhone 6s/7)
        }
        return .high
    }
}
