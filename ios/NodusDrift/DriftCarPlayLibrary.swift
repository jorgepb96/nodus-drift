// SPDX-License-Identifier: MIT
import Foundation
import Combine

extension DriftPreset {
    static let starters: [DriftPreset] = [
        .init(id: "rainy-pages", name: "Rainy pages", icon: "book", selection: ["light-rain", "brown-noise"], volumes: [:], master: 0.35),
        .init(id: "by-the-sea", name: "By the sea", icon: "water.waves", selection: ["waves", "seagulls"], volumes: [:], master: 0.35),
        .init(id: "nightfall", name: "Nightfall", icon: "moon", selection: ["crickets", "wind"], volumes: [:], master: 0.35)
    ]
}

struct DriftCarPlayEntry: Identifiable, Equatable {
    enum Source: Equatable { case mix(DriftPreset), scene(StudioScene) }
    let id: String
    let title: String
    let landscape: StudioLandscape
    let source: Source

    static func mix(_ preset: DriftPreset, prefix: String = "mix") -> Self {
        let sounds = preset.selection.compactMap(DriftCatalog.sound)
        return .init(id: "\(prefix):\(preset.id)", title: preset.name,
                     landscape: MeditationComposition.scene(sounds: sounds, volumes: preset.volumes).visuals.landscape,
                     source: .mix(preset))
    }
    static func scene(_ scene: StudioScene, id: String? = nil) -> Self {
        .init(id: id ?? "scene:\(scene.id.uuidString)", title: scene.name,
              landscape: scene.visuals.landscape, source: .scene(scene))
    }

    func isAvailable(recordings: URL = StudioLibrary.recordingsURL) -> Bool {
        switch source {
        case .mix(let preset):
            return !preset.selection.isEmpty && preset.selection.allSatisfy { DriftCatalog.sound($0) != nil }
        case .scene(let scene):
            guard (try? scene.validate()) != nil, scene.layers.contains(where: { !$0.muted }) else { return false }
            return scene.layers.allSatisfy { layer in
                guard !layer.muted, let recording = layer.recording else { return true }
                guard StudioScene.safeAudioName(recording.fileName),
                      let size = try? recordings.appendingPathComponent(recording.fileName).resourceValues(forKeys: [.fileSizeKey]).fileSize else { return false }
                return size == recording.bytes
            }
        }
    }
}

/// Resolves identifiers against the current library: deleted or edited scenes never
/// play an old snapshot kept by a CarPlay cell or recent-history record.
@MainActor final class DriftCarPlayLibrary: ObservableObject {
    let store: DriftStore
    let studio: StudioStore
    @Published private(set) var recentIDs: [String]
    private let defaults: UserDefaults
    private let recentKey = "drift.carplay.recents.v1"

    init(store: DriftStore, studio: StudioStore, defaults: UserDefaults = .standard) {
        self.store = store; self.studio = studio; self.defaults = defaults
        var seen = Set<String>()
        recentIDs = Array((defaults.stringArray(forKey: recentKey) ?? []).filter {
            $0.count <= 100 && seen.insert($0).inserted
        }.prefix(12))
    }
    var mixes: [DriftCarPlayEntry] { store.config.presets.map { .mix($0) } }
    var scenes: [DriftCarPlayEntry] { studio.saved.map { .scene($0) } }
    var explore: [DriftCarPlayEntry] {
        DriftPreset.starters.map { .mix($0, prefix: "starter-mix") } + StudioScene.starters.enumerated().map {
            .scene($0.element, id: "starter-scene:\($0.offset)")
        }
    }
    var recents: [DriftCarPlayEntry] { recentIDs.compactMap(resolve) }
    var current: DriftCarPlayEntry? {
        if store.audio.owner == .studio { return .scene(studio.scene, id: "current-scene") }
        guard !store.selection.isEmpty else { return nil }
        let preset = DriftPreset(id: "current", name: store.playbackName, icon: "headphones", selection: store.selection,
                                 volumes: store.config.volumes, master: store.config.master)
        return .mix(preset, prefix: "current")
    }
    func resolve(_ id: String) -> DriftCarPlayEntry? {
        if id == "current-scene" || id == "current:current" { return current?.id == id ? current : nil }
        return (mixes + scenes + explore).first { $0.id == id }
    }
    func play(_ id: String) throws {
        guard let entry = resolve(id), entry.isAvailable() else {
            throw StudioError.invalid("This soundscape is unavailable. Choose another from your library or Explore.")
        }
        guard !studio.generating else {
            throw StudioError.invalid("Audio creation is in progress. Try again when it finishes.")
        }
        let tab = store.tab
        switch entry.source {
        case .mix(let preset):
            if id != "current:current" { store.load(preset) }
            store.audio.play(sounds: store.activeSounds, volumes: store.config.volumes)
        case .scene(let value):
            if id != "current-scene" { studio.load(value) }
            studio.play()
        }
        store.tab = tab
        // Volatile current drafts remain available via Continue, not persistent recents.
        if !id.hasPrefix("current") {
            recentIDs.removeAll { $0 == id }; recentIDs.insert(id, at: 0)
            recentIDs = Array(recentIDs.prefix(12)); defaults.set(recentIDs, forKey: recentKey)
        }
    }
}
