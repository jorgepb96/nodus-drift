// SPDX-License-Identifier: MIT
import SwiftUI
import MetalKit
import ImageIO

struct StudioLandscapeSurface: UIViewRepresentable {
    let state: StudioVisualState
    let animated: Bool
    var framesPerSecond = 30

    func makeUIView(context: Context) -> LandscapeHostView { LandscapeHostView() }
    func updateUIView(_ view: LandscapeHostView, context: Context) { view.update(state: state, animated: animated, framesPerSecond: framesPerSecond) }
    static func dismantleUIView(_ view: LandscapeHostView, coordinator: ()) { view.stop() }
}

/// A native photograph remains visible while Metal is loading or unavailable.
final class LandscapeHostView: UIView {
    private let still = UIImageView()
    private var metal: MTKView?
    private var renderer: StudioLandscapeRenderer?
    private var plate: StudioLandscapePlate?
    private var latestState: StudioVisualState?
    private var requestedAnimation = false
    private var gpuFailed = false
    private var frameRate = 30
    #if DEBUG
    var renderedFrames: Int { renderer?.renderedFrames ?? 0 }
    var animationTime: Double { renderer?.animationTime ?? 0 }
    private(set) var displayedPlate: StudioLandscapePlate?
    #endif

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(DriftTheme.background)
        isUserInteractionEnabled = false
        clipsToBounds = true
        still.contentMode = .scaleAspectFill; still.clipsToBounds = true
        still.accessibilityIgnoresInvertColors = true
        addSubview(still)
        if let device = MTLCreateSystemDefaultDevice() {
            let surface = MTKView(frame: .zero, device: device)
            surface.colorPixelFormat = .bgra8Unorm_srgb
            surface.framebufferOnly = true
            surface.isPaused = true; surface.enableSetNeedsDisplay = true
            surface.preferredFramesPerSecond = 30
            surface.autoResizeDrawable = false
            surface.isOpaque = true
            surface.accessibilityIgnoresInvertColors = true
            (surface.layer as? CAMetalLayer)?.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
            surface.clearColor = MTLClearColor(red: 0.03, green: 0.06, blue: 0.07, alpha: 1)
            surface.isHidden = false
            if let renderer = try? StudioLandscapeRenderer(device: device) {
                self.renderer = renderer; metal = surface
                renderer.didPresentFrame = { [weak self] presented in
                    guard let self, self.plate == presented else { return }
                    self.still.isHidden = true
                    #if DEBUG
                    self.displayedPlate = presented
                    #endif
                }
                renderer.didFail = { [weak self] in
                    guard let self else { return }
                    self.gpuFailed = true; self.metal?.isPaused = true
                    self.metal?.isHidden = true; self.still.isHidden = false; self.renderer?.suspend()
                }
                surface.delegate = renderer
                insertSubview(surface, belowSubview: still)
            }
        }
        accessibilityIdentifier = "studio-photographic-landscape"
        isAccessibilityElement = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        still.frame = bounds; metal?.frame = bounds
        defer { applyVisibility() }
        guard let metal, bounds.width > 0, bounds.height > 0 else { return }
        // Cap fill-rate instead of continuously rendering full iPad display resolution.
        let scale = min(window?.screen.scale ?? UIScreen.main.scale, 2048 / max(bounds.width, bounds.height))
        let size = CGSize(width: max(1, (bounds.width * scale).rounded()), height: max(1, (bounds.height * scale).rounded()))
        if metal.drawableSize != size { metal.drawableSize = size }
    }
    override func didMoveToWindow() { super.didMoveToWindow(); applyVisibility() }
    func update(state: StudioVisualState, animated: Bool, framesPerSecond: Int = 30) {
        latestState = state; requestedAnimation = animated; frameRate = framesPerSecond
        // This also makes the no-Metal fallback respond to daylight controls.
        still.alpha = CGFloat(0.65 + state.daylight * 0.35)
        applyVisibility()
    }
    private func applyVisibility() {
        guard let latestState else { return }
        let next = StudioLandscapePlate(landscape: latestState.landscape, size: bounds.size)
        if plate != next {
            plate = next; still.isHidden = false
            if let url = next.photographURL { still.image = Self.downsample(url, maximum: 2048) }
        }
        guard !gpuFailed else { return }
        let onScreen = window.map { convert(bounds, to: $0).intersects($0.bounds) && !bounds.isEmpty } ?? false
        metal?.preferredFramesPerSecond = frameRate
        renderer?.update(state: latestState, animated: requestedAnimation && onScreen, view: metal)
    }
    func stop() {
        metal?.isPaused = true
        renderer?.suspend()
    }
    static func downsample(_ url: URL, maximum: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maximum,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
}

/// SIMD4-only layout is shared with StudioLandscapeShaders.metal (16-byte alignment).
struct StudioLandscapeUniforms {
    var viewport: SIMD4<Float>   // width, height, source aspect, animation time
    var weather: SIMD4<Float>    // rain, wind, fog, fire
    var lighting: SIMD4<Float>   // daylight, stars, tint, lightning
    var scene: SIMD4<Float>      // landscape index, seed, effect flags, actor count
    var composition: SIMD4<Float> // focal point y, horizontal artwork flag, reserved
    var aperture: SIMD4<Float>    // horizontal exterior glass bounds
    var hearth: SIMD4<Float>      // flame base x/y and half-width/height
}

