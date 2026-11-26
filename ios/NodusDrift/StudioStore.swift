// SPDX-License-Identifier: MIT
import SwiftUI
import Combine
import StableAudioMLX

@MainActor final class StudioStore: ObservableObject {
    @Published var scene: StudioScene
    @Published private(set) var saved: [StudioScene] = []
    @Published private(set) var time: Double = 0
    @Published private(set) var playing = false
    @Published var notice: String?
    @Published var immersive = false
    @Published var generationProgress = ""
    @Published private(set) var generating = false
    let audio: DriftAudioEngine
    let generator = StudioGenerator()
    let director = StudioDirector()
    private let library: StudioLibrary
    private var clock: Timer?
    private var anchor: Double?
    private var anchorTime: Double = 0
    private var previousCycle = 0
    private var playbackObservation: AnyCancellable?
    private var generatorObservation: AnyCancellable?
    private var errorObservation: AnyCancellable?
    private var generationTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var draftSave: Task<Void, Never>?

    init(audio: DriftAudioEngine, library: StudioLibrary = StudioLibrary()) {
        self.audio = audio; self.library = library
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") && ProcessInfo.processInfo.arguments.contains("-ui-testing-studio-reset") {
            try? FileManager.default.removeItem(at: library.root)
        }
        #endif
        scene = StudioScene.starters[0]
        do { saved = try library.load(); if let draft = try library.loadDraft() { scene = draft } }
        catch { notice = "Your previous scene could not be opened: \(error.localizedDescription)" }
        playbackObservation = audio.$playing.dropFirst().sink { [weak self] active in
            guard let self else { return }
            if active && self.audio.owner == .studio { self.beginClock() }
            else { self.freezeClock() }
        }
        generatorObservation = generator.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
        errorObservation = audio.$errors.dropFirst().sink { [weak self] errors in
            guard let self, self.audio.owner == .studio, let message = errors.values.first else { return }
            self.notice = message
        }
        audio.didRequestStudioPlayback = { [weak self] in self?.play() }
        for name in [UIApplication.didEnterBackgroundNotification, UIApplication.didReceiveMemoryWarningNotification,
                     ProcessInfo.thermalStateDidChangeNotification, NSNotification.Name.NSProcessInfoPowerStateDidChange] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] event in
                Task { @MainActor in
                    if event.name == UIApplication.didEnterBackgroundNotification { self?.flushDraft() }
                    if event.name == UIApplication.didEnterBackgroundNotification || event.name == UIApplication.didReceiveMemoryWarningNotification ||
                        ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue || ProcessInfo.processInfo.isLowPowerModeEnabled {
                        self?.cancelGeneration()
                    }
                }
            })
        }
    }
    deinit { clock?.invalidate(); observers.forEach(NotificationCenter.default.removeObserver); generationTask?.cancel(); draftSave?.cancel() }

    func changed() {
        scene.updated = Date()
        draftSave?.cancel()
        draftSave = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard let self, !Task.isCancelled else { return }
            // A name can briefly be empty while the user is editing it.
            guard (try? self.scene.validate()) != nil else { return }
            do {
                try self.library.saveDraft(self.scene)
                if !self.generating { self.library.removeUnusedRecordings(scenes: self.saved, draft: self.scene) }
            } catch { self.notice = error.localizedDescription }
        }
        if playing { synchronize() }
    }
    func flushDraft() {
        draftSave?.cancel()
        guard (try? scene.validate()) != nil else { return }
        do { try library.saveDraft(scene) } catch { notice = error.localizedDescription }
    }
    func load(_ value: StudioScene) {
        cancelGeneration(); pause(); scene = value; time = 0; changed()
    }
    func create() { load(StudioScene()) }
    func save() {
        do {
            try scene.validate()
            var list = saved
            if let index = list.firstIndex(where: { $0.id == scene.id }) { list[index] = scene }
            else { list.insert(scene, at: 0) }
            try library.save(list); saved = list; changed(); notice = "Scene saved on this device."
        } catch { notice = error.localizedDescription }
    }
    func duplicate(_ value: StudioScene) {
        let copy = value.duplicated()
        do { let list = [copy] + saved; try library.save(list); saved = list; load(copy) }
        catch { notice = error.localizedDescription }
    }
    func delete(_ value: StudioScene) {
        do {
            let list = saved.filter { $0.id != value.id }; try library.save(list); saved = list
            library.removeUnusedRecordings(scenes: saved, draft: scene)
        } catch { notice = error.localizedDescription }
    }
    func archive() throws -> StudioArchive { try library.export(scene) }
    func importScene(from url: URL) throws {
        guard !generating else { throw StudioError.invalid("Wait for generation to finish before importing.") }
        let accessed = url.startAccessingSecurityScopedResource(); defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
        guard size <= StudioScene.maximumArchiveBytes else { throw StudioError.invalid("This scene exceeds the 96 MB import limit.") }
        let archive = try StudioArchive.decode(Data(contentsOf: url))
        guard saved.count < 96 else { throw StudioError.invalid("Your library holds up to 96 scenes.") }
        let imported = try library.importArchive(archive)
        try library.save([imported] + saved); saved.insert(imported, at: 0); load(imported)
    }
    func add(_ sound: DriftSound) {
        guard scene.layers.count < StudioScene.maximumLayers else { notice = "A scene holds up to 12 layers."; return }
        if sound.kind == "binaural", scene.layers.contains(where: { $0.catalogID.flatMap(DriftCatalog.sound)?.kind == "binaural" }) {
            notice = "Use one binaural layer at a time."; return
        }
        scene.layers.append(StudioLayer(name: sound.name, catalogID: sound.id, spatial: sound.kind != "binaural", end: scene.duration))
        changed()
    }
    func removeLayer(_ id: UUID) { scene.layers.removeAll { $0.id == id }; changed() }
    func togglePlayback() { playing ? pause() : play() }
    func play() {
        guard !scene.layers.isEmpty else { notice = "Add a sound to start your scene."; return }
        do { try scene.validate() } catch { notice = error.localizedDescription; return }
        if time >= scene.duration { time = 0 }
        for layer in scene.layers where audio.errors[layer.id.uuidString] != nil { audio.retry(layer.id.uuidString) }
        let mix = evaluatedMix()
        // Start with all non-muted sources if the first frame is an intentional fade-in.
        let sounds = mix.sounds.isEmpty ? scene.layers.filter { !$0.muted }.compactMap(sourceSound) : mix.sounds
        audio.master = scene.master
        audio.play(sounds: sounds, volumes: mix.volumes, owner: .studio, positions: mix.positions)
    }
    func pause() { if audio.owner == .studio { audio.pause() }; freezeClock() }
    func seek(_ value: Double) {
        let wasPlaying = playing
        if wasPlaying { audio.pause(immediate: true) }
        time = min(scene.duration, max(0, value)); previousCycle = 0
        if wasPlaying { play() }
    }
    func setDuration(_ duration: Double) {
        let old = scene.duration; scene.duration = min(3600, max(10, duration))
        for index in scene.layers.indices {
            if scene.layers[index].end == old || scene.layers[index].end > scene.duration { scene.layers[index].end = scene.duration }
            scene.layers[index].start = min(scene.layers[index].start, scene.layers[index].end - 0.5)
            scene.layers[index].keyframes.removeAll { $0.time > scene.duration }
        }
        if time > scene.duration { seek(0) }; changed()
    }
    private func beginClock() {
        guard !playing else { return }
        playing = true; anchor = ProcessInfo.processInfo.systemUptime; anchorTime = time; previousCycle = 0
        clock?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
        RunLoop.main.add(timer, forMode: .common); clock = timer
    }
    private func freezeClock() {
        if let anchor, playing { time = min(scene.duration, (anchorTime + ProcessInfo.processInfo.systemUptime - anchor).truncatingRemainder(dividingBy: scene.duration)) }
        playing = false; anchor = nil; clock?.invalidate(); clock = nil
    }
    private func tick() {
        guard let anchor, playing, audio.owner == .studio else { freezeClock(); return }
        let elapsed = anchorTime + ProcessInfo.processInfo.systemUptime - anchor
        if elapsed >= scene.duration && !scene.repeats { pause(); time = scene.duration; return }
        let cycle = Int(elapsed / scene.duration)
        if cycle != previousCycle { previousCycle = cycle; audio.resetStudioCycle() }
        time = elapsed.truncatingRemainder(dividingBy: scene.duration); synchronize()
    }
    private func synchronize() {
        let mix = evaluatedMix(); if audio.master != scene.master { audio.master = scene.master }
        audio.synchronizeStudio(sounds: mix.sounds, volumes: mix.volumes, positions: mix.positions)
    }
    private func evaluatedMix() -> (sounds: [DriftSound], volumes: [String: Float], positions: [String: StudioPosition]) {
        var sounds: [DriftSound] = [], volumes: [String: Float] = [:], positions: [String: StudioPosition] = [:]
        for (index, layer) in scene.layers.enumerated() {
            let state = layer.evaluated(at: time, seed: scene.seed &+ UInt64(index * 7919))
            let id = layer.id.uuidString
            // Bed layers stay attached during fades; random events start a fresh recording.
            if !layer.muted && time >= layer.start && time < layer.end && (!layer.randomEvents || state.gain > 0.0001), let sound = sourceSound(layer) { sounds.append(sound) }
            volumes[id] = state.gain
            if layer.spatial && !layer.isMusic && layer.catalogID.flatMap(DriftCatalog.sound)?.kind != "binaural" { positions[id] = state.position }
        }
        return (sounds, volumes, positions)
    }
    private func sourceSound(_ layer: StudioLayer) -> DriftSound? {
        if let id = layer.catalogID, var sound = DriftCatalog.sound(id) {
            sound.id = layer.id.uuidString
            if layer.randomEvents && sound.kind == "file" {
                sound.oneShot = true
                let width = layer.eventGap * 1.6 + layer.eventLength
                let bucket = UInt64(max(0, floor((time - layer.start) / width)))
                let index = scene.layers.firstIndex(where: { $0.id == layer.id }) ?? 0
                sound.startOffsetSeconds = StudioScene.random(scene.seed &+ UInt64(index * 7919) &+ bucket) * max(0, (sound.duration ?? 10) - layer.eventLength)
            }
            return sound
        }
        guard let recording = layer.recording else { return nil }
        var sound = DriftSound(id: layer.id.uuidString, name: layer.name, detail: "Generated locally", category: "studio", icon: layer.icon, kind: "file",
                          sha256: recording.sha256, bytes: recording.bytes, duration: recording.seconds, crossfadeMs: layer.isMusic ? 0 : 500,
                          licenseStatus: "generated", licenseId: "Stability-AI-Community", localFileName: recording.fileName, oneShot: layer.isMusic,
                          startOffsetSeconds: layer.isMusic ? max(0, time - layer.start) : nil)
        if layer.randomEvents {
            let bucket = UInt64(max(0, floor((time - layer.start) / (layer.eventGap * 1.6 + layer.eventLength))))
            let index = scene.layers.firstIndex(where: { $0.id == layer.id }) ?? 0
            sound.oneShot = true
            sound.startOffsetSeconds = StudioScene.random(scene.seed &+ UInt64(index * 7919) &+ bucket) * max(0, recording.seconds - layer.eventLength)
        }
        return sound
    }
    func generate(prompt: String, kind: SA3ModelKind, seconds: Double, replacing layerID: UUID? = nil,
                  continuing: Bool = false, repair: ClosedRange<Double>? = nil) {
        guard !generating, !director.busy else { return }
        guard layerID != nil || scene.layers.count < StudioScene.maximumLayers else { notice = "Make room for another layer first."; return }
        let sceneID = scene.id
        let source = layerID.flatMap { id in scene.layers.first { $0.id == id }?.recording }
        var keep: [ClosedRange<Double>] = []
        if continuing, let source { keep = [0...max(0, source.seconds - 2)] }
        if let repair, let source {
            if repair.lowerBound > 0 { keep.append(0...repair.lowerBound) }
            if repair.upperBound < source.seconds { keep.append(repair.upperBound...source.seconds) }
        }
        generating = true
        generationTask = Task { [weak self] in
            guard let self else { return }
            defer { self.generating = false; self.generationTask = nil }
            do {
                let recording = try await self.generator.render(prompt: prompt, kind: kind, seconds: seconds, source: source, keep: keep)
                guard !Task.isCancelled, self.scene.id == sceneID else {
                    try? FileManager.default.removeItem(at: StudioLibrary.recordingsURL.appendingPathComponent(recording.fileName)); return
                }
                // Give a regenerated layer a fresh playback identity; the old file stays in saved scenes.
                if let layerID, let index = self.scene.layers.firstIndex(where: { $0.id == layerID }) {
                    self.scene.layers[index].role = self.scene.layers[index].visualRole
                    self.scene.layers[index].recording = recording; self.scene.layers[index].catalogID = nil
                    self.scene.layers[index].requestedPrompt = nil; self.scene.layers[index].requestedKind = nil
                    self.scene.layers[index].id = UUID()
                    if kind == .music { self.scene.layers[index].end = min(self.scene.duration, self.scene.layers[index].start + recording.seconds) }
                } else if layerID == nil && self.scene.layers.count < StudioScene.maximumLayers {
                    self.scene.layers.append(StudioLayer(name: String(prompt.prefix(60)), recording: recording, spatial: kind != .music,
                                                         end: kind == .music ? min(self.scene.duration, recording.seconds) : self.scene.duration))
                } else {
                    try? FileManager.default.removeItem(at: StudioLibrary.recordingsURL.appendingPathComponent(recording.fileName))
                    self.notice = "The layer changed while generating. Make room and try again."; return
                }
                self.changed()
            } catch { if !Task.isCancelled { self.notice = error.localizedDescription } }
        }
    }
    func cancelGeneration() { generationTask?.cancel() }
    func generateSceneAudio(onlyRequests: Bool = false, automatic: Bool = false) {
        guard !generating, !director.busy, !scene.layers.isEmpty else { return }
        let sceneID = scene.id
        let layers = scene.layers.filter { layer in
            !onlyRequests || (layer.requestedPrompt != nil && generator.models.installed.contains(SA3ModelKind(rawValue: layer.requestedKind ?? "sfx") ?? .sfx))
        }
        guard !layers.isEmpty else {
            if !automatic { notice = "Download the matching models in Models & licenses to create the suggested recordings." }
            return
        }
        generating = true
        generationTask = Task { [weak self] in
            guard let self else { return }
            defer { self.generating = false; self.generationTask = nil }
            do {
                for layer in layers {
                    try Task.checkCancellation()
                    guard self.scene.layers.contains(where: { $0.id == layer.id }) else { continue }
                    let kind = SA3ModelKind(rawValue: layer.requestedKind ?? "") ?? (layer.isMusic ? .music : .sfx)
                    let catalogSound = layer.catalogID.flatMap(DriftCatalog.sound)
                    let prompt = layer.requestedPrompt ?? layer.recording?.prompt ?? "\(catalogSound?.name ?? layer.name), \(catalogSound?.detail ?? "steady natural ambience")"
                    self.generationProgress = "Creating \(layer.name)…"
                    let recording = try await self.generator.render(prompt: prompt, kind: kind, seconds: kind == .music ? 60 : 20)
                    guard !Task.isCancelled, self.scene.id == sceneID else {
                        try? FileManager.default.removeItem(at: StudioLibrary.recordingsURL.appendingPathComponent(recording.fileName)); return
                    }
                    if let index = self.scene.layers.firstIndex(where: { $0.id == layer.id }) {
                        self.scene.layers[index].role = self.scene.layers[index].visualRole
                        self.scene.layers[index].recording = recording; self.scene.layers[index].catalogID = nil; self.scene.layers[index].id = UUID()
                        self.scene.layers[index].requestedPrompt = nil; self.scene.layers[index].requestedKind = nil
                        if kind == .music { self.scene.layers[index].end = min(self.scene.duration, layer.start + recording.seconds) }
                        self.changed()
                    } else {
                        try? FileManager.default.removeItem(at: StudioLibrary.recordingsURL.appendingPathComponent(recording.fileName))
                    }
                    // Return control between pieces; the next admission check stops if the device is too hot.
                    try await Task.sleep(for: .seconds(ProcessInfo.processInfo.thermalState == .fair ? 8 : 2))
                }
            } catch { if !Task.isCancelled { self.notice = "Scene generation stopped: \(error.localizedDescription). Completed layers are kept." } }
        }
    }
    func direct(_ instruction: String, modifying: Bool) async {
        guard !generating else { return }
        do {
            let result = try await director.create(instruction: instruction, current: modifying ? scene : nil)
            load(result)
            generateSceneAudio(onlyRequests: true, automatic: true)
        } catch { notice = error.localizedDescription }
    }
}
