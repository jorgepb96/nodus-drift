// SPDX-License-Identifier: MIT
import Foundation

enum StudioError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}

enum StudioLandscape: String, Codable, CaseIterable, Identifiable {
    case forest, coast, mountains, cabin, river, snow, night
    case car, tent, cafe, city, train, underwater, room, sanctuary, airport
    case utility, market, construction, fairground, laboratory, library
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .forest: return "tree"
        case .coast: return "water.waves"
        case .mountains: return "mountain.2"
        case .cabin: return "flame"
        case .river: return "drop"
        case .snow: return "snowflake"
        case .night: return "moon.stars"
        case .car: return "car"
        case .tent: return "tent"
        case .cafe: return "cup.and.saucer"
        case .city: return "building.2"
        case .train: return "tram"
        case .underwater: return "water.waves"
        case .room: return "deskclock"
        case .sanctuary: return "building.columns"
        case .airport: return "airplane"
        case .utility: return "washer"
        case .market: return "basket"
        case .construction: return "hammer"
        case .fairground: return "sparkles"
        case .laboratory: return "flask"
        case .library: return "books.vertical"
        }
    }
}

struct StudioVisuals: Codable, Equatable {
    var enabled = true
    var landscape: StudioLandscape = .forest
    var rain = 0.3
    var wind = 0.2
    var daylight = 0.15
    var fog = 0.25
    var fire = false
    var stars = true
    var dawn = false
    var tint = 0.5
    var actors: [StudioVisualActor]?
    var effects: [StudioVisualEffect]?
}

struct StudioPosition: Codable, Equatable {
    var x: Float = 0
    var z: Float = -3
    static func interpolate(_ a: Self, _ b: Self, _ fraction: Float) -> Self {
        Self(x: a.x + (b.x - a.x) * fraction, z: a.z + (b.z - a.z) * fraction)
    }
}

struct StudioKeyframe: Codable, Equatable, Identifiable {
    var id = UUID()
    var time: Double
    /// Gain multiplier, so the layer's main volume remains useful with automation.
    var intensity: Float
    var position: StudioPosition
}

struct StudioRecording: Codable, Equatable {
    var fileName: String
    var sha256: String
    var bytes: Int
    var seconds: Double
    var prompt: String
    var model: String
    var seed: UInt64
    var revision: String
}

enum StudioRole: String, Codable, CaseIterable, Identifiable {
    case rain, wind, thunder, fire, water, birds, music, other
    var id: String { rawValue }
    static func infer(_ text: String) -> Self {
        let text = text.lowercased()
        let words = text.components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty }
        if text.contains("thunder") || text.contains("lightning") { return .thunder }
        if words.contains(where: { $0.hasPrefix("rain") }) { return .rain }
        if words.contains(where: { $0 == "wind" || $0 == "windy" }) { return .wind }
        if text.contains("fire") || text.contains("embers") { return .fire }
        if text.contains("river") || text.contains("waves") || text.contains("water") { return .water }
        if text.contains("bird") || text.contains("owl") || text.contains("seagull") { return .birds }
        return .other
    }
}

