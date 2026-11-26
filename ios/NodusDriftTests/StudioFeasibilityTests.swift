import XCTest
import AVFoundation
import StableAudioMLX
#if canImport(FoundationModels)
import FoundationModels
#endif
@testable import NodusDrift

/// Run explicitly on hardware; weights are installed into the isolated Studio Lab app.
final class StudioFeasibilityTests: XCTestCase {
    func testLocalGenerationOnHardware() async throws {
        guard SA3Engine.isSupported else { throw XCTSkip("MLX inference is disabled in Simulator") }
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StudioModels")
        let directory = SA3ModelDirectory(root: root)
        guard directory.isReady(.sfx), directory.isReady(.music) else {
            throw XCTSkip("Install the pinned models in StudioModels before running the hardware probe")
        }
        let engine = SA3Engine(directory: directory, residency: .staged, cacheLimitBytes: 64 << 20)
        var measurements: [SA3Measurement] = []
        for kind in SA3ModelKind.allCases {
            let prompt = kind == .music
                ? "TrackType: Music, VocalType: Instrumental. Gentle ambient piano, slowly evolving, no vocals."
                : "Steady gentle rain on leaves, natural forest ambience, no music, no voices."
            let output = try await engine.generate(.init(kind: kind, prompt: prompt, seconds: 30, steps: 8, seed: 20261106))
            XCTAssertEqual(output.channels.count, 2)
            XCTAssertGreaterThan(output.channels[0].count, 29 * output.sampleRate)
            XCTAssertTrue(output.channels.allSatisfy { $0.allSatisfy(\.isFinite) })
            let levels = SA3Audio.levels(output.channels, sampleRate: output.sampleRate)
            XCTAssertGreaterThan(levels.rmsDB, -65)
            measurements.append(output.measurement)
            await engine.unloadAll()
        }
        let report = try JSONEncoder().encode(measurements)
        let attachment = XCTAttachment(data: report, uniformTypeIdentifier: "public.json")
        attachment.name = "Drift-iPhone-StableAudio-measurements"; attachment.lifetime = .keepAlways
        add(attachment)
        try report.write(to: root.appendingPathComponent("drift-inference-measurements.json"))
    }

    @MainActor func testSpatialSources() async throws {
        let engine = AVAudioEngine()
        let environment = AVAudioEnvironmentNode()
        engine.attach(environment)
        engine.connect(environment, to: engine.mainMixerNode, format: nil)
        let mono = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        var players: [AVAudioPlayerNode] = []
        for index in 0..<6 {
            let player = AVAudioPlayerNode(); engine.attach(player)
            engine.connect(player, to: environment, format: mono)
            player.renderingAlgorithm = .auto
            player.position = AVAudio3DPoint(x: Float(index) - 3, y: 0, z: -3)
            let pcm = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: 44_100)!
            pcm.frameLength = pcm.frameCapacity
            for frame in 0..<44_100 { pcm.floatChannelData![0][frame] = Float(sin(Double(frame) * 2 * .pi * Double(150 + 50 * index) / 44_100)) * 0.002 }
            player.scheduleBuffer(pcm, at: nil, options: .loops, completionHandler: nil)
            players.append(player)
        }
        try AVAudioSession.sharedInstance().setCategory(.playback)
        try AVAudioSession.sharedInstance().setActive(true)
        try engine.start(); players.forEach { $0.play() }
        try await Task.sleep(for: .seconds(2))
        XCTAssertTrue(engine.isRunning)
        players.forEach { $0.position = AVAudio3DPoint(x: 3, y: 0, z: -8) }
        let route = AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portType.rawValue).joined(separator: ",")
        let report = "Six mono sources active; route=\(route); algorithms=\(environment.applicableRenderingAlgorithms)"
        let attachment = XCTAttachment(string: report); attachment.name = "Drift-spatial-sources"
        attachment.lifetime = .keepAlways; add(attachment)
        players.forEach { $0.stop() }; engine.stop()
    }

    @MainActor func testFoundationModelsAvailability() async throws {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            let model = SystemLanguageModel.default
            var report = "FoundationModels=\(model.availability)"
            if case .available = model.availability {
                do {
                    let reply = try await LanguageModelSession(model: model).respond(to: "Name two natural sounds heard in a rainy forest. Use fewer than 12 words.")
                    XCTAssertFalse(reply.content.isEmpty); report += "; response=\(reply.content)"
                } catch {
                    let attachment = XCTAttachment(string: report + "; inference failed: \(String(describing: error))")
                    attachment.name = "FoundationModels-inference-unavailable"; attachment.lifetime = .keepAlways; add(attachment)
                    #if targetEnvironment(simulator)
                    throw XCTSkip("Simulator's system model reports available but cannot run: \(String(describing: error))")
                    #else
                    throw error
                    #endif
                }
            }
            let attachment = XCTAttachment(string: report); attachment.name = "Drift-FoundationModels-availability"
            attachment.lifetime = .keepAlways; add(attachment)
        }
        #endif
    }
}
