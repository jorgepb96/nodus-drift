// SPDX-License-Identifier: MIT
import Foundation

enum StudioVisualEffect: String, Codable, CaseIterable {
    case snowTracks, leafTracks, gravelTracks, wipers, glassRain, bubbles, steam
    case fireworks, traffic, crowd, ripples, signal, fan, waterfall
    var mask: UInt32 { 1 << UInt32(Self.allCases.firstIndex(of: self)!) }
    var title: String {
        switch self {
        case .snowTracks: return "Footprints in snow"
        case .leafTracks: return "Falling leaves"
        case .gravelTracks: return "Gravel path"
        case .wipers: return "Moving wipers"
        case .glassRain: return "Rain on glass"
        case .bubbles: return "Rising bubbles"
        case .steam: return "Drifting steam"
        case .fireworks: return "Distant fireworks"
        case .traffic: return "Passing lights"
        case .crowd: return "Distant movement"
        case .ripples: return "Water ripples"
        case .signal: return "Soft signal glow"
        case .fan: return "Turning fan"
        case .waterfall: return "Water spray"
        }
    }
}

enum StudioSpriteAtlas: String, Codable { case animals, props }

struct StudioVisualActor: Codable, Equatable, Identifiable {
    var id: String { "\(sourceID)-\(atlas.rawValue)-\(tile)" }
    var sourceID: String
    var atlas: StudioSpriteAtlas
    var tile: Int
    /// Anchor in the original image, with the bottom resting on the surface.
    var x: Float
    var y: Float
    var width: Float
    var title: String {
        if sourceID == "laundry-room" { return tile == 11 ? "Washing machine" : "Dryer" }
        return DriftCatalog.sound(sourceID)?.name ?? sourceID
    }
}

struct StudioSpriteRegion: Decodable {
    var x: Float; var y: Float; var width: Float; var height: Float
    var aspect: Float { width / max(0.001, height) }
    static let regions: [String: [StudioSpriteRegion]] = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Landscapes/sprite-regions.json"),
              let data = try? Data(contentsOf: url),
              let result = try? JSONDecoder().decode([String: [StudioSpriteRegion]].self, from: data) else { return [:] }
        return result
    }()
    static func region(at tile: Int, in atlas: StudioSpriteAtlas) -> StudioSpriteRegion {
        if let values = regions[atlas.rawValue], values.indices.contains(tile) { return values[tile] }
        return .init(x: Float(tile % 4) / 4, y: Float(tile / 4) / 4, width: 0.25, height: 0.25)
    }
}

extension StudioLandscape {
    var isInterior: Bool { [.car, .tent, .cafe, .cabin, .train, .room, .sanctuary, .airport, .utility, .market, .laboratory, .library].contains(self) }
    /// A lower focal point keeps surfaces, animals and the hearth in wide crops.
    var focusY: Float {
        switch self {
        case .cabin: return 0.63
        case .car: return 0.56
        case .tent: return 0.61
        case .cafe, .room, .laboratory, .library: return 0.69
        case .train: return 0.57
        case .snow: return 0.67
        case .underwater, .city, .sanctuary, .airport, .market, .construction, .fairground: return 0.61
        case .utility: return 0.79
        default: return 0.57
        }
    }
}

extension StudioVisuals {
    var compositionSummary: String {
        let integrated = StudioVisualPolicy.resolve(self)
        var parts = (StudioVisualPolicy.decorativeActorsEnabled ? integrated.actors ?? [] : []).map(\.title) + (integrated.effects ?? []).map(\.title)
        if integrated.rain > 0 { parts.insert(landscape == .snow ? "Falling snow" : "Rain", at: 0) }
        if integrated.fire { parts.append("Fire") }
        if integrated.wind > 0.3 { parts.append("Wind") }
        return parts.joined(separator: " · ")
    }
}

/// A sound can belong to the ambience without its object appearing in the shot.
/// This gate also applies to older saved/imported scenes and manually chosen backgrounds.
enum StudioVisualPolicy {
    // Presentation-only switch: keep actor recipes, saved documents, atlases and
    // placement code intact so decorative overlays can return in a future release.
    static let decorativeActorsEnabled = false