struct StudioLayer: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var catalogID: String?
    var recording: StudioRecording?
    var volume: Float = 0.3
    var muted = false
    var spatial = true
    var position = StudioPosition()
    var start: Double = 0
    var end: Double = 300
    var fadeIn: Double = 3
    var fadeOut: Double = 3
    var randomEvents = false
    var eventGap: Double = 25
    var eventLength: Double = 6
    var keyframes: [StudioKeyframe] = []
    var role: StudioRole?
    var requestedPrompt: String?
    var requestedKind: String?
    var isMusic: Bool { recording?.model == "music" || (recording == nil && requestedKind == "music") }
    var visualRole: StudioRole { role ?? (isMusic ? .music : StudioRole.infer(catalogID ?? recording?.prompt ?? name)) }
    var icon: String { catalogID.flatMap(DriftCatalog.sound)?.icon ?? (isMusic ? "music.note" : "waveform") }

    /// Stateless random schedule: scrubbing does not create a different event sequence.
    func eventOffset(at time: Double, seed: UInt64) -> Double? {
        let width = eventGap * 1.6 + eventLength
        let bucket = Int(floor(max(0, time - start) / width))
        let random = StudioScene.random(seed &+ UInt64(bucket))
        let onset = Double(bucket) * width + eventGap * (0.4 + random * 1.2)
        let offset = time - start - onset
        return offset >= 0 && offset < eventLength ? offset : nil
    }

    func evaluated(at time: Double, seed: UInt64) -> (gain: Float, position: StudioPosition) {
        guard !muted, time >= start, time < end else { return (0, position) }
        var intensity: Float = 1
        var point = position
        let frames = keyframes.sorted { $0.time < $1.time }
        if let first = frames.first {
            if time <= first.time { intensity = first.intensity; point = first.position }
            else if let last = frames.last, time >= last.time { intensity = last.intensity; point = last.position }
            else if let index = frames.indices.dropFirst().first(where: { frames[$0].time >= time }) {
                let a = frames[index - 1], b = frames[index]
                let t = Float((time - a.time) / max(0.001, b.time - a.time))
                let smooth = t * t * (3 - 2 * t)
                intensity = a.intensity + (b.intensity - a.intensity) * smooth
                point = .interpolate(a.position, b.position, smooth)
            }
        }
        let edge = min(1, fadeIn > 0 ? (time - start) / fadeIn : 1, fadeOut > 0 ? (end - time) / fadeOut : 1)
        var envelope = max(0, edge)
        if randomEvents {
            guard let offset = eventOffset(at: time, seed: seed) else { return (0, point) }
            envelope *= min(1, offset / 0.35, (eventLength - offset) / 0.8)
        }
        return (max(0, volume * intensity * Float(envelope)), point)
    }
}

struct StudioScene: Codable, Identifiable, Equatable {
    var version = 1
    var id = UUID()
    var name = "Untitled landscape"
    var duration: Double = 300
    var repeats = true
    var master: Float = 0.35
    var seed: UInt64 = UInt64.random(in: 1...UInt64.max / 2)
    var layers: [StudioLayer] = []
    var visuals = StudioVisuals()
    var updated = Date()
    static let maximumLayers = 12
    static let maximumArchiveBytes = 96 * 1024 * 1024

    static func random(_ seed: UInt64) -> Double {
        var value = seed &+ 0x9E3779B97F4A7C15
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return Double((value ^ (value >> 31)) >> 11) / 9_007_199_254_740_992
    }

