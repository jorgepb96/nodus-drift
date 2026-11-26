// SPDX-License-Identifier: MIT
import Foundation
import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor final class StudioDirector: ObservableObject {
    @Published private(set) var busy = false
    var availability: String? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return nil
            case .unavailable(.deviceNotEligible): return "This device does not support Apple Intelligence. All manual tools are available."
            case .unavailable(.appleIntelligenceNotEnabled): return "Enable Apple Intelligence in iOS Settings to create scenes with words."
            case .unavailable: return "Apple's on-device model is not ready. Try again later or create manually."
            }
        }
        #endif
        return "Scene direction requires iOS 26 and Apple Intelligence. All manual tools are available."
    }
    func create(instruction: String, current: StudioScene?) async throws -> StudioScene {
        guard !busy else { throw StudioError.invalid("Your scene is already being directed.") }
        guard availability == nil else { throw StudioError.invalid(availability!) }
        let input = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty && input.count <= 1200 else { throw StudioError.invalid("Describe your scene in 1–1200 characters.") }
        busy = true; defer { busy = false }
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            do { return try await AppleStudioDirector.create(instruction: input, current: current) }
            catch is CancellationError { throw CancellationError() }
            catch let error as StudioError { throw error }
            catch { throw StudioError.invalid("Apple's on-device model could not finish this scene. Try a shorter description, try again later, or continue with manual editing.") }
        }
        #endif
        throw StudioError.invalid("Apple Intelligence is unavailable.")
    }
}

#if canImport(FoundationModels)
@available(iOS 26, *) @Generable
private struct DirectedPoint {
    @Guide(description: "Seconds in the scene", .range(0...3600)) var time: Int
    @Guide(description: "Intensity multiplier", .range(0.0...1.0)) var intensity: Double
    @Guide(description: "Left negative, right positive, metres", .range(-20.0...20.0)) var x: Double
    @Guide(description: "In front negative, behind positive, metres", .range(-20.0...20.0)) var z: Double
}
@available(iOS 26, *) @Generable
private struct DirectedLayer {
    @Guide(description: "Reuse the exact UUID of an existing layer being modified, or empty for a new layer") var existingID: String
    @Guide(description: "An exact sound ID from the provided catalogue") var soundID: String
    @Guide(description: "Empty when catalogue sounds suffice. If the user requests an unavailable sound or instrumental score, a brief English audio-generation prompt, maximum 40 words. The soundID must still be a usable catalogue fallback.") var generationPrompt: String
    @Guide(description: "True only for a requested instrumental score, false for environmental sound effects") var generateMusic: Bool
    @Guide(description: "Short name for this layer") var name: String
    @Guide(.range(0.0...1.0)) var volume: Double
    @Guide(description: "Use sparse random events for isolated thunder or animal calls, false for continuous beds") var randomEvents: Bool
    @Guide(description: "Two to four keyframes for intensity and movement", .count(2...4)) var points: [DirectedPoint]
}
@available(iOS 26, *) @Generable
private enum DirectedLandscape { case forest, coast, mountains, cabin, river, snow, night }
@available(iOS 26, *) @Generable
private struct DirectedScene {
    var name: String
    @Guide(.range(30...1800)) var duration: Int
    @Guide(.count(1...8)) var layers: [DirectedLayer]
    var landscape: DirectedLandscape
    @Guide(.range(0.0...1.0)) var rain: Double
    @Guide(.range(0.0...1.0)) var wind: Double
    @Guide(.range(0.0...1.0)) var daylight: Double
    @Guide(.range(0.0...1.0)) var fog: Double
    var fire: Bool
    var dawn: Bool
}

