// SPDX-License-Identifier: AGPL-3.0-only
import AVFoundation
import MediaPlayer
import CryptoKit

enum DriftAudioFailure: LocalizedError {
    case missing, corrupt, capacity
    var errorDescription: String? {
        switch self {
        case .missing: return "This recording is missing. Reinstall the app to restore it."
        case .corrupt: return "This recording could not be read. Try again."
        case .capacity: return "This mix needs too much audio memory. Try a shorter recording."
        }
    }
}

/// The long middle plays directly from the file. Only the circular seam is PCM.
struct DriftFileLoop {
    let file: AVAudioFile
    let middleStart: AVAudioFramePosition
    let middleCount: AVAudioFrameCount
    let seam: AVAudioPCMBuffer?
}

/// Sample state lives exclusively on the audio render thread; UI changes use mixer gains.
final class DriftDSP {
    private var seed: UInt64 = 0x123456789ABCDEF
    private var brown = [Float](repeating: 0, count: 2)
    private var rows = [[Float]](repeating: [Float](repeating: 0, count: 16), count: 2)
    private var rowTotal = [Float](repeating: 0, count: 2)
    private var counter = [UInt32](repeating: 1, count: 2)
    private var phaseLeft = 0.0
    private var phaseRight = 0.0
    let sound: DriftSound
    let sampleRate: Double
    init(sound: DriftSound, sampleRate: Double) {
        self.sound = sound; self.sampleRate = sampleRate
        for channel in 0..<2 {
            for row in 0..<16 { rows[channel][row] = random(); rowTotal[channel] += rows[channel][row] }
        }
    }
    func random() -> Float {
        seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
        return Float(seed & 0xFFFFFF) / Float(0xFFFFFF) * 2 - 1
    }
    func sample() -> (Float, Float) {
        if sound.kind == "binaural" {
            let carrier = sound.carrierHz ?? 100, beat = sound.beatHz ?? 10
            let left = Float(sin(phaseLeft)) * 0.28, right = Float(sin(phaseRight)) * 0.28
            phaseLeft += 2 * .pi * (carrier - beat / 2) / sampleRate
            phaseRight += 2 * .pi * (carrier + beat / 2) / sampleRate
            if phaseLeft >= 2 * .pi { phaseLeft -= 2 * .pi }
            if phaseRight >= 2 * .pi { phaseRight -= 2 * .pi }
            return (left, right)
        }
        return (noise(channel: 0), noise(channel: 1))
    }
    private func noise(channel: Int) -> Float {
        let white = random()
        let value: Float
        switch sound.color {
        case "brown":
            brown[channel] = 0.998 * brown[channel] + white
            value = brown[channel] * 0.022
        case "pink":
            counter[channel] &+= 1
            if counter[channel] == 0 { counter[channel] = 1 }
            let row = counter[channel].trailingZeroBitCount
            if row < 16 { rowTotal[channel] -= rows[channel][row]; rows[channel][row] = random(); rowTotal[channel] += rows[channel][row] }
            value = (rowTotal[channel] + white) / 17 * 1.6
        default: value = white * 0.3464
        }
        return min(0.95, max(-0.95, value))
    }

    /// The original circular seam: middle, then complementary tail/head overlap.
    static func crossfade(_ input: [Float], overlap: Int) -> [Float] {
        let c = min(max(0, overlap), (input.count - 1) / 2)
        guard c >= 2 else { return input }
        var result = Array(input[c..<(input.count - c)])
        for i in 0..<c {
            let w = Float(i) / Float(c - 1)
            result.append(input[input.count - c + i] * (1 - w) + input[i] * w)
        }
        return result
    }
}

