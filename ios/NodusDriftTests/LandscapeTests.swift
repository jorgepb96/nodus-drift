import XCTest
import MetalKit
import SwiftUI
import ImageIO
@testable import NodusDrift

final class LandscapeTests: XCTestCase {
    @MainActor func testWindowCanAdoptLandscapeGeometry() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = try XCTUnwrap(scene.keyWindow)
        let controller = try XCTUnwrap(window.rootViewController)
        let before = "bounds=\(window.bounds), effective=\(scene.effectiveGeometry), app=\(UIApplication.shared.supportedInterfaceOrientations(for: window).rawValue), root=\(controller.supportedInterfaceOrientations.rawValue), autorotate=\(controller.shouldAutorotate)"
        print("ORIENTATION PROBE \(before)")
        defer { scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) }
        var failure: Error?
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeLeft)) { failure = $0 }
        try await Task.sleep(for: .seconds(2))
        let report = XCTAttachment(string: before + "\nafter=\(window.bounds), geometry=\(scene.effectiveGeometry), error=\(String(describing: failure))")
        report.name = "Window orientation geometry"; report.lifetime = .keepAlways; add(report)
        if let error = failure as NSError?, error.domain == "UISceneErrorDomain", error.code == 101 {
            throw XCTSkip("The current resizable windowing mode prohibits programmatic orientation; test its existing viewport instead")
        }
        XCTAssertNil(failure)
        XCTAssertGreaterThan(window.bounds.width, window.bounds.height)
    }
    func testEveryCataloguePairKeepsACompatibleCompositionWithoutChangingAudio() throws {
        let sounds = DriftCatalog.sounds
        var pairs = 0
        for i in sounds.indices {
            for j in sounds.indices where j > i {
                let input = [sounds[i], sounds[j]]
                let scene = MeditationComposition.scene(sounds: input, volumes: [:])
                try scene.validate(); pairs += 1
                XCTAssertEqual(scene.layers.compactMap(\.catalogID), input.map(\.id))
                XCTAssertEqual(scene.visuals, StudioVisualPolicy.resolve(scene.visuals))
                if scene.visuals.fire { XCTAssertEqual(scene.visuals.landscape, .cabin) }
                if scene.visuals.landscape == .car { XCTAssertTrue(scene.visuals.actors?.isEmpty == true) }
                if scene.visuals.landscape == .underwater { XCTAssertEqual(scene.visuals.rain, 0) }
                for effect in scene.visuals.effects ?? [] { XCTAssertTrue(StudioVisualPolicy.permits(effect, in: scene.visuals.landscape)) }
                for actor in scene.visuals.actors ?? [] { XCTAssertNotNil(StudioVisualPolicy.placement(for: actor, in: scene.visuals.landscape)) }
            }
        }
        XCTAssertEqual(pairs, 3916)
        let report = XCTAttachment(string: "All 3916 pairs of the 89 catalogue sounds preserve their audio and satisfy context, habitat, surface and effect compatibility.")
        report.name = "Catalogue pair audit"; report.lifetime = .keepAlways; add(report)
    }
    func testCarRejectsUmbrellaFireWildlifeAndWaterInLegacyAndCurrentScenes() throws {
        let ids = ["rain-on-car-roof", "rain-on-umbrella", "campfire", "wolf", "bubbles", "windshield-wipers"]
        var scene = MeditationComposition.scene(sounds: ids.compactMap(DriftCatalog.sound), volumes: [:])
        XCTAssertEqual(scene.visuals.landscape, .car)
        XCTAssertFalse(scene.visuals.fire); XCTAssertTrue(scene.visuals.actors?.isEmpty == true)
        XCTAssertTrue(scene.offscreenVisualSounds.isEmpty, "Simplified landscapes need no object-placement explanation")
        XCTAssertEqual(scene.layers.count, 6)
        // Old drafts and imports can still carry the invalid build-12 configuration.
        scene.visuals.fire = true
        scene.visuals.actors = [.init(sourceID: "rain-on-umbrella", atlas: .props, tile: 14, x: 0.5, y: 0.8, width: 0.48)]
        scene.visuals.effects = StudioVisualEffect.allCases
        let state = StudioVisualState(scene: scene, time: 10)
        XCTAssertEqual(state.fire, 0); XCTAssertTrue(state.actors.isEmpty)
        XCTAssertEqual(state.effects, StudioVisualEffect.wipers.mask | StudioVisualEffect.glassRain.mask)
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let renderer = try StudioLandscapeRenderer(device: device)
        let photo = try StudioLandscapeRenderer.loadPhotograph(.car, device: device)
        var forced = state; forced.fire = 1
        XCTAssertEqual(try render(renderer, source: photo, state: state, time: 1), try render(renderer, source: photo, state: forced, time: 1), "The shader must never draw a fire in a car, even with a malformed snapshot")
    }
    func testEveryBackgroundFiltersAllCatalogueActorsAndEffects() throws {
        let candidates = DriftCatalog.sounds.flatMap { MeditationComposition.scene(sounds: [$0], volumes: [:]).visuals.actors ?? [] }
        for landscape in StudioLandscape.allCases {
            let resolved = StudioVisualPolicy.resolve(StudioVisuals(landscape: landscape, fire: true, actors: candidates, effects: StudioVisualEffect.allCases))
            XCTAssertLessThanOrEqual(resolved.actors?.count ?? 0, 3)
            XCTAssertEqual(resolved.fire, landscape == .cabin)
            XCTAssertEqual(StudioVisualPolicy.resolve(resolved), resolved)
            var scene = StudioScene(name: "Compatibility sweep"); scene.visuals = resolved
            try scene.validate()
            let state = StudioVisualState(scene: scene, time: 10)
            for size in [CGSize(width: 402, height: 874), CGSize(width: 874, height: 402), CGSize(width: 951, height: 669)] {
                for actor in StudioLandscapeRenderer.actorUniforms(state: state, size: size, sourceAspect: 2.0 / 3.0) {
                    XCTAssertGreaterThan(actor.rect.z, 0); XCTAssertGreaterThan(actor.rect.w, 0)
                }
            }
        }
    }
    func testSimplifiedCompositionsKeepWeatherAndPreserveDormantActors() throws {
        let snow = MeditationComposition.scene(sounds: ["walk-in-snow", "wolf"].compactMap(DriftCatalog.sound), volumes: [:])
        try snow.validate()
        XCTAssertEqual(snow.visuals.landscape, .snow)
        XCTAssertEqual(snow.visuals.actors?.map(\.sourceID), ["wolf"])
        XCTAssertTrue(snow.visuals.effects?.contains(.snowTracks) == true)
        let car = MeditationComposition.scene(sounds: ["rain-on-car-roof", "windshield-wipers"].compactMap(DriftCatalog.sound), volumes: [:])
        try car.validate()
        XCTAssertEqual(car.visuals.landscape, .car)
        XCTAssertGreaterThan(car.visuals.rain, 0)
        XCTAssertTrue(car.visuals.effects?.contains(.wipers) == true)
        XCTAssertTrue(car.visuals.effects?.contains(.glassRain) == true)
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let renderer = try StudioLandscapeRenderer(device: device)
        let source = try StudioLandscapeRenderer.loadPhotograph(.snow, device: device)
        let state = StudioVisualState(scene: snow, time: 10)
        XCTAssertTrue(state.actors.isEmpty)
        XCTAssertFalse(snow.visuals.compositionSummary.contains("Wolf"))
        XCTAssertTrue(renderer.sprites.isEmpty, "Unused sprite atlases should not consume GPU memory")
        let decoded = try JSONDecoder().decode(StudioScene.self, from: JSONEncoder().encode(snow))
        XCTAssertEqual(decoded.visuals.actors, snow.visuals.actors, "Keep actor recipes in saved scenes for a future release")
        XCTAssertEqual(decoded.layers, snow.layers)
        var forced = state
        forced.actors = snow.visuals.actors ?? []
        XCTAssertEqual(try render(renderer, source: source, state: state, time: 1),
                       try render(renderer, source: source, state: forced, time: 1),
                       "Even a legacy/malformed snapshot cannot draw decorative cutouts")
        var withoutEffects = state; withoutEffects.effects = 0
        XCTAssertNotEqual(try render(renderer, source: source, state: state, time: 1),
                          try render(renderer, source: source, state: withoutEffects, time: 1),
                          "Snowfall and footprint effects remain available")
        for size in [CGSize(width: 128, height: 192), CGSize(width: 256, height: 118), CGSize(width: 951, height: 669)] {
            XCTAssertTrue(StudioLandscapeRenderer.actorUniforms(state: forced, size: size, sourceAspect: 2.0 / 3.0).isEmpty)
        }
    }
    func testEveryCatalogueItemProducesAValidLocalVisualRecipe() throws {
        for sound in DriftCatalog.sounds {
            let scene = MeditationComposition.scene(sounds: [sound], volumes: [:])
            try scene.validate()
            XCTAssertEqual(scene.layers.first?.catalogID, sound.id)
            XCTAssertTrue(scene.visuals.landscape.photographURL.map { FileManager.default.fileExists(atPath: $0.path) } == true, sound.id)
        }
        let valid = MeditationComposition.scene(sounds: [DriftCatalog.sound("wolf")!], volumes: [:])
        var invalid = valid; invalid.visuals.actors?[0].tile = 99
        XCTAssertThrowsError(try invalid.validate())
    }
    @MainActor func testLiveViewKeepsRenderingAndSurvivesPauseAndReattachment() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController(); window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previous?.makeKey() }
        let host = LandscapeHostView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        controller.view.addSubview(host)
        var document = StudioScene(name: "Live rain and flames", seed: 42)
        document.visuals = StudioVisuals(landscape: .cabin, rain: 1, wind: 0.6, fire: true)
        let state = StudioVisualState(scene: document, time: 10)
        host.update(state: state, animated: true)
        for _ in 0..<20 {
            host.setNeedsLayout(); host.layoutIfNeeded(); host.update(state: state, animated: true)
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertGreaterThan(host.renderedFrames, 15, "The actual onscreen view must present moving frames, even with repeated SwiftUI updates")
        XCTAssertGreaterThan(host.animationTime, 0.5)
        host.update(state: state, animated: false)
        try await Task.sleep(for: .milliseconds(200))
        let pausedTime = host.animationTime, pausedFrames = host.renderedFrames
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(host.animationTime, pausedTime, accuracy: 0.001)
        XCTAssertEqual(host.renderedFrames, pausedFrames)
        host.removeFromSuperview()
        controller.view.addSubview(host); host.update(state: state, animated: true)
        try await Task.sleep(for: .milliseconds(600))
        XCTAssertGreaterThan(host.renderedFrames, pausedFrames + 3)
        host.stop()
    }
    @MainActor func testAppearanceChangesKeepOneLandscapeSurfaceAndPauseItBehindNodi() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let suite = "landscape-switch-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let store = DriftStore(defaults: defaults)
        store.setMeditationAppearance(.landscape)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: ImmersiveView().environmentObject(store).environmentObject(store.audio).environment(\.scenePhase, .active))
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previous?.makeKey(); defaults.removePersistentDomain(forName: suite) }
        func surfaces(_ view: UIView) -> [LandscapeHostView] {
            (view as? LandscapeHostView).map { [$0] } ?? view.subviews.flatMap(surfaces)
        }
        // First-use texture/pipeline preparation can outlast one second on a
        // cold simulator. Wait for a presented surface rather than a fixed delay.
        for _ in 0..<50 {
            if let host = surfaces(window).first, host.renderedFrames > 3 { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        let host = try XCTUnwrap(surfaces(window).first)
        XCTAssertGreaterThan(host.renderedFrames, 3)
        for _ in 0..<3 {
            store.setMeditationAppearance(.nodi)
            try await Task.sleep(for: .milliseconds(250))
            XCTAssertEqual(surfaces(window).count, 1)
            XCTAssertTrue(surfaces(window).first === host)
            let paused = host.animationTime
            try await Task.sleep(for: .milliseconds(200))
            XCTAssertEqual(host.animationTime, paused, accuracy: 0.001, "The hidden landscape must stop rendering")
            let frames = host.renderedFrames
            store.setMeditationAppearance(.landscape)
            try await Task.sleep(for: .milliseconds(450))
            XCTAssertTrue(surfaces(window).first === host, "Reuse the same drawable rather than flashing through a fresh surface")
            XCTAssertGreaterThan(host.renderedFrames, frames + 2)
        }
    }
    func testMeditationUsesTheSelectedMixAndLegacySettingsStillDecode() throws {
        let sounds = ["heavy-rain", "campfire", "wind-in-trees"].compactMap(DriftCatalog.sound)
        let scene = MeditationComposition.scene(sounds: sounds, volumes: ["campfire": 0, "heavy-rain": 0.4])
        XCTAssertEqual(scene.layers.compactMap(\.catalogID), sounds.map(\.id))
        XCTAssertEqual(scene.visuals.landscape, .forest, "A silent fire must not choose the cabin")
        let state = StudioVisualState(scene: scene, time: 1)
        XCTAssertEqual(state.rain, 1); XCTAssertEqual(state.fire, 0)
        XCTAssertGreaterThan(state.wind, 0)
        let river = MeditationComposition.scene(sounds: [DriftCatalog.sound("river")!], volumes: [:])
        XCTAssertEqual(river.visuals.landscape, .river); XCTAssertEqual(river.visuals.rain, 0)
        let data = try JSONEncoder().encode(DriftConfiguration())
        let decoded = try JSONDecoder().decode(DriftConfiguration.self, from: data)
        XCTAssertNil(decoded.meditationAppearance, "Earlier settings have no appearance field")
    }
    func testPhotographicAssetsAreBundledAndDecode() throws {
        for landscape in StudioLandscape.allCases {
            let url = try XCTUnwrap(landscape.photographURL)
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil), landscape.rawValue)
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            XCTAssertGreaterThanOrEqual(image.width, 1024)
            XCTAssertGreaterThanOrEqual(image.height, 1536)
        }
        XCTAssertEqual(MemoryLayout<StudioLandscapeUniforms>.stride, 112)
    }
    func testEveryScenarioHasAnIndependentWidePhotographAndAdaptsToViewport() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let renderer = try StudioLandscapeRenderer(device: device)
        for landscape in StudioLandscape.allCases {
            try autoreleasepool {
                let portrait = StudioLandscapePlate(landscape: landscape, size: CGSize(width: 402, height: 874))
                let wide = StudioLandscapePlate(landscape: landscape, size: CGSize(width: 874, height: 402))
                XCTAssertFalse(portrait.wide); XCTAssertTrue(wide.wide)
                XCTAssertNotEqual(portrait.photographURL, wide.photographURL)
                XCTAssertTrue(try XCTUnwrap(wide.photographURL).lastPathComponent.hasSuffix("-wide.jpg"))
                for viewport in [CGSize(width: 1024, height: 768), CGSize(width: 951, height: 669), CGSize(width: 1600, height: 700)] {
                    XCTAssertTrue(StudioLandscapePlate(landscape: landscape, size: viewport).wide)
                }
                let photo = try StudioLandscapeRenderer.loadPhotograph(landscape, wide: true, device: device)
                XCTAssertGreaterThan(photo.width, photo.height)
                XCTAssertGreaterThanOrEqual(photo.width, 1536)
                var scene = StudioScene(name: "Wide " + landscape.title, seed: 42)
                scene.visuals = StudioVisuals(landscape: landscape, rain: 0.7, wind: 0.6, fire: landscape == .cabin)
                let state = StudioVisualState(scene: scene, time: 30)
                let uniforms = StudioLandscapeRenderer.uniforms(state: state, size: CGSize(width: 256, height: 144), texture: photo, time: 1)
                XCTAssertEqual(uniforms.composition.y, 1)
                XCTAssertEqual(uniforms.hearth, wide.hearth)
                let a = try render(renderer, source: photo, state: state, time: 1, size: CGSize(width: 256, height: 144))
                XCTAssertFalse(a.isEmpty)
                if landscape == .cabin || landscape == .forest || landscape == .car {
                    let b = try render(renderer, source: photo, state: state, time: 2, size: CGSize(width: 256, height: 144))
                    XCTAssertNotEqual(a, b, "Horizontal weather/fire must animate: " + landscape.rawValue)
                }
            }
        }
    }
    @MainActor func testLiveSurfaceChangesArtworkOnResizeEvenWhilePaused() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController(); window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previous?.makeKey() }
        let host = LandscapeHostView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        controller.view.addSubview(host)
        var document = StudioScene(name: "Adaptive cabin", seed: 42)
        document.visuals = StudioVisuals(landscape: .cabin, rain: 1, fire: true)
        let state = StudioVisualState(scene: document, time: 10)
        for size in [CGSize(width: 320, height: 640), CGSize(width: 720, height: 360), CGSize(width: 320, height: 640)] {
            host.frame.size = size; host.setNeedsLayout(); host.layoutIfNeeded()
            host.update(state: state, animated: false)
            let expected = StudioLandscapePlate(landscape: .cabin, size: size)
            for _ in 0..<30 {
                if host.displayedPlate == expected { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            XCTAssertEqual(host.displayedPlate, expected, "Paused scenery must choose the new photograph and present it after resizing")
        }
        host.stop()
    }
    func testVisualStateTracksAutomationAndMutedSources() {
        var scene = StudioScene(name: "Rain", seed: 42)
        scene.visuals.rain = 0.8; scene.visuals.wind = 0.6; scene.visuals.fire = true
        scene.layers = [StudioLayer(name: "Rain", catalogID: "light-rain", volume: 0.5, fadeIn: 0,
                                   keyframes: [.init(time: 0, intensity: 0.2, position: .init()), .init(time: 100, intensity: 1, position: .init())]),
                        StudioLayer(name: "Wind", catalogID: "wind", volume: 0.4, muted: true),
                        StudioLayer(name: "Fire", catalogID: "campfire", volume: 0.3, muted: true)]
        let state = StudioVisualState(scene: scene, time: 50)
        XCTAssertEqual(state.rain, 0.48, accuracy: 0.001)
        XCTAssertEqual(state.wind, 0)
        XCTAssertEqual(state.fire, 0)
        scene.visuals.dawn = true
        XCTAssertGreaterThan(StudioVisualState(scene: scene, time: 250).daylight, StudioVisualState(scene: scene, time: 50).daylight)
    }
    func testReduceMotionSuppressesLightning() {
        var scene = StudioScene(name: "Thunder", seed: 42)
        scene.layers = [.init(name: "Thunder", catalogID: "thunder", randomEvents: true)]
        let time = (0..<3000).map { Double($0) / 10 }.first { StudioVisualState(scene: scene, time: $0).lightning > 0 }!
        XCTAssertGreaterThan(StudioVisualState(scene: scene, time: time).lightning, 0)
        XCTAssertEqual(StudioVisualState(scene: scene, time: time, reduceMotion: true).lightning, 0)
    }
    func testMetalRendersPhotographsAndRealMotion() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("Metal is unavailable in this environment") }
        let renderer = try StudioLandscapeRenderer(device: device)
        var scene = StudioScene(name: "River", seed: 42)
        scene.visuals = StudioVisuals(landscape: .river, rain: 0.8, wind: 0.7, daylight: 0.5, fog: 0.4)
        let source = try MTKTextureLoader(device: device).newTexture(URL: XCTUnwrap(scene.visuals.landscape.photographURL), options: [.SRGB: true])
        let state = StudioVisualState(scene: scene, time: 120)
        let first = try render(renderer, source: source, state: state, time: 0)
        let later = try render(renderer, source: source, state: state, time: 2)
        XCTAssertNotEqual(first, later, "Water and weather must actually move")
        XCTAssertEqual(first, try render(renderer, source: source, state: state, time: 0), "A paused frame must be deterministic")
        XCTAssertGreaterThan(Set(stride(from: 0, to: first.count, by: 4).map { first[$0] }).count, 50, "Photo detail cannot collapse to a flat placeholder")
        for landscape in StudioLandscape.allCases {
            scene.visuals.landscape = landscape
            let photo = try MTKTextureLoader(device: device).newTexture(URL: XCTUnwrap(landscape.photographURL), options: [.SRGB: true])
            XCTAssertFalse(try render(renderer, source: photo, state: StudioVisualState(scene: scene, time: 120), time: 1).isEmpty)
        }
    }
    func testPhotographicColorPreservesNaturalGreens() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let renderer = try StudioLandscapeRenderer(device: device)
        var scene = StudioScene(name: "Color", seed: 42)
        scene.visuals = StudioVisuals(landscape: .river, rain: 0, wind: 0.55, daylight: 0.42, fog: 0.4, stars: false)
        let source = try StudioLandscapeRenderer.loadPhotograph(.river, device: device)
        XCTAssertTrue([MTLPixelFormat.bgra8Unorm_srgb, .rgba8Unorm_srgb].contains(source.pixelFormat))
        let processed = try render(renderer, source: source, state: StudioVisualState(scene: scene, time: 120), time: 1.5)
        let means = (0..<3).map { channel in stride(from: channel, to: processed.count, by: 4).reduce(0.0) { $0 + Double(processed[$1]) } / Double(processed.count / 4) }
        let report = XCTAttachment(string: "BGRA graded=\(means), sRGB format=\(source.pixelFormat)")
        report.name = "Photographic-color-check"; report.lifetime = .keepAlways; add(report)
        XCTAssertGreaterThan(means[1], means[0], "River foliage must remain green rather than blue")
        XCTAssertGreaterThan(means[1], means[2], "River foliage must remain green rather than magenta")
    }
    func testFireAndRainMoveIndividuallyWithoutFoliageOrWater() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let renderer = try StudioLandscapeRenderer(device: device)
        for fire in [true, false] {
            var scene = StudioScene(name: fire ? "Fire only" : "Rain only", seed: 42)
            scene.visuals = StudioVisuals(landscape: fire ? .cabin : .forest, rain: fire ? 0 : 1,
                                         wind: 0, daylight: 0.4, fog: 0, fire: fire, stars: false)
            let source = try StudioLandscapeRenderer.loadPhotograph(scene.visuals.landscape, device: device)
            let state = StudioVisualState(scene: scene, time: 10)
            let a = try render(renderer, source: source, state: state, time: 0.1)
            let b = try render(renderer, source: source, state: state, time: 0.8)
            if fire {
                let hearth = (106..<134).flatMap { y in (12..<40).flatMap { x in (0..<3).map { (y * 128 + x) * 4 + $0 } } }
                XCTAssertNotEqual(hearth.map { a[$0] }, hearth.map { b[$0] }, "Flames inside the photographed hearth must change shape")
            } else {
                XCTAssertNotEqual(a, b, "Rain must fall even when foliage, fog, water and stars are stationary")
            }
        }
    }
    private func render(_ renderer: StudioLandscapeRenderer, source: MTLTexture, state: StudioVisualState, time: Double, size: CGSize = CGSize(width: 128, height: 192)) throws -> Data {
        let width = Int(size.width), height = Int(size.height)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.renderTarget, .shaderRead]
        let output = try XCTUnwrap(renderer.device.makeTexture(descriptor: descriptor))
        let pass = MTLRenderPassDescriptor(); pass.colorAttachments[0].texture = output
        pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
        let command = try XCTUnwrap(renderer.queue.makeCommandBuffer())
        let encoder = try XCTUnwrap(command.makeRenderCommandEncoder(descriptor: pass))
        renderer.encode(encoder, photograph: source, state: state, size: size, time: time)
        encoder.endEncoding()
        command.commit(); command.waitUntilCompleted()
        if let error = command.error { throw error }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        output.getBytes(&pixels, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        return Data(pixels)
    }
}