struct StudioActorUniforms {
    var rect: SIMD4<Float>
    var source: SIMD4<Float>
    var behavior: SIMD4<Float> // atlas, opacity, animation kind, seed
}

final class StudioLandscapeRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let pipeline: MTLRenderPipelineState
    let queue: MTLCommandQueue
    let sprites: [MTLTexture]
    private static let spriteCache = NSCache<NSString, AnyObject>()
    var didPresentFrame: ((StudioLandscapePlate) -> Void)?
    var didFail: (() -> Void)?
    #if DEBUG
    private var completedFrames = 0
    var renderedFrames: Int { lock.lock(); defer { lock.unlock() }; return completedFrames }
    var animationTime: Double { lock.lock(); defer { lock.unlock() }; return elapsed }
    #endif
    private let lock = NSLock()
    private var state: StudioVisualState?
    private var current: StudioLandscapePlate?
    private var textureRevision: UInt64 = 0
    private var presentedRevision: UInt64?
    private var texture: MTLTexture?
    private var animated = false
    private var elapsed: Double = 0
    private var lastFrame: Double?
    private var inFlight = DispatchSemaphore(value: 2)
    private static let textures = NSCache<NSString, AnyObject>()

    init(device: MTLDevice) throws {
        self.device = device
        guard let queue = device.makeCommandQueue() else { throw StudioError.invalid("Metal command queue unavailable") }
        self.queue = queue
        sprites = try (StudioVisualPolicy.decorativeActorsEnabled ? ["animals", "props"] : []).map { name in
            let key = "\(device.registryID)-\(name)" as NSString
            if let cached = Self.spriteCache.object(forKey: key) as? MTLTexture { return cached }
            guard let url = Bundle.main.resourceURL?.appendingPathComponent("Landscapes/\(name).png") else { throw StudioError.invalid("Scene artwork unavailable") }
            let value = try MTKTextureLoader(device: device).newTexture(URL: url, options: [.SRGB: true, .generateMipmaps: false])
            Self.spriteCache.countLimit = 2
            Self.spriteCache.setObject(value as AnyObject, forKey: key)
            return value
        }
        let library = try device.makeDefaultLibrary(bundle: .main)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "driftLandscapeVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "driftLandscapeFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        super.init()
        Self.textures.totalCostLimit = 48 * 1024 * 1024
        Self.textures.countLimit = 2
    }

    func update(state: StudioVisualState, animated: Bool, view: MTKView?) {
        lock.lock()
        let changed = self.state != state
        self.state = state; self.animated = animated
        if !animated { lastFrame = nil }
        let plate = StudioLandscapePlate(landscape: state.landscape, size: view?.bounds.size ?? .zero)
        let needsTexture = current != plate
        if needsTexture { current = plate; texture = nil; textureRevision &+= 1 }
        let revision = textureRevision
        lock.unlock()
        if needsTexture { load(plate, revision: revision, view: view) }
        // Switch drawing modes only when they change; changing them on every
        // SwiftUI/transport update can repeatedly reset MetalKit's internal loop.
        if view?.enableSetNeedsDisplay != !animated { view?.enableSetNeedsDisplay = !animated }
        if view?.isPaused != !animated { view?.isPaused = !animated }
        if !animated && (changed || needsTexture) { view?.setNeedsDisplay() }
    }
    func suspend() { lock.lock(); animated = false; lastFrame = nil; lock.unlock() }

    private func load(_ plate: StudioLandscapePlate, revision: UInt64, view: MTKView?) {
        let key = "\(device.registryID)-\(plate.assetName)" as NSString
        if let cached = Self.textures.object(forKey: key) as? MTLTexture {
            lock.lock(); texture = cached; lock.unlock()
            view?.setNeedsDisplay(); return
        }
        let device = device
        DispatchQueue.global(qos: .userInitiated).async { [weak self, weak view] in
            guard let self, let texture = try? Self.loadPhotograph(plate.landscape, wide: plate.wide, device: device) else { return }
            Self.textures.setObject(texture as AnyObject, forKey: key, cost: texture.width * texture.height * 4)
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self else { return }
                self.lock.lock()
                let expected = self.current == plate && self.textureRevision == revision
                if expected { self.texture = texture }
                self.lock.unlock()
                if expected { view?.setNeedsDisplay() }
            }
        }
    }
    /// File-aware loading preserves the JPEG's sRGB profile. The CGImage thumbnail
    /// route can produce a non-sRGB texture with incorrect channel interpretation.
    static func loadPhotograph(_ landscape: StudioLandscape, wide: Bool = false, device: MTLDevice) throws -> MTLTexture {
        guard let url = StudioLandscapePlate(landscape: landscape, wide: wide).photographURL else { throw StudioError.invalid("Landscape photograph is missing") }
        return try MTKTextureLoader(device: device).newTexture(URL: url, options: [.SRGB: true, .generateMipmaps: false])
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { if view.isPaused { view.setNeedsDisplay() } }

    func draw(in view: MTKView) {
        guard let window = view.window, view.convert(view.bounds, to: window).intersects(window.bounds) else { return }
        guard inFlight.wait(timeout: .now()) == .success else { return }
        lock.lock()
        let state = self.state, texture = self.texture, plate = self.current
        let revision = textureRevision
        let now = CACurrentMediaTime()
        if animated {
            if let previous = lastFrame { elapsed += min(0.1, max(0, now - previous)) }
            lastFrame = now
        }
        let time = elapsed
        lock.unlock()
        guard let state, let texture, let plate,
              let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable,
              let command = queue.makeCommandBuffer(), let encoder = command.makeRenderCommandEncoder(descriptor: pass) else {
            inFlight.signal(); return
        }
        encode(encoder, photograph: texture, state: state, size: view.drawableSize, time: time)
        encoder.endEncoding()
        let semaphore = inFlight
        command.addCompletedHandler { [weak self] result in
            semaphore.signal()
            guard let self else { return }
            if result.status == .completed {
                self.lock.lock()
                #if DEBUG
                self.completedFrames += 1
                #endif
                let first = self.textureRevision == revision && self.presentedRevision != revision
                if first { self.presentedRevision = revision }
                self.lock.unlock()
                if first {
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        self.lock.lock(); let current = self.textureRevision == revision; self.lock.unlock()
                        if current { self.didPresentFrame?(plate) }
                    }
                }
            }
            if result.status == .error { DispatchQueue.main.async { [weak self] in self?.didFail?() } }
        }
        command.present(drawable); command.commit()
    }

    static func uniforms(state: StudioVisualState, size: CGSize, texture: MTLTexture, time: Double) -> StudioLandscapeUniforms {
        let plate = StudioLandscapePlate(landscape: state.landscape, wide: texture.width > texture.height)
        return StudioLandscapeUniforms(
            viewport: SIMD4(Float(size.width), Float(size.height), Float(texture.width) / Float(texture.height), Float(time)),
            weather: SIMD4(state.rain, state.wind, state.fog, state.fire),
            lighting: SIMD4(state.daylight, state.stars, state.tint, state.lightning),
            scene: SIMD4(state.landscape.shaderIndex, state.seed, Float(state.effects), Float(state.actors.count)),
            composition: SIMD4(plate.wide ? 0.5 : state.focusY, plate.wide ? 1 : 0, 0, 0),
            aperture: plate.exteriorRect, hearth: plate.hearth
        )
    }
    func encode(_ encoder: MTLRenderCommandEncoder, photograph: MTLTexture, state: StudioVisualState, size: CGSize, time: Double) {
        var uniforms = Self.uniforms(state: state, size: size, texture: photograph, time: time)
        var actors = Self.actorUniforms(state: state, size: size, sourceAspect: Float(photograph.width) / Float(photograph.height))
        uniforms.scene.w = Float(actors.count)
        if actors.isEmpty { actors = [.init(rect: .zero, source: .zero, behavior: .zero)] }
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(photograph, index: 0)
        // Keep the shader's texture bindings valid without loading unused atlases.
        encoder.setFragmentTexture(sprites.first ?? photograph, index: 1)
        encoder.setFragmentTexture(sprites.last ?? photograph, index: 2)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<StudioLandscapeUniforms>.stride, index: 0)
        actors.withUnsafeBytes { bytes in encoder.setFragmentBytes(bytes.baseAddress!, length: bytes.count, index: 1) }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }
    static func actorUniforms(state: StudioVisualState, size: CGSize, sourceAspect: Float) -> [StudioActorUniforms] {
        guard StudioVisualPolicy.decorativeActorsEnabled else { return [] }
        let aspect = Float(size.width / max(1, size.height))
        let cropX = min(1, aspect / sourceAspect), cropY = min(1, sourceAspect / aspect)
        let centreY = min(1 - cropY / 2, max(cropY / 2, state.focusY))
        return state.actors.sorted { $0.y < $1.y }.enumerated().compactMap { index, actor in
            let source = StudioSpriteRegion.region(at: actor.tile, in: actor.atlas)
            let width = actor.width
            let height = width * sourceAspect / source.aspect
            let x = actor.x, y = actor.y
            // Cropping must not move an object from its surface onto a dashboard,
            // water, wall or sky. Objects outside the shot remain off-screen.
            guard x - width / 2 >= 0.5 - cropX / 2, x + width / 2 <= 0.5 + cropX / 2,
                  y - height >= centreY - cropY / 2, y <= centreY + cropY / 2 else { return nil }
            let motion: Float = actor.sourceID == "seagulls" || actor.sourceID == "whale" ? 1 : (actor.sourceID == "ceiling-fan" ? 3 : (actor.atlas == .animals ? 2 : 0))
            return StudioActorUniforms(rect: SIMD4(x - width / 2, y - height, width, height),
                         source: SIMD4(source.x, source.y, source.width, source.height),
                         behavior: SIMD4(actor.atlas == .animals ? 0 : 1, 1, motion, Float(index) + state.seed))
        }
    }
}
