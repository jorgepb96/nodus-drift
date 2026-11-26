import XCTest
import AVFoundation
import StableAudioMLX
import CryptoKit
@testable import NodusDrift

final class StudioTests: XCTestCase {
    @MainActor func testDisconnectedPlayerReturnsAnErrorWithoutAborting() {
        let audio = DriftAudioEngine()
        XCTAssertThrowsError(try audio.startPlayer(AVAudioPlayerNode())) { error in
            XCTAssertTrue(error is DriftAudioFailure)
        }
    }
    @MainActor func testAudioRecoversWhenEngineStopsDuringSourcePreparation() async throws {
        let audio = DriftAudioEngine(); defer { audio.pause(immediate: true) }
        audio.simulateEngineStopBeforePlayerStart = true
        let sound = DriftCatalog.sound("rain-on-window")!
        audio.play(sounds: [sound], volumes: [sound.id: 0.01], owner: .studio,
                   positions: [sound.id: .init(x: 0, z: -4)])
        try await Task.sleep(for: .seconds(2))
        XCTAssertFalse(audio.simulateEngineStopBeforePlayerStart, "The interrupted-start path must actually run")
        XCTAssertTrue(audio.playing); XCTAssertTrue(audio.errors.isEmpty)
        XCTAssertGreaterThan(audio.decodedBytes, 0)
    }
    @MainActor func testEveryStarterCanActuallyPlayAndSwitch() async throws {
        let audio = DriftAudioEngine()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { audio.pause(immediate: true); try? FileManager.default.removeItem(at: root) }
        let studio = StudioStore(audio: audio, library: StudioLibrary(root: root))
        for scene in StudioScene.starters {
            studio.load(scene); studio.play()
            try await Task.sleep(for: .seconds(3))
            XCTAssertTrue(studio.playing, scene.name)
            XCTAssertTrue(audio.errors.isEmpty, "\(scene.name): \(audio.errors)")
            XCTAssertGreaterThan(studio.time, 1, scene.name)
        }
    }
    @MainActor func testSimpleMixCanHandOffToEveryStudioStarterAndBack() async throws {
        let audio = DriftAudioEngine(); audio.master = 0
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { audio.pause(immediate: true); try? FileManager.default.removeItem(at: root) }
        let studio = StudioStore(audio: audio, library: StudioLibrary(root: root))
        let bed = ["campfire", "wind-in-trees", "walk-on-gravel", "rain-on-car-roof", "rain-on-umbrella", "brown-noise"].compactMap(DriftCatalog.sound)
        for scene in StudioScene.starters {
            audio.play(sounds: bed, volumes: Dictionary(uniqueKeysWithValues: bed.map { ($0.id, Float(0.01)) }))
            for _ in 0..<100 { if audio.activeVoiceCount == 6 || !audio.errors.isEmpty { break }; try await Task.sleep(for: .milliseconds(50)) }
            XCTAssertEqual(audio.activeVoiceCount, 6); XCTAssertTrue(audio.errors.isEmpty, "\(audio.errors)")
            studio.load(scene); studio.play()
            try await Task.sleep(for: .seconds(2))
            XCTAssertTrue(studio.playing); XCTAssertEqual(audio.owner, .studio)
            XCTAssertTrue(audio.errors.isEmpty, "\(scene.name): \(audio.errors)")
            XCTAssertGreaterThan(audio.activeVoiceCount, 0)
        }
    }
    func testStartersAreValidAndKeepIndependentLayerIdentities() throws {
        for scene in StudioScene.starters {
            try scene.validate()
            let copy = scene.duplicated()
            XCTAssertNotEqual(scene.id, copy.id)
            XCTAssertTrue(Set(scene.layers.map(\.id)).isDisjoint(with: copy.layers.map(\.id)))
            XCTAssertEqual(scene.layers.map(\.catalogID), copy.layers.map(\.catalogID))
        }
    }
    func testAutomationInterpolatesPositionAndGainWithFades() {
        let layer = StudioLayer(name: "Rain", catalogID: "light-rain", volume: 0.5, end: 60, fadeIn: 2, fadeOut: 2,
                                keyframes: [.init(time: 0, intensity: 0.2, position: .init(x: -4, z: -12)),
                                            .init(time: 40, intensity: 1, position: .init(x: 4, z: -2))])
        XCTAssertEqual(layer.evaluated(at: 0, seed: 1).gain, 0)
        let middle = layer.evaluated(at: 20, seed: 1)
        XCTAssertEqual(middle.gain, 0.3, accuracy: 0.0001)
        XCTAssertEqual(middle.position.x, 0, accuracy: 0.0001)
        XCTAssertEqual(middle.position.z, -7, accuracy: 0.0001)
        XCTAssertEqual(layer.evaluated(at: 59, seed: 1).gain, 0.25, accuracy: 0.0001)
        XCTAssertEqual(layer.evaluated(at: 60, seed: 1).gain, 0)
    }
    func testRandomEventsAreReproducibleSparseAndSeeded() {
        let layer = StudioLayer(name: "Thunder", catalogID: "thunder", end: 300, randomEvents: true)
        let schedule = (0..<3000).map { layer.eventOffset(at: Double($0) / 10, seed: 10) }
        XCTAssertEqual(schedule, (0..<3000).map { layer.eventOffset(at: Double($0) / 10, seed: 10) })
        XCTAssertNotEqual(schedule, (0..<3000).map { layer.eventOffset(at: Double($0) / 10, seed: 11) })
        let events = schedule.compactMap { $0 }
        XCTAssertFalse(events.isEmpty)
        XCTAssertLessThan(events.count, schedule.count / 3)
        XCTAssertTrue(events.allSatisfy { $0 >= 0 && $0 < layer.eventLength })
    }
    func testLocalSoundCheckAcceptsAnInstrumentalTone() throws {
        let samples = (0..<(44_100 * 4)).map { Float(sin(Double($0) * 2 * .pi * 220 / 44_100)) * 0.03 }
        XCTAssertNoThrow(try StudioAudioQuality.checkForVoices([samples, samples], sampleRate: 44_100))
        XCTAssertEqual(StudioRole.infer("train"), .other)
        XCTAssertEqual(StudioRole.infer("rain-on-window"), .rain)
    }
    func testArchiveRoundTripAndRejectsUnknownSourcesVersionsAndPaths() throws {
        let scene = StudioScene.starters[0]
        let data = try JSONEncoder().encode(StudioArchive(scene: scene))
        XCTAssertEqual(try StudioArchive.decode(data).scene, scene)
        var invalid = scene; invalid.version = 2
        XCTAssertThrowsError(try StudioArchive.decode(JSONEncoder().encode(StudioArchive(scene: invalid))))
        invalid = scene; invalid.layers[0].catalogID = "nonexistent"
        XCTAssertThrowsError(try invalid.validate())
        invalid = scene; invalid.layers[0].volume = .nan
        XCTAssertThrowsError(try invalid.validate())
        invalid = scene; invalid.layers[0].end = 3601
        XCTAssertThrowsError(try invalid.validate())
        XCTAssertFalse(StudioScene.safeAudioName("../private.m4a"))
        XCTAssertFalse(StudioScene.safeAudioName("anything.m4a"))
        XCTAssertTrue(StudioScene.safeAudioName(UUID().uuidString + ".m4a"))
        XCTAssertThrowsError(try StudioArchive.decode(JSONEncoder().encode(StudioArchive(scene: scene, recordings: ["unexpected.m4a": Data([1])]))))
    }
    func testLibraryPersistsDraftAndSavedScenesIndependently() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = StudioLibrary(root: root)
        let saved = StudioScene.starters[0], draft = StudioScene.starters[1]
        try library.save([saved]); try library.saveDraft(draft)
        XCTAssertEqual(try library.load(), [saved]); XCTAssertEqual(try library.loadDraft(), draft)
        XCTAssertEqual(try library.export(saved).scene, saved)
    }
    func testPortableRecordingImportRemapsFilesAndRejectsTampering() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = StudioLibrary(root: root); try library.prepare()
        let fileName = UUID().uuidString.lowercased() + ".m4a"
        let url = library.recordings.appendingPathComponent(fileName)
        let channels = (0..<2).map { _ in (0..<44_100).map { Float(sin(Double($0) * 2 * .pi * 220 / 44_100)) * 0.02 } }
        _ = try SA3Audio.writeAAC(channels, sampleRate: 44_100, bitRate: 112_000, to: url)
        let data = try Data(contentsOf: url)
        let recording = StudioRecording(fileName: fileName, sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), bytes: data.count,
                                        seconds: 1, prompt: "Test sound", model: "sfx", seed: 1, revision: "test")
        var scene = StudioScene(); scene.layers = [StudioLayer(name: "Generated rain", recording: recording)]
        let archive = try library.export(scene)
        let imported = try library.importArchive(archive)
        XCTAssertNotEqual(imported.id, scene.id)
        XCTAssertNotEqual(imported.layers[0].recording?.fileName, fileName)
        XCTAssertEqual(imported.layers[0].recording?.sha256, recording.sha256)
        let remapped = library.recordings.appendingPathComponent(imported.layers[0].recording!.fileName)
        XCTAssertEqual(try Data(contentsOf: remapped), data)
        var tampered = archive; tampered.recordings[fileName] = Data([0, 1, 2])
        XCTAssertThrowsError(try library.importArchive(tampered))
        XCTAssertEqual(try Data(contentsOf: url), data, "A failed import cannot overwrite existing audio")
    }
    @MainActor func testStudioSpatialMixReroutesSixConcurrentSources() async throws {
        let audio = DriftAudioEngine(); audio.master = 0
        let ids = ["light-rain", "wind", "river", "campfire", "birds", "thunder"]
        let sounds = ids.compactMap(DriftCatalog.sound)
        let positions = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($0.element, StudioPosition(x: Float($0.offset) - 3, z: -5)) })
        audio.play(sounds: sounds, volumes: Dictionary(uniqueKeysWithValues: ids.map { ($0, Float(0.1)) }), owner: .studio, positions: positions)
        defer { audio.pause(immediate: true) }
        for _ in 0..<100 { if audio.activeVoiceCount == 6 || !audio.errors.isEmpty { break }; try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertTrue(audio.errors.isEmpty, "\(audio.errors)")
        XCTAssertEqual(audio.activeVoiceCount, 6)
        var stereo = positions; stereo["birds"] = nil
        audio.synchronizeStudio(sounds: sounds, volumes: [:], positions: stereo)
        for _ in 0..<30 { if audio.activeVoiceCount == 6 { break }; try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertEqual(audio.activeVoiceCount, 6)
        XCTAssertTrue(audio.errors.isEmpty)
    }
    @MainActor func testRemovingAndRestoringStudioLayersCompletesItsFade() async throws {
        let audio = DriftAudioEngine(); audio.master = 0
        defer { audio.pause(immediate: true) }
        let sounds = [DriftCatalog.sound("light-rain")!, DriftCatalog.sound("wind")!]
        let gains: [String: Float] = ["light-rain": 0.1, "wind": 0.1]
        audio.play(sounds: sounds, volumes: gains, owner: .studio)
        for _ in 0..<50 { if audio.activeVoiceCount == 2 { break }; try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertEqual(audio.activeVoiceCount, 2)
        // Repeated transport updates must not keep restarting the removal fade.
        for _ in 0..<6 {
            audio.synchronizeStudio(sounds: [sounds[0]], volumes: gains, positions: [:])
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertEqual(audio.activeVoiceCount, 1)
        audio.synchronizeStudio(sounds: sounds, volumes: gains, positions: [:])
        for _ in 0..<30 { if audio.activeVoiceCount == 2 { break }; try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertEqual(audio.activeVoiceCount, 2)
    }
    @MainActor func testGenerationPromptsAreBriefInstrumentalAndSimulatorSafe() async throws {
        let music = StudioGenerator.optimizedPrompt("Gentle piano", kind: .music)
        XCTAssertTrue(music.contains("VocalType: Instrumental"))
        XCTAssertTrue(music.contains("No voices"))
        XCTAssertLessThan(StudioGenerator.optimizedPrompt(String(repeating: "rain ", count: 400), kind: .sfx).count, 500)
        #if targetEnvironment(simulator)
        XCTAssertFalse(SA3Engine.isSupported)
        let generator = StudioGenerator()
        do { _ = try await generator.render(prompt: "rain", kind: .sfx, seconds: 5); XCTFail("Simulator must reject inference before touching MLX") }
        catch { XCTAssertTrue(error.localizedDescription.contains("real iPhone")) }
        #endif
    }
    @MainActor func testStudioDoesNotModifyLegacySavedMixes() throws {
        let name = UUID().uuidString, defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let drift = DriftStore(defaults: defaults)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let studio = StudioStore(audio: drift.audio, library: StudioLibrary(root: root))
        let legacy = try JSONEncoder().encode(drift.config)
        studio.create(); studio.add(DriftCatalog.sound("light-rain")!); studio.save()
        XCTAssertEqual(drift.config.selection, [])
        XCTAssertEqual(drift.config.presets, [])
        XCTAssertEqual(try JSONDecoder().decode(DriftConfiguration.self, from: legacy).selection, drift.config.selection)
        XCTAssertEqual(studio.saved.count, 1)
        XCTAssertEqual(try StudioLibrary(root: root).load().count, 1)
    }
    @MainActor func testSwitchingBackToSimpleMixRestoresItsMasterVolume() {
        let name = UUID().uuidString, defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let drift = DriftStore(defaults: defaults)
        defer { drift.audio.pause(immediate: true) }
        drift.load(DriftPreset(name: "Quiet rain", icon: "cloud.rain", selection: ["light-rain"], volumes: ["light-rain": 0], master: 0.15))
        drift.audio.master = 0.8
        drift.audio.play(sounds: [DriftCatalog.sound("wind")!], volumes: ["wind": 0], owner: .studio)
        drift.togglePlayback()
        XCTAssertEqual(drift.audio.owner, .listen)
        XCTAssertTrue(drift.audio.listening)
        XCTAssertEqual(drift.audio.master, 0.15, accuracy: 0.0001)
    }
}
