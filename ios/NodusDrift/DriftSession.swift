// SPDX-License-Identifier: MIT
import Foundation

/// The phone and the CarPlay scene share one transport, library and Studio clock.
@MainActor final class DriftSession {
    static let shared = DriftSession()
    let store: DriftStore
    let studio: StudioStore
    let artwork = DriftArtwork()
    let metadata: DriftPlaybackMetadata
    let carPlay: DriftCarPlayLibrary

    init(defaults: UserDefaults = .standard, library: StudioLibrary = StudioLibrary()) {
        let store = DriftStore(defaults: defaults)
        let studio = StudioStore(audio: store.audio, library: library)
        self.store = store; self.studio = studio
        metadata = DriftPlaybackMetadata(store: store, studio: studio, artwork: artwork)
        carPlay = DriftCarPlayLibrary(store: store, studio: studio, defaults: defaults)
    }
}