@available(iOS 26, *) private enum AppleStudioDirector {
    static func create(instruction: String, current: StudioScene?) async throws -> StudioScene {
        let catalog = DriftCatalog.sounds.filter { $0.kind != "binaural" }.map { "\($0.id):\($0.name)" }.joined(separator: "; ")
        let session = LanguageModelSession(model: SystemLanguageModel.default, instructions: """
        You direct relaxing soundscapes, not audio synthesis. Return a structured scene using only exact IDs from the catalogue as playable sources or fallbacks.
        Understand requests in any supported language. Names should match the user's language.
        Preserve existing layers and their IDs when modifying; change only what is requested. For distant thunder use low intensity and large negative z, gradually approaching.
        Space sources around the listener. Prefer 3–5 complementary layers with moderate volumes. Points are absolute seconds, sorted, within duration.
        No vocals. Prefer existing sounds; propose a short English generationPrompt only for a requested sound not covered by the catalogue, or an instrumental score. Stable Audio will perform the synthesis separately. Preserve existing recordings when modifying.
        Continuous rain, fire, wind and water are beds; isolated animals and thunder can be random events.
        Catalogue: \(catalog)
        """)
        var context = "Create a new soundscape."
        if let current {
            let layers = current.layers.map { layer in
                "id=\(layer.id.uuidString), sound=\(layer.catalogID ?? "generated"), name=\(layer.name), volume=\(layer.volume), position=\(layer.position.x),\(layer.position.z), points=\(layer.keyframes.map { "\($0.time):\($0.intensity):\($0.position.x):\($0.position.z)" }.joined(separator: "/"))"
            }.joined(separator: "\n")
            context = "Modify this scene, preserving its duration unless requested: name=\(current.name), duration=\(current.duration), landscape=\(current.visuals.landscape.rawValue), rain=\(current.visuals.rain), wind=\(current.visuals.wind), daylight=\(current.visuals.daylight), fog=\(current.visuals.fog), fire=\(current.visuals.fire), dawn=\(current.visuals.dawn). Layers:\n\(layers)"
        }
        let response = try await session.respond(to: "\(context)\nUser instruction: \(instruction)", generating: DirectedScene.self)
        try Task.checkCancellation()
        let plan = response.content
        var scene = current ?? StudioScene()
        scene.name = String(plan.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        scene.duration = Double(plan.duration)
        scene.layers = try plan.layers.map { proposed in
            let previous = current?.layers.first { $0.id.uuidString == proposed.existingID }
            guard let sound = DriftCatalog.sound(proposed.soundID), sound.kind != "binaural" else {
                // Generated sources have no catalogue ID and remain usable when referenced by ID.
                if var previous, previous.recording != nil {
                    previous.volume = Float(proposed.volume)
                    previous.end = min(previous.end, scene.duration)
                    previous.keyframes = points(proposed.points, duration: scene.duration)
                    return previous
                }
                throw StudioError.invalid("The scene director chose a sound outside your library. Try again or edit manually.")
            }
            var layer = previous ?? StudioLayer(name: sound.name, catalogID: sound.id)
            layer.name = String(proposed.name.prefix(80)); layer.volume = Float(proposed.volume)
            if previous?.recording == nil { layer.catalogID = sound.id }
            layer.end = scene.duration; layer.start = 0; layer.randomEvents = proposed.randomEvents
            let requested = proposed.generationPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if !requested.isEmpty {
                layer.requestedPrompt = String(requested.prefix(400)); layer.requestedKind = proposed.generateMusic ? "music" : "sfx"
                if proposed.generateMusic { layer.spatial = false; layer.randomEvents = false }
            }
            layer.keyframes = points(proposed.points, duration: scene.duration)
            if let first = layer.keyframes.first { layer.position = first.position }
            return layer
        }
        let landscape: StudioLandscape
        switch plan.landscape {
        case .forest: landscape = .forest
        case .coast: landscape = .coast
        case .mountains: landscape = .mountains
        case .cabin: landscape = .cabin
        case .river: landscape = .river
        case .snow: landscape = .snow
        case .night: landscape = .night
        }
        scene.visuals = StudioVisuals(enabled: scene.visuals.enabled, landscape: landscape, rain: plan.rain, wind: plan.wind, daylight: plan.daylight, fog: plan.fog, fire: plan.fire, dawn: plan.dawn)
        let interpreted = MeditationComposition.scene(sounds: scene.layers.compactMap { $0.catalogID.flatMap(DriftCatalog.sound) }, volumes: [:])
        scene.visuals.actors = interpreted.visuals.actors
        scene.visuals.effects = interpreted.visuals.effects
        if interpreted.visuals.landscape.shaderIndex >= 7 { scene.visuals.landscape = interpreted.visuals.landscape }
        scene.visuals = StudioVisualPolicy.resolve(scene.visuals)
        scene.updated = Date(); try scene.validate(); return scene
    }
    private static func points(_ proposed: [DirectedPoint], duration: Double) -> [StudioKeyframe] {
        var seen = Set<Double>()
        return proposed.map { StudioKeyframe(time: min(duration, Double($0.time)), intensity: Float($0.intensity), position: .init(x: Float($0.x), z: Float($0.z))) }
            .filter { seen.insert($0.time).inserted }.sorted { $0.time < $1.time }
    }
}
#endif