@MainActor final class DriftAudioEngine: ObservableObject {
    @Published private(set) var playing = false
    @Published private(set) var loading = Set<String>()
    @Published private(set) var errors: [String: String] = [:]
    var didStartVoice: ((String) -> Void)?
    var didStop: (() -> Void)?
    var master: Float = 0.35 { didSet { fadeMaster(to: master) } }
    var mixWithOtherAudio = false
    var sleepDeadline: Date? { didSet { scheduleSleep() } }
    private let engine = AVAudioEngine()
    private let limiter = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(componentType: kAudioUnitType_Effect, componentSubType: kAudioUnitSubType_PeakLimiter, componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0))
    private var nodes: [String: AVAudioNode] = [:]
    private var mixers: [String: AVAudioMixerNode] = [:]
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var fileLoops: [String: DriftFileLoop] = [:]
    private(set) var completedFileCycles: [String: Int] = [:]
    private var desired: [DriftSound] = []
    private var volumes: [String: Float] = [:]
    private var revision = 0
    private var worker: Task<Void, Never>?
    private var fade: Task<Void, Never>?
    private var voiceFades: [String: Task<Void, Never>] = [:]
    private var sleepTimer: DispatchSourceTimer?
    private var observers: [NSObjectProtocol] = []
    private var remoteTargets: [(MPRemoteCommand, Any)] = []
    private let memoryBudget = 192 * 1024 * 1024
    var decodedBytes: Int { buffers.values.reduce(0) { $0 + Int($1.frameLength) * Int($1.format.channelCount) * 4 } }
    var activeVoiceCount: Int { nodes.count }

    init() {
        engine.attach(limiter)
        engine.connect(engine.mainMixerNode, to: limiter, format: nil)
        engine.connect(limiter, to: engine.outputNode, format: nil)
        engine.mainMixerNode.outputVolume = 0
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            if type == AVAudioSession.InterruptionType.began.rawValue { Task { @MainActor in self?.pause() } }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { Task { @MainActor in self?.pause() } }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.pause(immediate: true) }
        })
        let commands = MPRemoteCommandCenter.shared()
        for (command, action) in [(commands.playCommand, 0), (commands.pauseCommand, 1), (commands.togglePlayPauseCommand, 2)] {
            let target = command.addTarget { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    if action == 1 || (action == 2 && self.playing) { self.pause() }
                    else { self.play(sounds: self.desired, volumes: self.volumes) }
                }
                return .success
            }
            remoteTargets.append((command, target))
        }
    }
    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        remoteTargets.forEach { $0.0.removeTarget($0.1) }
        sleepTimer?.cancel()
    }
    func reconfigureSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: mixWithOtherAudio ? [.mixWithOthers] : [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { errors["session"] = "Audio is unavailable. Try playing again." }
    }
    func configure(sounds: [DriftSound], volumes: [String: Float]) {
        desired = sounds; self.volumes = volumes
        updateNowPlaying()
    }
    func clear() { pause(); desired = []; updateNowPlaying() }
    func play(sounds: [DriftSound], volumes: [String: Float]) {
        #if DEBUG
        // Interaction-only UI runs never activate the audio session or engine.
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-silent") { return }
        #endif
        guard !sounds.isEmpty else { return }
        desired = sounds; self.volumes = volumes
        let keep = Set(sounds.map(\.id))
        for id in Array(nodes.keys) where !keep.contains(id) { detach(id) }
        errors = errors.filter { keep.contains($0.key) }
        reconfigureSession()
        do {
            if !engine.isRunning { try engine.start() }
            playing = true
            fadeMaster(to: master)
            for sound in sounds { setVolume(sound.id, volumes[sound.id] ?? 0.25) }
            pump(); updateNowPlaying()
        } catch { errors["session"] = "Audio could not start. Try again."; playing = false }
    }
    func retry(_ id: String) { errors[id] = nil; pump() }
    func pause(immediate: Bool = false) {
        guard playing || !nodes.isEmpty else { return }
        playing = false; revision += 1; loading = []
        didStop?(); updateNowPlaying()
        fade?.cancel()
        if immediate { finishPause(); return }
        let start = engine.mainMixerNode.outputVolume
        fade = Task { [weak self] in
            for step in 1...10 {
                guard let self, !Task.isCancelled else { return }
                self.engine.mainMixerNode.outputVolume = start * (1 - Float(step) / 10)
                try? await Task.sleep(for: .milliseconds(15))
            }
            guard let self, !Task.isCancelled, !self.playing else { return }
            self.finishPause()
        }
    }
    private func finishPause() {
        engine.stop()
        for id in Array(nodes.keys) { detach(id) }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    func remove(_ id: String) {
        desired.removeAll { $0.id == id }; errors[id] = nil
        guard let mixer = mixers[id] else { return }
        voiceFades[id]?.cancel()
        let start = mixer.outputVolume
        voiceFades[id] = Task { [weak self] in
            for step in 1...10 {
                guard !Task.isCancelled else { return }
                mixer.outputVolume = start * (1 - Float(step) / 10)
                try? await Task.sleep(for: .milliseconds(15))
            }
            guard !Task.isCancelled else { return }
            self?.detach(id); self?.updateNowPlaying()
        }
        updateNowPlaying()
    }
    func setVolume(_ id: String, _ value: Float) {
        volumes[id] = value
        voiceFades[id]?.cancel()
        guard let mixer = mixers[id] else { return }
        let start = mixer.outputVolume
        voiceFades[id] = Task {
            for step in 1...10 {
                guard !Task.isCancelled else { return }
                mixer.outputVolume = start + (value - start) * Float(step) / 10
                try? await Task.sleep(for: .milliseconds(15))
            }
        }
    }
    private func fadeMaster(to target: Float) {
        guard playing else { return }
        fade?.cancel()
        let start = engine.mainMixerNode.outputVolume
        fade = Task { [weak self] in
            for step in 1...10 {
                guard let self, !Task.isCancelled else { return }
                self.engine.mainMixerNode.outputVolume = start + (target - start) * Float(step) / 10
                try? await Task.sleep(for: .milliseconds(15))
            }
        }
    }
    private func detach(_ id: String) {
        voiceFades[id]?.cancel(); voiceFades[id] = nil
        if let node = nodes.removeValue(forKey: id) {
            (node as? AVAudioPlayerNode)?.stop(); engine.disconnectNodeOutput(node); engine.detach(node)
        }
        if let mixer = mixers.removeValue(forKey: id) { engine.disconnectNodeOutput(mixer); engine.detach(mixer) }
        buffers[id] = nil
        fileLoops[id] = nil
        completedFileCycles[id] = nil
    }
    private func attach(_ node: AVAudioNode, id: String, format: AVAudioFormat) {
        let mixer = AVAudioMixerNode()
        engine.attach(node); engine.attach(mixer)
        engine.connect(node, to: mixer, format: format)
        engine.connect(mixer, to: engine.mainMixerNode, format: format)
        mixer.outputVolume = 0
        nodes[id] = node; mixers[id] = mixer
    }
    private func pump() {
        guard worker == nil else { return }
        worker = Task { [weak self] in
            guard let self else { return }
            while self.playing, let sound = self.desired.first(where: { self.nodes[$0.id] == nil && self.errors[$0.id] == nil }) {
                let ticket = self.revision
                self.loading.insert(sound.id)
                do {
                    if sound.kind == "file" {
                        let available = self.memoryBudget - self.decodedBytes
                        let loop = try await Task.detached(priority: .userInitiated) { try Self.prepareFileLoop(sound, budget: available) }.value
                        guard self.playing, ticket == self.revision, self.desired.contains(where: { $0.id == sound.id }) else {
                            self.loading.remove(sound.id); continue
                        }
                        let player = AVAudioPlayerNode()
                        self.attach(player, id: sound.id, format: loop.file.processingFormat)
                        self.fileLoops[sound.id] = loop
                        self.buffers[sound.id] = loop.seam
                        // Keep three cycles queued so scheduling never waits for
                        // the last sample to reach the output device.
                        for _ in 0..<3 { self.queueFileCycle(sound.id, player: player) }
                        player.play()
                    } else {
                        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
                        let dsp = DriftDSP(sound: sound, sampleRate: 48_000)
                        let source = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
                            let output = UnsafeMutableAudioBufferListPointer(audioBufferList)
                            guard output.count == 2, let leftData = output[0].mData, let rightData = output[1].mData else { return noErr }
                            let left = leftData.assumingMemoryBound(to: Float.self), right = rightData.assumingMemoryBound(to: Float.self)
                            for frame in 0..<Int(frameCount) { let s = dsp.sample(); left[frame] = s.0; right[frame] = s.1 }
                            return noErr
                        }
                        self.attach(source, id: sound.id, format: format)
                    }
                    self.setVolume(sound.id, self.volumes[sound.id] ?? 0.25)
                    self.didStartVoice?(sound.id)
                } catch {
                    if ticket == self.revision && self.desired.contains(where: { $0.id == sound.id }) { self.errors[sound.id] = error.localizedDescription }
                }
                self.loading.remove(sound.id)
            }
            self.worker = nil
            if self.playing && self.nodes.isEmpty && !self.desired.isEmpty { self.pause() }
            self.updateNowPlaying()
        }
    }
    private func queueFileCycle(_ id: String, player: AVAudioPlayerNode) {
        guard let loop = fileLoops[id] else { return }
        let replenish: @Sendable (AVAudioPlayerNodeCompletionCallbackType) -> Void = { [weak self, weak player] _ in
            Task { @MainActor in
                guard let self, let player, self.playing,
                      self.nodes[id] === player,
                      self.desired.contains(where: { $0.id == id }) else { return }
                self.completedFileCycles[id, default: 0] &+= 1
                self.queueFileCycle(id, player: player)
            }
        }
        if let seam = loop.seam {
            player.scheduleSegment(loop.file, startingFrame: loop.middleStart, frameCount: loop.middleCount, at: nil, completionHandler: nil)
            player.scheduleBuffer(seam, at: nil, options: [], completionCallbackType: .dataConsumed, completionHandler: replenish)
        } else {
            player.scheduleSegment(loop.file, startingFrame: 0, frameCount: loop.middleCount, at: nil, completionCallbackType: .dataConsumed, completionHandler: replenish)
        }
    }
    nonisolated private static func verifiedFile(_ sound: DriftSound) throws -> AVAudioFile {
        guard let asset = sound.asset, !asset.contains(".."),
              let resource = Bundle.main.resourceURL else { throw DriftAudioFailure.missing }
        let url = resource.appendingPathComponent("Audio").appendingPathComponent(asset)
        guard FileManager.default.fileExists(atPath: url.path) else { throw DriftAudioFailure.missing }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count == sound.bytes,
              SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == sound.sha256 else { throw DriftAudioFailure.corrupt }
        return try AVAudioFile(forReading: url)
    }
    nonisolated static func prepareFileLoop(_ sound: DriftSound, budget: Int) throws -> DriftFileLoop {
        let file = try verifiedFile(sound)
        guard file.length > 0, file.length <= Int64(UInt32.max) else { throw DriftAudioFailure.corrupt }
        let overlap = min(Int(file.processingFormat.sampleRate * Double(sound.crossfadeMs ?? 0) / 1000), (Int(file.length) - 1) / 2)
        guard overlap >= 2 else {
            return DriftFileLoop(file: file, middleStart: 0, middleCount: AVAudioFrameCount(file.length), seam: nil)
        }
        let bytes = overlap * Int(file.processingFormat.channelCount) * 4
        let chunkFrames: AVAudioFrameCount = 8192
        guard bytes * 3 + Int(chunkFrames) * Int(file.processingFormat.channelCount) * 4 <= budget,
              let head = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(overlap)),
              let tail = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(overlap)),
              let seam = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(overlap)),
              let chunk = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: chunkFrames) else { throw DriftAudioFailure.capacity }
        try file.read(into: head, frameCount: AVAudioFrameCount(overlap))
        // Read forward in small chunks to preserve the MP3 decoder's history.
        // Seeking straight to the tail changes its first samples in some files.
        let tailStart = file.length - Int64(overlap)
        while file.framePosition < tailStart {
            let count = AVAudioFrameCount(min(Int64(chunkFrames), tailStart - file.framePosition))
            try file.read(into: chunk, frameCount: count)
            guard chunk.frameLength > 0 else { throw DriftAudioFailure.corrupt }
        }
        try file.read(into: tail, frameCount: AVAudioFrameCount(overlap))
        guard head.frameLength == overlap, tail.frameLength == overlap,
              let h = head.floatChannelData, let t = tail.floatChannelData,
              let s = seam.floatChannelData else { throw DriftAudioFailure.corrupt }
        seam.frameLength = seam.frameCapacity
        for channel in 0..<Int(file.processingFormat.channelCount) {
            for i in 0..<overlap {
                let w = Float(i) / Float(overlap - 1)
                s[channel][i] = t[channel][i] * (1 - w) + h[channel][i] * w
            }
        }
        file.framePosition = 0
        return DriftFileLoop(file: file, middleStart: Int64(overlap), middleCount: AVAudioFrameCount(file.length - Int64(overlap * 2)), seam: seam)
    }
    nonisolated static func decode(_ sound: DriftSound, budget: Int) throws -> AVAudioPCMBuffer {
        let file = try verifiedFile(sound)
        let needed = Int(file.length) * Int(file.processingFormat.channelCount) * 4
        let overlap = min(Int(file.processingFormat.sampleRate * Double(sound.crossfadeMs ?? 0) / 1000), (Int(file.length) - 1) / 2)
        let outputNeeded = overlap >= 2 ? (Int(file.length) - overlap) * Int(file.processingFormat.channelCount) * 4 : 0
        guard needed + outputNeeded <= budget, file.length <= Int64(UInt32.max),
              let source = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else { throw DriftAudioFailure.capacity }
        try file.read(into: source)
        guard overlap >= 2 else { return source }
        guard let target = AVAudioPCMBuffer(pcmFormat: source.format, frameCapacity: source.frameLength - AVAudioFrameCount(overlap)),
              let input = source.floatChannelData, let output = target.floatChannelData else { throw DriftAudioFailure.corrupt }
        target.frameLength = target.frameCapacity
        let n = Int(source.frameLength), middle = n - overlap * 2
        for channel in 0..<Int(source.format.channelCount) {
            output[channel].update(from: input[channel].advanced(by: overlap), count: middle)
            for i in 0..<overlap {
                let w = Float(i) / Float(overlap - 1)
                output[channel][middle + i] = input[channel][n - overlap + i] * (1 - w) + input[channel][i] * w
            }
        }
        return target
    }
    private func scheduleSleep() {
        sleepTimer?.cancel(); sleepTimer = nil
        guard let deadline = sleepDeadline else { return }
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + max(0, deadline.timeIntervalSinceNow))
        timer.setEventHandler { [weak self] in Task { @MainActor in self?.pause() } }
        sleepTimer = timer; timer.resume()
    }
    private func updateNowPlaying() {
        guard !desired.isEmpty else { MPNowPlayingInfoCenter.default().nowPlayingInfo = nil; return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "Nodus Drift",
            MPMediaItemPropertyArtist: desired.map(\.name).joined(separator: " · "),
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0
        ]
    }
}
