// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import SwiftUI

struct DriftSound: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let detail: String
    let category: String
    let icon: String
    let kind: String
    var asset: String?
    var sha256: String?
    var bytes: Int?
    var duration: Double?
    var crossfadeMs: Int?
    var color: String?
    var carrierHz: Double?
    var beatHz: Double?
    let licenseStatus: String
    let licenseId: String
}

enum DriftCatalog {
    static let sounds: [DriftSound] = {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let sounds = try? JSONDecoder().decode([DriftSound].self, from: data) else { return [] }
        return sounds
    }()
    static func sound(_ id: String) -> DriftSound? { sounds.first { $0.id == id } }
    static let categories: [(id: String, name: String, icon: String)] = [
        ("rain", "Rain", "cloud.rain"), ("nature", "Nature", "leaf"), ("animals", "Animals", "pawprint"),
        ("places", "Places", "mappin.and.ellipse"), ("things", "Things", "clock"),
        ("transport", "Transport", "tram"), ("urban", "Urban", "building.2"),
        ("noise", "Noise", "waveform"), ("binaural", "Binaural", "waveform.path")
    ]
    static func categoryName(_ id: String) -> String { categories.first { $0.id == id }?.name ?? "Sounds" }
}

enum DriftSort: String, Codable, CaseIterable, Identifiable {
    case recommended, alphabetical, type, usage
    var id: String { rawValue }
    var title: String {
        switch self {
        case .recommended: return "Recommended"
        case .alphabetical: return "Alphabetical"
        case .type: return "By type"
        case .usage: return "Most used"
        }
    }
}

struct DriftPreset: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var name: String
    var icon: String
    var selection: [String]
    var volumes: [String: Float]
    var master: Float
}

struct DriftConfiguration: Codable {
    var version = 1
    var selection: [String] = []
    var volumes: [String: Float] = [:]
    var master: Float = 0.35
    var favorites: Set<String> = []
    var presets: [DriftPreset] = []
    var usage: [String: Int] = [:]
    var presetUsage: [String: Int] = [:]
    var sort: DriftSort = .recommended
    var haptics = true
    var keepAwake = true
    var mixWithOtherAudio = false

    mutating func sanitize() {
        let known = Set(DriftCatalog.sounds.map(\.id))
        func safeSelection(_ values: [String]) -> [String] {
            var result: [String] = []
            var hasBinaural = false
            for id in values where known.contains(id) && !result.contains(id) {
                if DriftCatalog.sound(id)?.kind == "binaural" {
                    if hasBinaural { continue }
                    hasBinaural = true
                }
                result.append(id)
                if result.count == 6 { break }
            }
            return result
        }
        selection = safeSelection(selection)
        master = Self.clamp(master, fallback: 0.35)
        volumes = volumes.filter { known.contains($0.key) }.mapValues { Self.clamp($0, fallback: 0.25) }
        favorites = favorites.intersection(known)
        usage = usage.filter { known.contains($0.key) }.mapValues { max(0, $0) }
        var ids = Set<String>()
        presets = Array(presets.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && ids.insert($0.id).inserted }.prefix(48)).map {
            var preset = $0
            preset.name = String(preset.name.prefix(80))
            preset.selection = safeSelection(preset.selection)
            preset.master = Self.clamp(preset.master, fallback: 0.35)
            preset.volumes = preset.volumes.filter { known.contains($0.key) }.mapValues { Self.clamp($0, fallback: 0.25) }
            if !DriftStore.presetIcons.contains(preset.icon) { preset.icon = "headphones" }
            return preset
        }
        presetUsage = presetUsage.filter { ids.contains($0.key) }.mapValues { max(0, $0) }
    }
    static func clamp(_ value: Float, fallback: Float) -> Float { value.isFinite ? min(1, max(0, value)) : fallback }
}

