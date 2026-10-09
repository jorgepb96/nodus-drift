import XCTest
import AVFoundation
import UIKit
@testable import NodusDrift

final class DriftTests: XCTestCase {
    func testCatalogAndEveryBundledRecording() throws {
        XCTAssertEqual(DriftCatalog.sounds.count, 89)
        XCTAssertEqual(Set(DriftCatalog.sounds.map(\.id)).count, 89)
        XCTAssertEqual(DriftCatalog.sounds.filter { $0.kind == "file" }.count, 81)
        for sound in DriftCatalog.sounds {
            XCTAssertNotNil(UIImage(systemName: sound.icon), "Unknown symbol for \(sound.id)")
            XCTAssertFalse(sound.name.isEmpty)
            if sound.kind == "file" {
                try autoreleasepool {
                    let buffer = try DriftAudioEngine.decode(sound, budget: 192 * 1024 * 1024)
                    XCTAssertGreaterThan(buffer.frameLength, 0, sound.id)
                    XCTAssertLessThanOrEqual(buffer.format.channelCount, 2)
                    XCTAssertEqual(sound.licenseStatus, "verified")
                    XCTAssertTrue(["LicenseRef-Nodus-loop-CC0-sources", "LicenseRef-Nodus-original-audio"].contains(sound.licenseId))
                    let duration = Double(buffer.frameLength) / buffer.format.sampleRate
                    XCTAssertEqual(duration, (sound.duration ?? 0) - Double(sound.crossfadeMs ?? 0) / 1000, accuracy: 0.1, sound.id)
                    let loop = try DriftAudioEngine.prepareFileLoop(sound, budget: 2 * 1024 * 1024)
                    XCTAssertEqual(Int(loop.middleCount) + Int(loop.seam?.frameLength ?? 0), Int(buffer.frameLength), sound.id)
                    if let seam = loop.seam {
                        // Streaming preserves the same PCM seam as the original
                        // whole-buffer algorithm, in every channel and sample.
                        let start = Int(buffer.frameLength) - Int(seam.frameLength)
                        for channel in 0..<Int(seam.format.channelCount) {
                            var maxDifference: Float = 0
                            for i in 0..<Int(seam.frameLength) {
                                maxDifference = max(maxDifference, abs(seam.floatChannelData![channel][i] - buffer.floatChannelData![channel][start + i]))
                            }
                            XCTAssertLessThanOrEqual(maxDifference, 0.00001, sound.id)
                        }
                    }
                }
            }
        }
    }
    func testDecodeEnforcesBudgetAndMissingFile() {
        XCTAssertThrowsError(try DriftAudioEngine.decode(DriftCatalog.sound("light-rain")!, budget: 10)) {
            XCTAssertTrue($0 is DriftAudioFailure)
        }
        var sound = DriftCatalog.sound("light-rain")!
        sound.asset = "../private.mp3"
        XCTAssertThrowsError(try DriftAudioEngine.decode(sound, budget: 192 * 1024 * 1024))
    }
    func testCircularCrossfadePreservesContinuation() {
        let samples: [Float] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        let result = DriftDSP.crossfade(samples, overlap: 3)
        XCTAssertEqual(result, [3, 4, 5, 6, 7, 4.5, 2])
        XCTAssertEqual(DriftDSP.crossfade(samples, overlap: 0), samples)
        XCTAssertEqual(DriftDSP.crossfade(samples, overlap: 100).count, 6)
    }
    func testNoiseIsStereoBoundedAndSpectrallyDistinct() {
        var differences: [String: Double] = [:]
        for color in ["white", "pink", "brown"] {
            let dsp = DriftDSP(sound: DriftCatalog.sound("\(color)-noise")!, sampleRate: 48_000)
            var energy = 0.0, difference = 0.0, cross = 0.0, rightEnergy = 0.0
            var previous: Float = 0
            for frame in 0..<144_000 {
                let (left, right) = dsp.sample()
                XCTAssertTrue(left.isFinite && right.isFinite)
                XCTAssertLessThanOrEqual(abs(left), 0.95)
                if frame >= 48_000 {
                    energy += Double(left * left); difference += Double((left - previous) * (left - previous))
                    cross += Double(left * right); rightEnergy += Double(right * right)
                }
                previous = left
            }
            XCTAssertGreaterThan(sqrt(energy / 96_000), 0.05)
            XCTAssertLessThan(abs(cross / sqrt(energy * rightEnergy)), 0.6, "Noise channels should be independent")
            differences[color] = difference / energy
        }
        XCTAssertGreaterThan(differences["white"]!, differences["pink"]!)
        XCTAssertGreaterThan(differences["pink"]!, differences["brown"]!)
    }
    func testBinauralFrequenciesRemainSeparated() {
        for id in ["delta", "theta", "alpha", "beta", "gamma"] {
            let sound = DriftCatalog.sound("binaural-\(id)")!
            let dsp = DriftDSP(sound: sound, sampleRate: 48_000)
            var leftCrossings = 0, rightCrossings = 0
            var previous: (Float, Float) = (0, 0)
            for _ in 0..<96_000 {
                let sample = dsp.sample()
                if previous.0 < 0 && sample.0 >= 0 { leftCrossings += 1 }
                if previous.1 < 0 && sample.1 >= 0 { rightCrossings += 1 }
                previous = sample
            }
            XCTAssertEqual(Double(leftCrossings) / 2, 100 - sound.beatHz! / 2, accuracy: 1)
            XCTAssertEqual(Double(rightCrossings) / 2, 100 + sound.beatHz! / 2, accuracy: 1)
        }
    }
    func testConfigurationRejectsInvalidPersistedData() {
        var state = DriftConfiguration()
        state.selection = ["missing", "light-rain", "light-rain", "binaural-delta", "binaural-alpha", "heavy-rain", "waves", "birds", "campfire", "river"]
        state.volumes = ["missing": 0.9, "light-rain": .infinity, "waves": -2]
        state.master = .nan
        state.favorites = ["missing", "birds"]
        state.sanitize()
        XCTAssertEqual(state.selection.count, 6)
        XCTAssertEqual(state.selection.filter { $0.hasPrefix("binaural") }.count, 1)
        XCTAssertEqual(state.master, 0.35)
        XCTAssertEqual(state.volumes["light-rain"], 0.25)
        XCTAssertEqual(state.volumes["waves"], 0)
        XCTAssertNil(state.volumes["missing"])
        XCTAssertEqual(state.favorites, ["birds"])
    }
    @MainActor func testSavedMixRestoresPausedAndEditingKeepsSoundSettings() {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let store = DriftStore(defaults: defaults)
        let fixture = DriftPreset(name: "Rainy pages", icon: "book", selection: ["light-rain", "brown-noise"], volumes: ["light-rain": 0.42], master: 0.31)
        store.load(fixture)
        XCTAssertFalse(store.audio.playing)
        store.save(name: "Evening reading", icon: "book")
        let saved = store.config.presets[0]
        store.save(name: "Renamed", icon: "moon", editing: saved.id)
        XCTAssertEqual(store.config.presets[0].selection, saved.selection)
        XCTAssertEqual(store.config.presets[0].volumes, saved.volumes)
        let restored = DriftStore(defaults: defaults)
        XCTAssertEqual(restored.selection, fixture.selection)
        XCTAssertEqual(restored.config.master, 0.31)
        XCTAssertFalse(restored.audio.playing)
        XCTAssertEqual(restored.config.presets[0].name, "Renamed")
        restored.deletePreset(saved.id)
        XCTAssertTrue(restored.config.presets.isEmpty)
    }
    @MainActor func testSixVoiceLimitAndBinauralReplacement() async {
        let store = DriftStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        store.load(DriftPreset(name: "Test", icon: "book", selection: ["light-rain", "heavy-rain", "thunder", "river", "waves", "binaural-delta"], volumes: [:], master: 0))
        store.toggle("birds")
        XCTAssertEqual(store.selection.count, 6)
        XCTAssertNotNil(store.notice)
        store.toggle("binaural-alpha")
        XCTAssertEqual(store.selection.count, 6)
        XCTAssertFalse(store.selection.contains("binaural-delta"))
        XCTAssertTrue(store.selection.contains("binaural-alpha"))
        store.clear()
        try? await Task.sleep(for: .milliseconds(300))
        XCTAssertFalse(store.audio.playing)
        XCTAssertTrue(store.audio.loading.isEmpty)
        XCTAssertEqual(store.audio.decodedBytes, 0)
    }
    @MainActor func testSleepTimerEndsPlaybackAndClearsDeadline() async {
        let store = DriftStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        store.toggle("white-noise")
        store.setSleepTimer(minutes: 0)
        try? await Task.sleep(for: .milliseconds(300))
        XCTAssertFalse(store.audio.playing)
        XCTAssertNil(store.sleepDeadline)
    }
    @MainActor func testRapidPlayPauseDoesNotResurrectRemovedVoices() async {
        let store = DriftStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        store.toggle("light-rain")
        store.clear()
        store.toggle("pink-noise")
        try? await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(store.selection, ["pink-noise"])
        XCTAssertTrue(store.audio.playing)
        XCTAssertTrue(store.audio.errors.isEmpty)
        XCTAssertEqual(store.audio.decodedBytes, 0)
        store.clear()
        try? await Task.sleep(for: .milliseconds(250))
    }
    @MainActor func testSixLongestRecordingsPlayWithSmallResidentBuffers() async {
        let audio = DriftAudioEngine()
        audio.master = 0
        let sounds = Array(DriftCatalog.sounds.filter { $0.kind == "file" }.sorted { ($0.duration ?? 0) > ($1.duration ?? 0) }.prefix(6))
        audio.play(sounds: sounds, volumes: [:])
        for _ in 0..<200 {
            if audio.activeVoiceCount == 6 || !audio.errors.isEmpty { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertTrue(audio.errors.isEmpty, "\(audio.errors)")
        XCTAssertEqual(audio.activeVoiceCount, 6)
        XCTAssertLessThan(audio.decodedBytes, 6 * 1024 * 1024)
        audio.pause(immediate: true)
        XCTAssertEqual(audio.activeVoiceCount, 0)
        XCTAssertEqual(audio.decodedBytes, 0)
    }
    @MainActor func testFileQueuesReplenishAndStayStoppedAfterPause() async {
        let audio = DriftAudioEngine()
        audio.master = 0
        let sounds = [DriftCatalog.sound("bubbles")!, DriftCatalog.sound("keyboard")!]
        audio.play(sounds: sounds, volumes: [:])
        for _ in 0..<340 {
            if sounds.allSatisfy({ (audio.completedFileCycles[$0.id] ?? 0) > 0 }) || !audio.errors.isEmpty { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertTrue(audio.errors.isEmpty, "\(audio.errors)")
        for sound in sounds { XCTAssertGreaterThan(audio.completedFileCycles[sound.id] ?? 0, 0, sound.id) }
        XCTAssertEqual(audio.activeVoiceCount, 2)
        audio.pause(immediate: true)
        try? await Task.sleep(for: .milliseconds(250))
        XCTAssertFalse(audio.playing)
        XCTAssertEqual(audio.activeVoiceCount, 0)
        XCTAssertTrue(audio.completedFileCycles.isEmpty)
    }
}
