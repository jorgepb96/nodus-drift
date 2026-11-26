// SPDX-License-Identifier: MIT
import AVFoundation
import SoundAnalysis
import Foundation

enum StudioAudioQuality {
    /// Reject likely speech/singing using Apple's local classifier. This is a
    /// probabilistic safeguard in addition to the instrumental generation prompt.
    static func checkForVoices(_ channels: [[Float]], sampleRate: Int) throws {
        guard channels.count == 2, channels[0].count == channels[1].count,
              let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192) else { throw DriftAudioFailure.corrupt }
        let analyzer = SNAudioStreamAnalyzer(format: format)
        let observer = VoiceResults()
        let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
        try analyzer.add(request, withObserver: observer)
        defer { analyzer.removeAllRequests() }
        var frame = 0
        while frame < channels[0].count {
            try Task.checkCancellation()
            let count = min(8192, channels[0].count - frame)
            buffer.frameLength = AVAudioFrameCount(count)
            for index in 0..<count { buffer.floatChannelData![0][index] = (channels[0][frame + index] + channels[1][frame + index]) * 0.5 }
            analyzer.analyze(buffer, atAudioFramePosition: AVAudioFramePosition(frame)); frame += count
        }
        analyzer.completeAnalysis()
        let result = observer.snapshot()
        if let error = result.error { throw error }
        guard result.windows > 0 else { throw StudioError.invalid("The local sound check could not finish. Try generating again.") }
        guard Double(result.voiced) / Double(result.windows) <= 0.15 else {
            throw StudioError.invalid("The result may contain speech or singing. Try a more specific instrumental or environmental prompt.")
        }
    }

    private final class VoiceResults: NSObject, SNResultsObserving, @unchecked Sendable {
        private let lock = NSLock()
        private var windows = 0
        private var voiced = 0
        private var error: Error?
        func request(_ request: SNRequest, didProduce result: SNResult) {
            guard let classifications = result as? SNClassificationResult else { return }
            let confidence = max(classifications.classification(forIdentifier: "speech")?.confidence ?? 0,
                                 classifications.classification(forIdentifier: "singing")?.confidence ?? 0)
            lock.lock(); windows += 1; if confidence >= 0.5 { voiced += 1 }; lock.unlock()
        }
        func request(_ request: SNRequest, didFailWithError error: Error) { lock.lock(); self.error = error; lock.unlock() }
        func requestDidComplete(_ request: SNRequest) {}
        func snapshot() -> (windows: Int, voiced: Int, error: Error?) {
            lock.lock(); defer { lock.unlock() }; return (windows, voiced, error)
        }
    }
}