@MainActor final class DriftStore: ObservableObject {
    @Published private(set) var config: DriftConfiguration
    @Published var notice: String?
    @Published var tab = 0
    @Published var immersive = false
    @Published private(set) var sleepDeadline: Date?
    @Published private(set) var remainingSeconds: Int?
    let audio = DriftAudioEngine()
    private let defaults: UserDefaults
    private var clock: Timer?
    nonisolated static let presetIcons = ["headphones", "book", "moon", "cloud.rain", "wind", "flame", "cup.and.saucer", "water.waves", "star"]
    var selection: [String] { config.selection }
    var activeSounds: [DriftSound] { selection.compactMap(DriftCatalog.sound) }
    var summary: String { activeSounds.map(\.name).joined(separator: " · ") }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") { defaults.removeObject(forKey: "drift.configuration.v1") }
        #endif
        if let data = defaults.data(forKey: "drift.configuration.v1"),
           var saved = try? JSONDecoder().decode(DriftConfiguration.self, from: data), saved.version == 1 {
            saved.sanitize(); config = saved
        } else { config = DriftConfiguration() }
        audio.didStartVoice = { [weak self] id in
            guard let self else { return }
            self.config.usage[id] = min(1_000_000, (self.config.usage[id] ?? 0) + 1)
            self.persist()
        }
        audio.didStop = { [weak self] in self?.setSleepTimer(minutes: nil) }
        audio.master = config.master
        audio.mixWithOtherAudio = config.mixWithOtherAudio
        audio.configure(sounds: activeSounds, volumes: config.volumes)
    }

    func persist() {
        if let data = try? JSONEncoder().encode(config) { defaults.set(data, forKey: "drift.configuration.v1") }
    }
    func volume(_ id: String) -> Float { config.volumes[id] ?? 0.25 }
    func toggle(_ id: String) {
        guard let sound = DriftCatalog.sound(id) else { return }
        if config.selection.contains(id) { remove(id); return }
        if sound.kind == "binaural", let previous = config.selection.first(where: { DriftCatalog.sound($0)?.kind == "binaural" }) {
            config.selection[config.selection.firstIndex(of: previous)!] = id
            audio.remove(previous)
        } else {
            guard config.selection.count < 6 else { notice = "Your mix holds up to 6 sounds. Remove one to make room."; return }
            config.selection.append(id)
        }
        persist(); feedback()
        // Selecting a sound starts the mix, as in the desktop experience.
        audio.play(sounds: activeSounds, volumes: config.volumes)
    }
    func remove(_ id: String) {
        config.selection.removeAll { $0 == id }; audio.remove(id); persist(); feedback()
        if selection.isEmpty { audio.pause(); setSleepTimer(minutes: nil) }
    }
    func togglePlayback() {
        if audio.playing { audio.pause() }
        else if !selection.isEmpty { audio.play(sounds: activeSounds, volumes: config.volumes) }
    }
    func clear() { audio.clear(); config.selection = []; setSleepTimer(minutes: nil); persist() }
    func setVolume(_ id: String, _ value: Float) {
        config.volumes[id] = DriftConfiguration.clamp(value, fallback: 0.25)
        audio.setVolume(id, volume(id)); persist()
    }
    func setMaster(_ value: Float) {
        config.master = DriftConfiguration.clamp(value, fallback: 0.35)
        audio.master = config.master; persist()
    }
    func favorite(_ id: String) {
        if config.favorites.contains(id) { config.favorites.remove(id) } else { config.favorites.insert(id) }
        persist(); feedback()
    }
    func setSort(_ sort: DriftSort) { config.sort = sort; persist() }
    func setPreference(_ key: WritableKeyPath<DriftConfiguration, Bool>, _ value: Bool) {
        config[keyPath: key] = value; persist()
        if key == \DriftConfiguration.mixWithOtherAudio {
            audio.mixWithOtherAudio = value
            if audio.playing { audio.reconfigureSession() }
        }
    }
    func save(name: String, icon: String, editing: String? = nil) {
        let cleanName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard !cleanName.isEmpty else { return }
        if let editing, let index = config.presets.firstIndex(where: { $0.id == editing }) {
            config.presets[index].name = cleanName; config.presets[index].icon = icon
        } else if !selection.isEmpty && config.presets.count < 48 {
            config.presets.append(DriftPreset(name: cleanName, icon: icon, selection: selection, volumes: config.volumes, master: config.master))
        }
        persist()
    }
    func deletePreset(_ id: String) { config.presets.removeAll { $0.id == id }; config.presetUsage[id] = nil; persist() }
    func load(_ preset: DriftPreset) {
        audio.pause(); setSleepTimer(minutes: nil)
        config.selection = preset.selection
        config.volumes.merge(preset.volumes) { _, new in new }
        config.master = preset.master; audio.master = preset.master
        config.presetUsage[preset.id] = min(1_000_000, (config.presetUsage[preset.id] ?? 0) + 1)
        config.sanitize(); audio.configure(sounds: activeSounds, volumes: config.volumes); persist(); tab = 1; feedback()
    }
    func sorted(_ sounds: [DriftSound]) -> [DriftSound] {
        sounds.sorted { a, b in
            switch config.sort {
            case .recommended: return DriftCatalog.sounds.firstIndex(of: a)! < DriftCatalog.sounds.firstIndex(of: b)!
            case .type:
                if a.category != b.category { return DriftCatalog.categoryName(a.category) < DriftCatalog.categoryName(b.category) }
            case .usage:
                if config.usage[a.id, default: 0] != config.usage[b.id, default: 0] { return config.usage[a.id, default: 0] > config.usage[b.id, default: 0] }
            case .alphabetical: break
            }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }
    func setSleepTimer(minutes: Int?) {
        clock?.invalidate(); clock = nil
        sleepDeadline = minutes.map { Date().addingTimeInterval(Double($0) * 60) }
        audio.sleepDeadline = sleepDeadline
        updateCountdown()
        if sleepDeadline != nil {
            clock = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.updateCountdown() }
            }
        }
    }
    func updateCountdown() {
        guard let deadline = sleepDeadline else { remainingSeconds = nil; return }
        let remaining = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
        remainingSeconds = remaining
        if remaining == 0 { audio.pause(); setSleepTimer(minutes: nil) }
    }
    func feedback() {
        if config.haptics { UISelectionFeedbackGenerator().selectionChanged() }
    }
}
