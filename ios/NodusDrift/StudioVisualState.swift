// SPDX-License-Identifier: MIT
import Foundation

/// The renderer consumes a small value snapshot, never the audio engine or document.
struct StudioVisualState: Equatable {
    var landscape: StudioLandscape
    var rain: Float
    var wind: Float
    var daylight: Float
    var fog: Float
    var fire: Float
    var stars: Float
    var tint: Float
    var lightning: Float
    var seed: Float
    var actors: [StudioVisualActor]
    var effects: UInt32
    var focusY: Float

    init(scene: StudioScene, time: Double, reduceMotion: Bool = false) {
        var proposed = scene.visuals
        proposed.actors = proposed.actors?.filter { actor in
            let sources = scene.layers.filter { $0.catalogID == actor.sourceID }
            return sources.isEmpty || sources.contains { !$0.muted && $0.volume > 0 }
        }
        let visuals = StudioVisualPolicy.resolve(proposed)
        landscape = visuals.landscape
        func intensity(_ role: StudioRole) -> Float {
            let matches = scene.layers.enumerated().filter { $0.element.visualRole == role }
            guard !matches.isEmpty else { return 1 }
            return matches.map { index, layer in
                let state = layer.evaluated(at: time, seed: scene.seed &+ UInt64(index * 7919))
                return layer.volume > 0.0001 ? min(1, state.gain / layer.volume) : 0
            }.max() ?? 0
        }
        rain = Float(visuals.rain) * intensity(.rain)
        wind = Float(visuals.wind) * intensity(.wind)
        daylight = Float(min(1, visuals.daylight + (visuals.dawn ? max(0, min(1, time / scene.duration)) * 0.8 : 0)))
        fog = Float(visuals.fog)
        fire = visuals.fire ? intensity(.fire) : 0
        stars = visuals.stars ? 1 : 0
        tint = Float(visuals.tint)
        seed = Float(scene.seed % 65521)
        actors = StudioVisualPolicy.decorativeActorsEnabled ? Array((visuals.actors ?? []).filter { actor in
            let sources = scene.layers.filter { $0.catalogID == actor.sourceID }
            return sources.isEmpty || sources.contains { !$0.muted && $0.volume > 0 }
        }.prefix(12)) : []
        effects = (visuals.effects ?? []).reduce(UInt32(0)) { $0 | $1.mask }
        focusY = visuals.landscape.focusY
        if !actors.isEmpty && [.snow, .forest, .river].contains(landscape) { focusY = 0.72 }
        if actors.contains(where: { $0.sourceID == "whale" }) { focusY = 0.49 }
        if actors.contains(where: { $0.sourceID == "seagulls" }) { focusY = 0.43 }
        lightning = 0
        if !reduceMotion {
            for (index, layer) in scene.layers.enumerated() where layer.visualRole == .thunder && layer.randomEvents && !layer.muted && layer.volume > 0 {
                guard let offset = layer.eventOffset(at: time, seed: scene.seed &+ UInt64(index * 7919)) else { continue }
                // Soft double illumination of the scene, without a strobing bolt graphic.
                let first = max(0, 1 - abs(offset - 0.12) / 0.12)
                let second = max(0, 1 - abs(offset - 0.39) / 0.18) * 0.45
                lightning = max(lightning, Float(max(first, second)) * 0.24)
            }
        }
    }
}

extension StudioLandscape {
    var photographURL: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("Landscapes/\(rawValue).jpg")
    }
    var shaderIndex: Float {
        switch self {
        case .forest: return 0
        case .coast: return 1
        case .mountains: return 2
        case .cabin: return 3
        case .river: return 4
        case .snow: return 5
        case .night: return 6
        case .car: return 7
        case .tent: return 8
        case .cafe: return 9
        case .city: return 10
        case .train: return 11
        case .underwater: return 12
        case .room: return 13
        case .sanctuary: return 14
        case .airport: return 15
        case .utility: return 16
        case .market: return 17
        case .construction: return 18
        case .fairground: return 19
        case .laboratory: return 20
        case .library: return 21
        }
    }
}

/// Artwork follows the actual viewport, including resizable and split windows.
/// Both orientations are bundled; the portrait remains a fallback for older packs.
struct StudioLandscapePlate: Equatable {
    let landscape: StudioLandscape
    let wide: Bool

    init(landscape: StudioLandscape, wide: Bool) {
        self.landscape = landscape; self.wide = wide
    }
    init(landscape: StudioLandscape, size: CGSize) {
        self.init(landscape: landscape, wide: size.width > size.height && size.height > 0)
    }
    var assetName: String { landscape.rawValue + (wide ? "-wide" : "") }
    var photographURL: URL? {
        let url = Bundle.main.resourceURL?.appendingPathComponent("Landscapes/\(assetName).jpg")
        if let url, FileManager.default.fileExists(atPath: url.path) { return url }
        return landscape.photographURL
    }
    // Conservative glass bounds measured on the new horizontal photographs.
    // The shader keeps the original detailed masks for portrait artwork.
    var exteriorRect: SIMD4<Float> {
        switch landscape {
        case .cabin: return SIMD4(0.48, 0.24, 0.92, 0.65)
        case .car: return SIMD4(0.08, 0.18, 0.92, 0.64)
        case .cafe: return SIMD4(0.43, 0.09, 0.95, 0.54)
        case .train: return SIMD4(0.26, 0.20, 0.94, 0.61)
        case .room: return SIMD4(0.47, 0.18, 0.92, 0.60)
        case .sanctuary: return SIMD4(0.489, 0.408, 0.522, 0.573)
        case .airport: return SIMD4(0.13, 0.15, 0.87, 0.62)
        case .utility: return SIMD4(0.54, 0.18, 0.93, 0.55)
        case .market: return SIMD4(0.83, 0.10, 0.98, 0.43)
        case .laboratory: return SIMD4(0.50, 0.09, 0.95, 0.57)
        case .library: return SIMD4(0.49, 0.11, 0.90, 0.58)
        default: return SIMD4(0, 0, 1, 1)
        }
    }
    var hearth: SIMD4<Float> {
        wide ? SIMD4(0.26, 0.75, 0.075, 0.16) : SIMD4(0.19, 0.695, 0.10, 0.14)
    }
}
