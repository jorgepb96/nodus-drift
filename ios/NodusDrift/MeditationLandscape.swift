// SPDX-License-Identifier: MIT
import Foundation
import SwiftUI

enum MeditationAppearance: String, Codable, CaseIterable, Identifiable {
    case landscape, nodi
    var id: String { rawValue }
    var title: String { self == .landscape ? "Your landscape" : "Nodi" }
}

/// A visual interpretation of the existing mix; never starts a second audio engine.
enum MeditationComposition {
    static func scene(sounds: [DriftSound], volumes: [String: Float]) -> StudioScene {
        let audible = sounds.filter { (volumes[$0.id] ?? 0.25) > 0.0001 }
        let ids = Set(audible.map(\.id))
        let night = !ids.isDisjoint(with: ["crickets", "owl", "wolf"])
        let fire = ids.contains("campfire")
        let rain = audible.contains { $0.category == "rain" }
        let wind = !ids.isDisjoint(with: ["wind", "howling-wind", "wind-in-trees"])
        let landscape: StudioLandscape
        if ids.contains("walk-in-snow") { landscape = .snow }
        else if !ids.isDisjoint(with: ["rain-on-car-roof", "windshield-wipers"]) { landscape = .car }
        else if ids.contains("rain-on-tent") { landscape = .tent }
        else if !ids.isDisjoint(with: ["laundry-room", "washing-machine", "dryer"]) { landscape = .utility }
        else if ids.contains("supermarket") { landscape = .market }
        else if ids.contains("construction-site") { landscape = .construction }
        else if ids.contains("laboratory") { landscape = .laboratory }
        else if ids.contains("library") { landscape = .library }
        else if ids.contains("carousel") { landscape = .fairground }
        else if !ids.isDisjoint(with: ["underwater", "submarine", "whale", "bubbles"]) { landscape = .underwater }
        else if !ids.isDisjoint(with: ["train", "inside-a-train", "subway-station"]) { landscape = .train }
        else if !ids.isDisjoint(with: ["airport", "airplane"]) { landscape = .airport }
        else if !ids.isDisjoint(with: ["cafe", "restaurant", "crowded-bar"]) { landscape = .cafe }
        else if !ids.isDisjoint(with: ["church", "temple", "singing-bowl"]) { landscape = .sanctuary }
        else if audible.contains(where: { $0.category == "urban" }) || ids.contains("night-village") { landscape = .city }
        else if !ids.isDisjoint(with: ["waves", "seagulls", "sailboat", "rowing-boat"]) { landscape = .coast }
        else if !ids.isDisjoint(with: ["river", "waterfall", "droplets", "frog"]) { landscape = .river }
        else if fire || ids.contains("rain-on-window") { landscape = .cabin }
        else if audible.contains(where: { $0.category == "things" || $0.category == "places" }) { landscape = .room }
        else { landscape = ids.contains("binaural-delta") ? .night : .forest }
        var scene = StudioScene(name: "Your soundscape", seed: 20261107)
        scene.duration = 3600
        scene.layers = sounds.map { sound in
            StudioLayer(name: sound.name, catalogID: sound.id, volume: volumes[sound.id] ?? 0.25,
                        spatial: false, end: 3600, fadeIn: 0, fadeOut: 0,
                        randomEvents: sound.id == "thunder")
        }
        scene.visuals = StudioVisuals(landscape: landscape,
                                     rain: rain ? (ids.contains("heavy-rain") ? 1 : 0.7) : (landscape == .snow ? 0.4 : 0),
                                     wind: wind ? (ids.contains("howling-wind") ? 0.9 : 0.55) : 0.12,
                                     daylight: night || ids.contains("night-village") ? 0.08 : 0.4,
                                     fog: rain ? 0.4 : 0.16, fire: fire, stars: night && !landscape.isInterior)
        let animals = ["birds", "seagulls", "crickets", "wolf", "owl", "frog", "dog-barking", "horse-gallop",
                       "cat-purring", "crows", "whale", "beehive", "woodpecker", "chickens", "cows", "sheep"]
        let props = ["clock", "keyboard", "typewriter", "paper", "wind-chimes", "singing-bowl", "ceiling-fan", "slide-projector",
                     "boiling-water", "tuning-radio", "vinyl-effect", "washing-machine", "dryer", "morse-code", "rain-on-umbrella", "rain-on-tent"]
        var actors: [StudioVisualActor] = []
        var effects: [StudioVisualEffect] = []
        func effect(_ value: StudioVisualEffect) { if !effects.contains(value) { effects.append(value) } }
        for sound in audible {
            let id = sound.id
            if let tile = animals.firstIndex(of: id) {
                let flying = id == "seagulls"
                let perched = ["birds", "owl", "crows", "woodpecker", "beehive"].contains(id)
                let pet = ["dog-barking", "cat-purring"].contains(id)
                let number = actors.filter { $0.atlas == .animals }.count
                var x: Float = number % 2 == 0 ? 0.65 : 0.36
                var y: Float = perched ? 0.48 : 0.76
                var width: Float = ["crickets", "frog"].contains(id) ? 0.12 : (perched ? 0.17 : 0.25)
                if landscape.isInterior && !pet { x = 0.65; y = landscape == .car ? 0.54 : 0.49; width *= 0.65 }
                if flying { y = 0.39; width = 0.18 }
                if id == "whale" { x = 0.52; y = 0.59; width = 0.48 }
                actors.append(.init(sourceID: id, atlas: .animals, tile: tile, x: x, y: y, width: width))
            } else if let tile = props.firstIndex(of: id), id != "rain-on-tent" {
                let wall = ["clock", "wind-chimes", "ceiling-fan"].contains(id)
                let number = actors.filter { $0.atlas == .props }.count
                let x: Float = wall ? 0.22 : (number % 2 == 0 ? 0.66 : 0.34)
                let y: Float = wall ? 0.38 : (landscape == .utility ? 0.96 : 0.88 - Float(number / 2) * 0.1)
                actors.append(.init(sourceID: id, atlas: .props, tile: tile, x: x, y: y,
                                    width: id == "rain-on-umbrella" ? 0.48 : (wall ? 0.19 : (landscape == .utility ? 0.32 : 0.28))))
            }
            if id == "laundry-room" {
                actors.append(.init(sourceID: id, atlas: .props, tile: 11, x: 0.34, y: 0.96, width: 0.32))
                actors.append(.init(sourceID: id, atlas: .props, tile: 12, x: 0.67, y: 0.96, width: 0.32))
            }
            switch id {
            case "walk-in-snow": effect(.snowTracks)
            case "walk-on-leaves": effect(.leafTracks)
            case "walk-on-gravel": effect(.gravelTracks)
            case "windshield-wipers": effect(.wipers); effect(.glassRain)
            case "rain-on-car-roof", "rain-on-window": effect(.glassRain)
            case "bubbles", "underwater", "submarine": effect(.bubbles)
            case "boiling-water", "cafe", "laundry-room": effect(.steam)
            case "fireworks": effect(.fireworks)
            case "road", "highway", "traffic", "ambulance-siren", "busy-street": effect(.traffic)
            case "crowd", "crowded-bar", "airport", "supermarket", "carousel": effect(.crowd)
            case "waterfall": effect(.waterfall)
            case "river", "waves", "droplets", "sailboat", "rowing-boat": effect(.ripples)
            case "ceiling-fan": effect(.fan)
            case "tuning-radio", "morse-code", "slide-projector", "laboratory": effect(.signal)
            default: if ["noise", "binaural"].contains(sound.category) { effect(.signal) }
            }
        }
        scene.visuals.actors = Array(actors.prefix(12))
        scene.visuals.effects = effects
        scene.visuals = StudioVisualPolicy.resolve(scene.visuals)
        return scene
    }
}

struct MeditationAppearancePicker: View {
    @EnvironmentObject private var store: DriftStore
    var identifier = "meditation-appearance"
    var body: some View {
        HStack(spacing: 4) {
            ForEach(MeditationAppearance.allCases) { appearance in
                Button {
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { store.setMeditationAppearance(appearance) }
                } label: {
                    Text(appearance.title).font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(store.meditationAppearance == appearance ? DriftTheme.accent : DriftTheme.muted)
                        .background(store.meditationAppearance == appearance ? DriftTheme.accent.opacity(0.14) : .clear,
                                    in: RoundedRectangle(cornerRadius: 10))
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityIdentifier("\(identifier)-\(appearance.rawValue)")
                    .accessibilityAddTraits(store.meditationAppearance == appearance ? .isSelected : [])
            }
        }.padding(4).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .contain).accessibilityLabel("Meditation visual")
            .accessibilityIdentifier(identifier)
    }
}
