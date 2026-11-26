// SPDX-License-Identifier: MIT
import Combine
import MediaPlayer

struct DriftNowPlayingContent {
    var title: String
    var subtitle: String
    var artwork: MPMediaItemArtwork?
    var duration: Double?
    var elapsed: Double = 0
}

@MainActor final class DriftPlaybackMetadata {
    private let store: DriftStore
    private let studio: StudioStore
    private let artwork: DriftArtwork
    private var observations = Set<AnyCancellable>()
    private var loadedLandscape: StudioLandscape?
    private var mediaArtwork: MPMediaItemArtwork?
    private var artworkTask: Task<Void, Never>?

    init(store: DriftStore, studio: StudioStore, artwork: DriftArtwork) {
        self.store = store; self.studio = studio; self.artwork = artwork
        store.audio.nowPlayingContent = { [weak self] in self?.content() }
        Publishers.Merge3(store.$config.map { _ in () }, studio.$scene.map { _ in () },
                          store.audio.$owner.map { _ in () })
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.refresh() }.store(in: &observations)
        studio.$time.throttle(for: .seconds(1), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in
                guard let self, self.store.audio.owner == .studio else { return }
                self.store.audio.refreshNowPlaying()
            }.store(in: &observations)
        refresh()
    }

    private func content() -> DriftNowPlayingContent {
        if store.audio.owner == .studio {
            return DriftNowPlayingContent(title: studio.scene.name, subtitle: "Nodus Drift · Soundscape Studio",
                artwork: loadedLandscape == studio.scene.visuals.landscape ? mediaArtwork : nil,
                duration: studio.scene.repeats ? nil : studio.scene.duration, elapsed: studio.time)
        }
        return DriftNowPlayingContent(title: store.playbackName, subtitle: "Nodus Drift · " + store.summary,
            artwork: loadedLandscape == store.meditationScene.visuals.landscape ? mediaArtwork : nil)
    }

    private func refresh() {
        let landscape = store.audio.owner == .studio ? studio.scene.visuals.landscape : store.meditationScene.visuals.landscape
        if loadedLandscape != landscape {
            artworkTask?.cancel(); loadedLandscape = landscape; mediaArtwork = nil
            artworkTask = Task { [weak self] in
                guard let self, let image = await self.artwork.cover(landscape), !Task.isCancelled,
                      self.loadedLandscape == landscape else { return }
                self.mediaArtwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                self.store.audio.refreshNowPlaying()
            }
        }
        store.audio.refreshNowPlaying()
    }
}