    /// Reject malformed imports, rather than silently changing their meaning.
    func validate() throws {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw StudioError.invalid(message) }
        }
        try require(version == 1, "This scene format is not supported.")
        try require(!name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 80, "Use a scene name of 1–80 characters.")
        try require(duration.isFinite && (10...3600).contains(duration), "Scene length must be 10 seconds to 60 minutes.")
        try require(master.isFinite && (0...1).contains(master), "Invalid master volume.")
        try require(layers.count <= Self.maximumLayers && Set(layers.map(\.id)).count == layers.count, "A scene holds up to 12 unique layers.")
        for layer in layers {
            try require(!layer.name.isEmpty && layer.name.count <= 80, "Invalid layer name.")
            if let prompt = layer.requestedPrompt {
                try require(!prompt.isEmpty && prompt.count <= 400 && ["sfx", "music"].contains(layer.requestedKind ?? ""), "Invalid suggested recording.")
            } else { try require(layer.requestedKind == nil, "Invalid suggested model.") }
            try require((layer.catalogID == nil) != (layer.recording == nil), "Each layer must have one audio source.")
            if let id = layer.catalogID { try require(DriftCatalog.sound(id) != nil, "The scene refers to an unknown catalogue sound.") }
            try require(layer.volume.isFinite && (0...1).contains(layer.volume), "Invalid layer volume.")
            try require(layer.start.isFinite && layer.end.isFinite && layer.start >= 0 && layer.end <= duration && layer.end > layer.start, "Invalid layer time range.")
            try require(layer.fadeIn.isFinite && layer.fadeOut.isFinite && (0...60).contains(layer.fadeIn) && (0...60).contains(layer.fadeOut), "Invalid fade length.")
            try require(layer.eventGap.isFinite && (3...300).contains(layer.eventGap) && layer.eventLength.isFinite && (1...60).contains(layer.eventLength), "Invalid random event timing.")
            try require(layer.keyframes.count <= 64 && Set(layer.keyframes.map(\.time)).count == layer.keyframes.count, "Use up to 64 keyframes at distinct times.")
            let positions = [layer.position] + layer.keyframes.map(\.position)
            try require(positions.allSatisfy { $0.x.isFinite && $0.z.isFinite && abs($0.x) <= 20 && abs($0.z) <= 20 }, "Invalid spatial position.")
            try require(layer.keyframes.allSatisfy { $0.time.isFinite && (0...duration).contains($0.time) && $0.intensity.isFinite && (0...1).contains($0.intensity) }, "Invalid automation.")
            if let recording = layer.recording {
                try require(Self.safeAudioName(recording.fileName), "Invalid recording path.")
                try require(recording.sha256.count == 64 && recording.sha256.allSatisfy { $0.isHexDigit }, "Invalid recording checksum.")
                try require((1...24_000_000).contains(recording.bytes) && recording.seconds.isFinite && (0.5...120).contains(recording.seconds), "Recording is too large or too long.")
                try require(recording.prompt.count <= 600 && ["sfx", "music"].contains(recording.model), "Invalid generation metadata.")
                try require(!recording.revision.isEmpty && recording.revision.count <= 80, "Invalid model revision.")
            }
        }
        try require([visuals.rain, visuals.wind, visuals.daylight, visuals.fog, visuals.tint].allSatisfy { $0.isFinite && (0...1).contains($0) }, "Invalid visual settings.")
        try require((visuals.actors ?? []).count <= 12 && (visuals.effects ?? []).count <= StudioVisualEffect.allCases.count, "Too many visual elements.")
        for actor in visuals.actors ?? [] {
            try require(DriftCatalog.sound(actor.sourceID) != nil && (0..<16).contains(actor.tile), "Unknown visual element.")
            try require([actor.x, actor.y, actor.width].allSatisfy { $0.isFinite && (0...1).contains($0) } && actor.width > 0.01, "Invalid visual element position.")
        }
    }

    static func safeAudioName(_ name: String) -> Bool {
        name.hasSuffix(".m4a") && UUID(uuidString: String(name.dropLast(4))) != nil && !name.contains("/")
    }

    func duplicated() -> Self {
        var copy = self; copy.id = UUID(); copy.name = String((name + " copy").prefix(80)); copy.updated = Date()
        copy.layers = layers.map { var layer = $0; layer.id = UUID(); return layer }
        return copy
    }

    static let starters: [Self] = {
        func layer(_ id: String, _ volume: Float, _ x: Float, _ z: Float) -> StudioLayer {
            StudioLayer(name: DriftCatalog.sound(id)?.name ?? id, catalogID: id, volume: volume, position: StudioPosition(x: x, z: z))
        }
        var cabin = Self(name: "A storm beyond the cabin")
        cabin.visuals = StudioVisuals(landscape: .cabin, rain: 0.65, wind: 0.5, fire: true)
        cabin.layers = [layer("rain-on-window", 0.4, 0, -4), layer("campfire", 0.32, -2, -1), layer("wind-in-trees", 0.2, 4, -8), layer("thunder", 0.2, 7, -16)]
        cabin.layers[0].keyframes = [.init(time: 0, intensity: 0.25, position: .init(z: -4)), .init(time: 210, intensity: 1, position: .init(z: -4))]
        cabin.layers[3].randomEvents = true
        cabin.layers[3].keyframes = [.init(time: 0, intensity: 0.2, position: .init(x: 7, z: -16)), .init(time: 250, intensity: 1, position: .init(x: 2, z: -3))]
        var dawn = Self(name: "The forest wakes")
        dawn.repeats = false
        dawn.visuals = StudioVisuals(landscape: .forest, rain: 0, daylight: 0.15, dawn: true)
        dawn.layers = [layer("wind-in-trees", 0.24, -4, -4), layer("birds", 0.3, 3, -6), layer("river", 0.22, 6, -3)]
        dawn.layers[1].keyframes = [.init(time: 0, intensity: 0.1, position: .init(x: 3, z: -6)), .init(time: 200, intensity: 1, position: .init(x: 2, z: -3))]
        var coast = Self(name: "A tide under the stars")
        coast.visuals = StudioVisuals(landscape: .coast, rain: 0, wind: 0.3, daylight: 0.08)
        coast.layers = [layer("waves", 0.4, 0, -6), layer("wind", 0.16, -5, -2), layer("seagulls", 0.15, 7, -10)]
        coast.layers[2].randomEvents = true; coast.layers[2].eventGap = 50
        return [cabin, dawn, coast]
    }()
}
