// SPDX-License-Identifier: MIT
import Foundation
import AVFoundation
import StableAudioMLX
import CryptoKit
import UIKit

@MainActor final class StudioGenerator: ObservableObject {
    @Published private(set) var busy = false
    @Published private(set) var stage = ""
    @Published private(set) var lastMeasurement: SA3Measurement?
    let models = StudioModels()

    static func optimizedPrompt(_ text: String, kind: SA3ModelKind) -> String {
        let brief = text.split(whereSeparator: \.isNewline).joined(separator: " ").prefix(400)
        if kind == .music && brief.hasPrefix("TrackType: Music, VocalType: Instrumental.") { return String(brief) + " No voices, no singing." }
        if kind == .sfx && brief.hasSuffix("Natural sound, no voices, no music.") { return String(brief) }
        if kind == .music { return "TrackType: Music, VocalType: Instrumental. \(brief). No voices, no singing." }
        return "\(brief). Natural sound, no voices, no music."
    }

    func render(prompt: String, kind: SA3ModelKind, seconds: Double, source: StudioRecording? = nil,
                keep: [ClosedRange<Double>] = []) async throws -> StudioRecording {
        guard !busy, !models.busy else { throw StudioError.invalid("Wait for the current model operation.") }
        guard SA3Engine.isSupported else { throw StudioError.invalid("Audio generation needs a real iPhone or iPad. You can build and play catalogue scenes here.") }
        guard models.acceptedTerms else { throw StudioError.invalid("Review and accept the model terms in Models & licenses before generating.") }
        guard models.installed.contains(kind) else { throw StudioError.invalid("Download Stable Audio 3 \(kind.displayName) in Models & licenses first.") }
        guard UIApplication.shared.applicationState == .active, !ProcessInfo.processInfo.isLowPowerModeEnabled,
              ProcessInfo.processInfo.thermalState.rawValue < ProcessInfo.ThermalState.serious.rawValue else {
            throw StudioError.invalid("Generation is paused. Keep Drift open, disable Low Power Mode and let the device cool.")
        }
        guard ProcessInfo.processInfo.physicalMemory >= 6_000_000_000, ProcessMemory.available() > 1_700_000_000 else {
            throw StudioError.invalid("There is not enough free memory for local generation. Close other apps and try again.")
        }
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw StudioError.invalid("Describe the sound in a short English prompt.") }
        busy = true; stage = "Preparing local generation…"
        defer { busy = false }
        let engine = SA3Engine(directory: models.directory, residency: .staged, cacheLimitBytes: 64 << 20)
        let seed = UInt64.random(in: 1...UInt64.max / 2)
        let optimized = Self.optimizedPrompt(text, kind: kind)
        do {
            var inpaint: SA3Engine.InpaintSource?
            if let source, !keep.isEmpty {
                guard StudioScene.safeAudioName(source.fileName) else { throw StudioError.invalid("Invalid source recording.") }
                let url = StudioLibrary.recordingsURL.appendingPathComponent(source.fileName)
                let pcm = try await Task.detached(priority: .utility) { () throws -> [[Float]] in
                    let file = try AVAudioFile(forReading: url)
                    guard file.processingFormat.sampleRate == 44_100, file.processingFormat.channelCount == 2,
                          file.length <= 120 * 44_100,
                          let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else { throw StudioError.invalid("This recording cannot be continued.") }
                    try file.read(into: buffer)
                    guard let channels = buffer.floatChannelData else { throw DriftAudioFailure.corrupt }
                    return (0..<2).map { Array(UnsafeBufferPointer(start: channels[$0], count: Int(buffer.frameLength))) }
                }.value
                inpaint = .init(channels: pcm, keep: keep)
            }
            let output = try await engine.generate(.init(kind: kind, prompt: optimized, seconds: Float(min(120, max(5, seconds))), steps: 8, seed: seed), inpaint: inpaint) { [weak self] phase in
                Task { @MainActor in self?.stage = ["text": "Understanding the sound…", "diffusion": "Composing locally…", "decode": "Preparing your recording…", "encoding": "Reading the fragment…"][phase] ?? "Generating on this device…" }
            }
            await engine.unloadAll()
            try Task.checkCancellation()
            stage = "Checking and balancing the recording…"
            let postprocessing = Task.detached(priority: .utility) { () throws -> StudioRecording in
                let samples = output.channels
                guard samples.count == 2, samples.allSatisfy({ $0.count > 44_100 && $0.allSatisfy(\.isFinite) }) else { throw StudioError.invalid("The model produced invalid audio. Try another prompt.") }
                let loudness = SA3Audio.integratedLoudness(samples, sampleRate: output.sampleRate)
                guard loudness > -55, loudness.isFinite else { throw StudioError.invalid("The result was too quiet. Try a more concrete prompt.") }
                try StudioAudioQuality.checkForVoices(samples, sampleRate: output.sampleRate)
                let balanced = SA3Audio.level(samples, sampleRate: output.sampleRate, targetLUFS: kind == .music ? -23 : -28, ceilingDBTP: -3)
                let name = UUID().uuidString.lowercased() + ".m4a"
                try FileManager.default.createDirectory(at: StudioLibrary.recordingsURL, withIntermediateDirectories: true)
                let url = StudioLibrary.recordingsURL.appendingPathComponent(name)
                do {
                    let frames = try SA3Audio.writeAAC(balanced.channels, sampleRate: output.sampleRate, bitRate: kind == .music ? 176_000 : 112_000, to: url)
                    let data = try Data(contentsOf: url, options: .mappedIfSafe)
                    try Task.checkCancellation()
                    return StudioRecording(fileName: name, sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), bytes: data.count,
                                           seconds: Double(frames) / Double(output.sampleRate), prompt: optimized, model: kind.rawValue, seed: seed, revision: SA3Manifest.revision)
                } catch { try? FileManager.default.removeItem(at: url); throw error }
            }
            let recording = try await withTaskCancellationHandler { try await postprocessing.value } onCancel: { postprocessing.cancel() }
            if Task.isCancelled {
                try? FileManager.default.removeItem(at: StudioLibrary.recordingsURL.appendingPathComponent(recording.fileName))
                throw CancellationError()
            }
            lastMeasurement = output.measurement; stage = "Added to your scene."
            return recording
        } catch {
            await engine.unloadAll(); stage = Task.isCancelled ? "Generation stopped." : "Generation could not finish."
            if case SA3Engine.EngineError.missingFile = error {
                models.refresh()
                throw StudioError.invalid("Some model files are missing. Remove this model in Models & licenses, then download it again.")
            }
            throw error
        }
    }
}
