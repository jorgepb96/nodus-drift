import XCTest
import CarPlay
import MediaPlayer
import AVFoundation
@testable import NodusDrift

final class CarPlayTests: XCTestCase {
    @MainActor private func fixture() -> (DriftSession, URL, UserDefaults, String) {
        let name = "carplay.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        return (DriftSession(defaults: defaults, library: StudioLibrary(root: root)), root, defaults, name)
    }

    @MainActor func testSavedGridIncludesEveryMixAndSceneWithNames() throws {
        let (session, root, defaults, name) = fixture()
        defer { defaults.removePersistentDomain(forName: name); try? FileManager.default.removeItem(at: root) }
        session.store.load(DriftPreset.starters[0])
        for i in 0..<48 { session.store.save(name: "Mix \(i)", icon: "book") }
        for i in 0..<96 {
            var scene = StudioScene.starters[i % 3].duplicated(); scene.name = "Scene \(i)"
            session.studio.load(scene); session.studio.save()
        }
        let entries = session.carPlay.mixes + session.carPlay.scenes
        XCTAssertEqual(entries.count, 144)
        XCTAssertEqual(Set(entries.map(\.id)).count, 144)
        let browser = DriftCarPlayBrowser(session: session)
        let section = browser.section("Saved", entries: entries, pixels: 128)
        if #available(iOS 26.0, *) {
            let rows = try section.items.map { try XCTUnwrap($0 as? CPListImageRowItem) }
            let elements = try rows.flatMap(\.elements).map { try XCTUnwrap($0 as? CPListImageRowItemImageGridElement) }
            XCTAssertEqual(elements.map(\.title), entries.map(\.title))
            XCTAssertTrue(elements.allSatisfy(\.isEnabled))
            XCTAssertTrue(rows.allSatisfy(\.allowsMultipleLines))
            XCTAssertTrue(rows.allSatisfy { $0.elements.count <= CPMaximumNumberOfGridImages })
        }
        XCTAssertLessThanOrEqual(section.items.count, CPListTemplate.maximumItemCount)
        session.studio.flushDraft()
    }

    @MainActor func testRecentsUseStableStarterIDsAndResolveLatestSavedValues() throws {
        let (session, root, defaults, name) = fixture()
        defer { session.store.audio.pause(immediate: true); defaults.removePersistentDomain(forName: name); try? FileManager.default.removeItem(at: root) }
        var mix = DriftPreset.starters[0]; mix.master = 0
        session.store.load(mix); session.store.save(name: "Before", icon: "book")
        let old = try XCTUnwrap(session.carPlay.mixes.first)
        session.store.save(name: "After", icon: "book", editing: session.store.config.presets[0].id)
        XCTAssertEqual(session.carPlay.resolve(old.id)?.title, "After")
        session.store.deletePreset(session.store.config.presets[0].id)
        XCTAssertNil(session.carPlay.resolve(old.id))
        XCTAssertThrowsError(try session.carPlay.play(old.id))
        defaults.set(["starter-scene:0", "starter-scene:0", "deleted", "starter-mix:rainy-pages"], forKey: "drift.carplay.recents.v1")
        let restored = DriftCarPlayLibrary(store: session.store, studio: session.studio, defaults: defaults)
        XCTAssertEqual(restored.recents.map(\.id), ["starter-scene:0", "starter-mix:rainy-pages"])
        XCTAssertEqual(restored.recents.first?.title, StudioScene.starters[0].name)
        XCTAssertFalse(session.store.audio.playing, "Connecting/browsing must never start audio")
    }

    @MainActor func testMissingGeneratedRecordingCannotReplaceAnExistingMix() throws {
        let (session, root, defaults, name) = fixture()
        defer { session.store.audio.pause(immediate: true); defaults.removePersistentDomain(forName: name); try? FileManager.default.removeItem(at: root) }
        session.store.load(DriftPreset.starters[1])
        let selection = session.store.selection
        var scene = StudioScene.starters[0].duplicated()
        scene.layers[0].catalogID = nil
        scene.layers[0].recording = StudioRecording(fileName: UUID().uuidString.lowercased() + ".m4a",
            sha256: String(repeating: "a", count: 64), bytes: 100, seconds: 10,
            prompt: "Gentle rain", model: "sfx", seed: 1, revision: "test")
        session.studio.load(scene); session.studio.save()
        let entry = try XCTUnwrap(session.carPlay.scenes.first)
        XCTAssertFalse(entry.isAvailable(recordings: root.appendingPathComponent("Recordings")))
        XCTAssertThrowsError(try session.carPlay.play(entry.id))
        XCTAssertEqual(session.store.selection, selection)
        XCTAssertEqual(session.store.audio.owner, .listen)
        session.studio.flushDraft()
    }

    @MainActor func testEveryEnvironmentHasAStaticBoundedCover() async throws {
        let artwork = DriftArtwork()
        for landscape in StudioLandscape.allCases {
            let loaded = await artwork.cover(landscape, pixels: 128)
            let image = try XCTUnwrap(loaded)
            XCTAssertEqual(image.cgImage?.width, 128)
            XCTAssertEqual(image.cgImage?.height, 128)
            XCTAssertNil(image.images, "CarPlay artwork must be static")
        }
        let loadedCar = await artwork.cover(.car, pixels: 512)
        let loadedSnow = await artwork.cover(.snow, pixels: 512)
        let car = try XCTUnwrap(loadedCar)
        let snow = try XCTUnwrap(loadedSnow)
        XCTAssertNotEqual(car.pngData(), snow.pngData())
        XCTAssertTrue(artwork.cached(.snow) === snow)
    }

    @MainActor func testCarPlayMixAndStudioShareTransportAndPublishCorrectArtwork() async throws {
        let (session, root, defaults, name) = fixture()
        defer { session.store.audio.pause(immediate: true); defaults.removePersistentDomain(forName: name); try? FileManager.default.removeItem(at: root) }
        XCTAssertTrue(session.store.audio === session.studio.audio)
        XCTAssertFalse(session.store.audio.playing)
        var mix = DriftPreset.starters[1]; mix.master = 0
        session.store.load(mix); session.store.save(name: "Another coast", icon: "water.waves")
        session.store.save(name: "Coastal drive", icon: "water.waves")
        let entry = try XCTUnwrap(session.carPlay.mixes.last)
        session.store.tab = 2
        try session.carPlay.play(entry.id)
        for _ in 0..<100 {
            if session.store.audio.activeVoiceCount == 2 && MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtwork] != nil { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(session.store.tab, 2)
        XCTAssertEqual(session.store.audio.activeVoiceCount, 2)
        XCTAssertTrue(session.store.audio.errors.isEmpty)
        XCTAssertEqual(MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyTitle] as? String, "Coastal drive")
        XCTAssertNotNil(MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtwork])
        var scene = StudioScene.starters[1]; scene.master = 0
        session.studio.load(scene); session.studio.save()
        let sceneEntry = try XCTUnwrap(session.carPlay.scenes.first)
        try session.carPlay.play(sceneEntry.id)
        try await Task.sleep(for: .seconds(2))
        XCTAssertEqual(session.store.audio.owner, .studio)
        XCTAssertTrue(session.studio.playing)
        XCTAssertGreaterThan(session.studio.time, 0)
        XCTAssertTrue(session.store.audio.errors.isEmpty)
        let info = try XCTUnwrap(MPNowPlayingInfoCenter.default().nowPlayingInfo)
        XCTAssertEqual(info[MPMediaItemPropertyTitle] as? String, scene.name)
        XCTAssertEqual(info[MPMediaItemPropertyPlaybackDuration] as? Double, scene.duration)
        XCTAssertNotNil(info[MPMediaItemPropertyArtwork])
        XCTAssertEqual(session.carPlay.recents.map(\.id), [sceneEntry.id, entry.id])
        session.store.audio.pause(immediate: true)
        XCTAssertFalse(session.studio.playing)
        session.studio.flushDraft()
    }

    @MainActor func testInterruptionResumesOnlyWithSystemPermissionAndNoUserPause() async throws {
        let (session, root, defaults, name) = fixture()
        let audio = session.store.audio
        defer { audio.pause(immediate: true); defaults.removePersistentDomain(forName: name); try? FileManager.default.removeItem(at: root) }
        session.store.load(DriftPreset(name: "Test", icon: "headphones", selection: ["white-noise"], volumes: [:], master: 0))
        audio.resume()
        func interruption(_ type: AVAudioSession.InterruptionType, resume: Bool = false) {
            NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [
                AVAudioSessionInterruptionTypeKey: type.rawValue,
                AVAudioSessionInterruptionOptionKey: resume ? AVAudioSession.InterruptionOptions.shouldResume.rawValue : 0
            ])
        }
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertTrue(audio.playing)
        interruption(.began)
        try await Task.sleep(for: .milliseconds(200)); XCTAssertFalse(audio.playing)
        interruption(.ended, resume: true)
        try await Task.sleep(for: .milliseconds(250)); XCTAssertTrue(audio.playing)
        interruption(.began)
        try await Task.sleep(for: .milliseconds(200)); audio.pause()
        interruption(.ended, resume: true)
        try await Task.sleep(for: .milliseconds(200)); XCTAssertFalse(audio.playing)
        audio.resume()
        interruption(.began)
        try await Task.sleep(for: .milliseconds(200))
        interruption(.ended, resume: false)
        try await Task.sleep(for: .milliseconds(200)); XCTAssertFalse(audio.playing)
    }
}