    static let literalSources: Set<String> = [
        "birds", "seagulls", "crickets", "wolf", "owl", "frog", "dog-barking", "horse-gallop",
        "cat-purring", "crows", "whale", "beehive", "woodpecker", "chickens", "cows", "sheep",
        "clock", "keyboard", "typewriter", "paper", "wind-chimes", "singing-bowl", "ceiling-fan",
        "slide-projector", "boiling-water", "tuning-radio", "vinyl-effect", "washing-machine", "dryer",
        "morse-code", "rain-on-umbrella", "laundry-room"
    ]
    static func permits(_ effect: StudioVisualEffect, in scene: StudioLandscape) -> Bool {
        switch effect {
        case .snowTracks: return scene == .snow
        case .leafTracks: return scene == .forest
        case .gravelTracks: return [.forest, .mountains, .construction].contains(scene)
        case .wipers: return scene == .car
        case .glassRain: return [.car, .cabin, .cafe, .train, .room, .airport, .laboratory, .library].contains(scene)
        case .bubbles: return scene == .underwater
        case .steam: return [.cafe, .room, .utility].contains(scene)
        case .fireworks: return [.city, .coast, .mountains, .night, .fairground].contains(scene)
        case .traffic: return scene == .city
        case .crowd: return [.city, .cafe, .airport, .market, .fairground, .train, .sanctuary].contains(scene)
        case .ripples: return [.coast, .river, .night, .underwater].contains(scene)
        case .signal: return [.room, .laboratory].contains(scene)
        case .fan: return false // A detached fan cutout has no calibrated ceiling mount.
        case .waterfall: return scene == .river
        }
    }
    static func placement(for actor: StudioVisualActor, in scene: StudioLandscape) -> StudioVisualActor? {
        var value = actor
        if actor.atlas == .animals {
            switch (actor.sourceID, actor.tile) {
            case ("wolf", 3) where [.snow, .forest].contains(scene):
                value.x = 0.65; value.y = 0.79; value.width = 0.23
            case ("dog-barking", 6) where [.snow, .forest, .cabin].contains(scene):
                value.x = 0.64; value.y = scene == .cabin ? 0.94 : 0.81; value.width = 0.17
            case ("frog", 5) where scene == .river:
                value.x = 0.76; value.y = 0.84; value.width = 0.08
            case ("seagulls", 1) where scene == .coast:
                value.x = 0.52; value.y = 0.36; value.width = 0.15
            case ("whale", 10) where scene == .underwater:
                value.x = 0.54; value.y = 0.56; value.width = 0.40
            case ("cat-purring", 8) where [.room, .cafe].contains(scene):
                value.y = 0.81; value.width = 0.25
            default: return nil // No photographed perch/ground/water habitat for this animal.
            }
            return value
        }
        let tabletop = ["keyboard": 1, "typewriter": 2, "paper": 3, "singing-bowl": 5,
                        "boiling-water": 8, "tuning-radio": 9, "vinyl-effect": 10, "morse-code": 13]
        if [.room, .cafe].contains(scene), tabletop[actor.sourceID] == actor.tile {
            value.y = 0.81; value.width = actor.sourceID == "paper" ? 0.17 : 0.21
            return value
        }
        if scene == .utility,
           (actor.sourceID == "laundry-room" && [11, 12].contains(actor.tile) ||
            actor.sourceID == "washing-machine" && actor.tile == 11 || actor.sourceID == "dryer" && actor.tile == 12) {
            value.y = 0.94; value.width = 0.30; return value
        }
        return nil
    }
    static func resolve(_ proposed: StudioVisuals) -> StudioVisuals {
        var result = proposed
        result.fire = proposed.fire && proposed.landscape == .cabin
        if proposed.landscape.isInterior || proposed.landscape == .underwater { result.stars = false }
        if proposed.landscape == .underwater { result.rain = 0; result.wind = 0 }
        result.effects = Array(Set(proposed.effects ?? [])).filter { permits($0, in: proposed.landscape) }
            .sorted { $0.rawValue < $1.rawValue }
        var occupied = Set<String>(), groups: [String: Int] = [:]
        result.actors = (proposed.actors ?? []).sorted { $0.id < $1.id }.compactMap { actor in
            guard var value = placement(for: actor, in: proposed.landscape) else { return nil }
            let surface = value.atlas == .props || value.sourceID == "cat-purring"
            let group = surface ? "surface" : (value.sourceID == "seagulls" ? "sky" : "habitat")
            let limit = surface ? 2 : 1
            let slot = groups[group, default: 0]
            guard slot < limit, occupied.insert("\(value.atlas.rawValue)-\(value.tile)").inserted else { return nil }
            groups[group] = slot + 1
            if surface { value.x = slot == 0 ? 0.35 : 0.66 }
            return value
        }
        return result
    }
}

extension StudioScene {
    var offscreenVisualSounds: String {
        guard StudioVisualPolicy.decorativeActorsEnabled else { return "" }
        let integrated = StudioVisualPolicy.resolve(visuals)
        let visible = Set((integrated.actors ?? []).map(\.sourceID))
        let names = layers.filter { !$0.muted && $0.volume > 0 }.compactMap { layer -> String? in
            if layer.visualRole == .fire && !integrated.fire { return layer.name }
            guard let id = layer.catalogID, StudioVisualPolicy.literalSources.contains(id), !visible.contains(id) else { return nil }
            return layer.name
        }
        return names.isEmpty ? "" : "Heard off-screen: " + Array(NSOrderedSet(array: names)).compactMap { $0 as? String }.joined(separator: " · ")
    }
}
