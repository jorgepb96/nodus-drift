// SPDX-License-Identifier: MIT
import AVFoundation
import MediaPlayer
import CryptoKit

enum DriftAudioFailure: LocalizedError {
    case missing, corrupt, capacity, connection
    var errorDescription: String? {
        switch self {
        case .missing: return "This recording is missing. Reinstall the app to restore it."
        case .corrupt: return "This recording could not be read. Try again."
        case .capacity: return "This mix needs too much audio memory. Try a shorter recording."
        case .connection: return "This sound could not connect to the audio output. Try playing again."
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
    var didRequestStudioPlayback: (() -> Void)?
    var master: Float = 0.35 { didSet { fadeMaster(to: master) } }
    var mixWithOtherAudio = false
    var sleepDeadline: Date? { didSet { scheduleSleep() } }
    enum Owner { case listen, studio }
    @Published private(set) var owner: Owner = .listen
    var nowPlayingContent: (() -> DriftNowPlayingContent?)?
    #if DEBUG
    var simulateEngineStopBeforePlayerStart = false
    #endif
    var listening: Bool { playing && owner == .listen }
    private var environment = AVAudioEnvironmentNode()
    private var spatialPositions: [String: StudioPosition] = [:]
    private var finished = Set<String>()
    private var engine = AVAudioEngine()
    private var limiter = DriftAudioEngine.makeLimiter()
    private var graphNeedsRebuild = false
    private static func makeLimiter() -> AVAudioUnitEffect {
        AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(componentType: kAudioUnitType_Effect, componentSubType: kAudioUnitSubType_PeakLimiter, componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0))
    }
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
    private var retiring = Set<String>()
    private var sleepTimer: DispatchSourceTimer?
    private var observers: [NSObjectProtocol] = []
    private var remoteTargets: [(MPRemoteCommand, Any)] = []
    private var resumeAfterInterruption = false
    private let memoryBudget = 192 * 1024 * 1024
    var decodedBytes: Int { buffers.values.reduce(0) { $0 + Int($1.frameLength) * Int($1.format.channelCount) * 4 } }
    var activeVoiceCount: Int { nodes.count }

    init() {
        configureGraph()
        installObservers()
    }
    private func configureGraph() {
        engine.attach(environment)
        engine.connect(environment, to: engine.mainMixerNode, format: AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        environment.distanceAttenuationParameters.distanceAttenuationModel = .inverse
        environment.distanceAttenuationParameters.referenceDistance = 2
        environment.distanceAttenuationParameters.maximumDistance = 30
        environment.distanceAttenuationParameters.rolloffFactor = 0.5
        engine.attach(limiter)
        engine.connect(engine.mainMixerNode, to: limiter, format: nil)
        engine.connect(limiter, to: engine.outputNode, format: nil)
        engine.mainMixerNode.outputVolume = 0
    }
    private func rebuildGraph() {
        // A stopped stereo graph can retain uninitialized converter/bus state when
        // handed to the spatial environment on iOS 27. Rebuild only at transport
        // boundaries, after the old voices are detached, never in a render callback.
        engine.stop()
        for id in Array(nodes.keys) { detach(id) }
        engine = AVAudioEngine(); environment = AVAudioEnvironmentNode(); limiter = Self.makeLimiter()
        configureGraph(); graphNeedsRebuild = false
    }
    private func installObservers() {
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor in
                guard let self else { return }
                if type == AVAudioSession.InterruptionType.began.rawValue {
                    let wasPlaying = self.playing
                    self.pause(); self.resumeAfterInterruption = wasPlaying
                } else if type == AVAudioSession.InterruptionType.ended.rawValue {
                    let resume = self.resumeAfterInterruption && AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume)
                    self.resumeAfterInterruption = false
                    if resume { self.resume() }
                }
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { Task { @MainActor in self?.pause() } }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.pause(immediate: true); self?.graphNeedsRebuild = true }
        })
        let commands = MPRemoteCommandCenter.shared()
        commands.nextTrackCommand.isEnabled = false; commands.previousTrackCommand.isEnabled = false
        commands.changePlaybackPositionCommand.isEnabled = false
        commands.seekForwardCommand.isEnabled = false; commands.seekBackwardCommand.isEnabled = false
        for (command, action) in [(commands.playCommand, 0), (commands.pauseCommand, 1), (commands.stopCommand, 1), (commands.togglePlayPauseCommand, 2)] {
            let target = command.addTarget { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    if action == 1 || (action == 2 && self.playing) { self.pause() }
                    else { self.resume() }
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
        owner = .listen; spatialPositions = [:]
        desired = sounds; self.volumes = volumes
        updateNowPlaying()
    }
    func clear() { pause(); desired = []; updateNowPlaying() }
    func resume() {
        guard !desired.isEmpty else { return }
        if owner == .studio, let request = didRequestStudioPlayback { request() }
        else { play(sounds: desired, volumes: volumes, owner: owner, positions: spatialPositions) }
    }
    func play(sounds: [DriftSound], volumes: [String: Float], owner: Owner = .listen, positions: [String: StudioPosition] = [:]) {
        #if DEBUG
        // Interaction-only UI runs never activate the audio session or engine.
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-silent") { return }
        #endif
        guard !sounds.isEmpty else { return }
        resumeAfterInterruption = false
        let changingOwner = self.owner != owner
        if changingOwner || (!playing && (!nodes.isEmpty || worker != nil)) { pause(immediate: true) }
        if graphNeedsRebuild || changingOwner { rebuildGraph() }
        // Invalidate asynchronous preparation from the previous playback request.
        revision += 1; loading = []
        if !playing { finished.removeAll() }
        self.owner = owner; spatialPositions = positions
        desired = sounds; self.volumes = volumes
        let keep = Set(sounds.map(\.id))
        if nodes.keys.contains(where: { !keep.contains($0) }) { engine.pause() }
        for id in Array(nodes.keys) where !keep.contains(id) { detach(id) }
        errors = errors.filter { keep.contains($0.key) }
        reconfigureSession()
        do {
            // Connect new inputs before initializing their converters. Transport
            // boundaries rebuild stopped graphs that retained stale bus state.
            if !nodes.isEmpty && !engine.isRunning { try engine.start() }
            playing = true
            fadeMaster(to: master)
            for sound in sounds { setVolume(sound.id, volumes[sound.id] ?? 0.25) }
            pump(); updateNowPlaying()
        } catch { errors["session"] = "Audio could not start. Try again."; playing = false }
    }
    func retry(_ id: String) { errors[id] = nil; pump() }
    func pause(immediate: Bool = false) {
        resumeAfterInterruption = false
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
        graphNeedsRebuild = true
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    func remove(_ id: String) {
        desired.removeAll { $0.id == id }; errors[id] = nil
        guard let mixer = mixers[id] else { return }
        guard retiring.insert(id).inserted else { return }
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
        retiring.remove(id)
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
    /// Transport updates keep loaded nodes and the existing continuous streams alive.
    func synchronizeStudio(sounds: [DriftSound], volumes: [String: Float], positions: [String: StudioPosition]) {
        guard owner == .studio, playing else { return }
        let oldSpatial = Set(spatialPositions.keys)
        desired = sounds; self.volumes = volumes; spatialPositions = positions
        let keep = Set(sounds.map(\.id))
        finished.formIntersection(keep)
        for id in Array(nodes.keys) {
            if !keep.contains(id) { remove(id) }
            else if oldSpatial.contains(id) != positions.keys.contains(id) { detach(id) }
        }
        for (id, value) in volumes where keep.contains(id) && (retiring.contains(id) || abs((mixers[id]?.outputVolume ?? -1) - value) > 0.002) { setVolume(id, value) }
        for (id, point) in positions {
            mixers[id]?.position = AVAudio3DPoint(x: point.x, y: 0, z: point.z)
        }
        pump()
    }
    func resetStudioCycle() {
        guard owner == .studio else { return }
        finished.removeAll()
    }
    var spatialRouteDescription: String {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        let headphones = outputs.contains { [.headphones, .bluetoothA2DP, .bluetoothLE].contains($0.portType) }
        return headphones ? "Spatial rendering · headphones" : "Stereo speaker rendering · connect headphones for immersion"
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
        let resume = playing && engine.isRunning
        if engine.isRunning { engine.pause() }
        retiring.remove(id)
        voiceFades[id]?.cancel(); voiceFades[id] = nil
        if let node = nodes.removeValue(forKey: id) {
            (node as? AVAudioPlayerNode)?.stop(); engine.disconnectNodeOutput(node); engine.detach(node)
        }
        if let mixer = mixers.removeValue(forKey: id) { engine.disconnectNodeOutput(mixer); engine.detach(mixer) }
        buffers[id] = nil
        fileLoops[id] = nil
        completedFileCycles[id] = nil
        if resume && !nodes.isEmpty {
            do { try engine.start() }
            catch { errors["session"] = "Audio could not resume. Try playing again." }
        }
    }
    private func attach(_ node: AVAudioNode, id: String, format: AVAudioFormat) throws {
        if engine.isRunning { engine.pause() }
        let mixer = AVAudioMixerNode()
        engine.attach(node); engine.attach(mixer)
        do {
            try connect(node, to: mixer, bus: 0, format: format)
            if let point = spatialPositions[id] {
                // The mixer converts recording rates to the environment's rate.
                let rate = environment.outputFormat(forBus: 0).sampleRate
                guard let mono = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else { throw DriftAudioFailure.connection }
                try connect(mixer, to: environment, bus: environment.nextAvailableInputBus, format: mono)
                mixer.renderingAlgorithm = .auto
                mixer.position = AVAudio3DPoint(x: point.x, y: 0, z: point.z)
            } else {
                try connect(mixer, to: engine.mainMixerNode, bus: engine.mainMixerNode.nextAvailableInputBus, format: format)
            }
        } catch {
            engine.detach(node); engine.detach(mixer)
            throw error
        }
        mixer.outputVolume = 0
        nodes[id] = node; mixers[id] = mixer
    }
    private func connect(_ source: AVAudioNode, to destination: AVAudioNode, bus: AVAudioNodeBus, format: AVAudioFormat) throws {
        if #available(iOS 27, *) {
            try engine.connectNode(source, to: destination, fromBus: 0, toBus: bus, format: format)
        } else {
            engine.connect(source, to: destination, fromBus: 0, toBus: bus, format: format)
        }
    }
    /// The legacy play() API aborts on an invalid graph. In particular, the
    /// engine may have stopped during asynchronous file preparation or a route change.
    func startPlayer(_ player: AVAudioPlayerNode) throws {
        guard player.engine === engine,
              !engine.outputConnectionPoints(for: player, outputBus: 0).isEmpty else { throw DriftAudioFailure.connection }
        #if DEBUG
        if simulateEngineStopBeforePlayerStart { simulateEngineStopBeforePlayerStart = false; engine.stop() }
        #endif
        if !engine.isRunning { try engine.start() }
        if #available(iOS 27, *) { try player.playAudio() }
        else { player.play() }
    }
    private func pump() {
        guard worker == nil else { return }
        worker = Task { [weak self] in
            guard let self else { return }
            while self.playing, let sound = self.desired.first(where: { self.nodes[$0.id] == nil && self.errors[$0.id] == nil && !self.finished.contains($0.id) }) {
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
                        try self.attach(player, id: sound.id, format: loop.file.processingFormat)
                        self.fileLoops[sound.id] = loop
                        self.buffers[sound.id] = loop.seam
                        // Keep three cycles queued so scheduling never waits for
                        // the last sample to reach the output device.
                        if sound.oneShot == true {
                            let offset = min(loop.file.length - 1, AVAudioFramePosition(max(0, sound.startOffsetSeconds ?? 0) * loop.file.processingFormat.sampleRate))
                            player.scheduleSegment(loop.file, startingFrame: offset, frameCount: AVAudioFrameCount(loop.file.length - offset), at: nil, completionCallbackType: .dataPlayedBack) { [weak self, weak player] _ in
                                Task { @MainActor in
                                    guard let self, let player, self.nodes[sound.id] === player else { return }
                                    self.finished.insert(sound.id); self.detach(sound.id)
                                }
                            }
                        } else {
                            for _ in 0..<3 { self.queueFileCycle(sound.id, player: player) }
                        }
                        try self.startPlayer(player)
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
                        try self.attach(source, id: sound.id, format: format)
                        if !self.engine.isRunning { try self.engine.start() }
                    }
                    self.setVolume(sound.id, self.volumes[sound.id] ?? 0.25)
                    self.didStartVoice?(sound.id)
                } catch {
                    self.detach(sound.id)
                    if self.playing && !self.nodes.isEmpty && !self.engine.isRunning {
                        do { try self.engine.start() }
                        catch { self.errors["session"] = "Audio could not resume. Try playing again."; self.pause(immediate: true) }
                    }
                    if ticket == self.revision && self.desired.contains(where: { $0.id == sound.id }) { self.errors[sound.id] = error.localizedDescription }
                }
                self.loading.remove(sound.id)
            }
            self.worker = nil
            if self.playing && self.nodes.isEmpty && !self.desired.isEmpty && self.desired.allSatisfy({ self.errors[$0.id] != nil }) { self.pause() }
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
        let url: URL
        if let fileName = sound.localFileName {
            guard StudioScene.safeAudioName(fileName) else { throw DriftAudioFailure.missing }
            url = StudioLibrary.recordingsURL.appendingPathComponent(fileName)
        } else {
            guard let asset = sound.asset, !asset.contains(".."), let resource = Bundle.main.resourceURL else { throw DriftAudioFailure.missing }
            url = resource.appendingPathComponent("Audio").appendingPathComponent(asset)
        }
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
    func refreshNowPlaying() { updateNowPlaying() }
    private func updateNowPlaying() {
        guard !desired.isEmpty else { MPNowPlayingInfoCenter.default().nowPlayingInfo = nil; return }
        let content = nowPlayingContent?()
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: content?.title ?? "Nodus Drift",
            MPMediaItemPropertyArtist: content?.subtitle ?? desired.map(\.name).joined(separator: " · "),
            MPNowPlayingInfoPropertyIsLiveStream: content?.duration == nil,
            MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0
        ]
        if let artwork = content?.artwork { info[MPMediaItemPropertyArtwork] = artwork }
        if let duration = content?.duration {
            info[MPMediaItemPropertyPlaybackDuration] = duration
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = content?.elapsed ?? 0
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
