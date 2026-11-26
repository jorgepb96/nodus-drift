// SPDX-License-Identifier: MIT
import CarPlay
import Combine

@MainActor final class DriftCarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var browser: DriftCarPlayBrowser?

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        let browser = DriftCarPlayBrowser(session: .shared)
        self.browser = browser
        browser.connect(interfaceController)
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnect interfaceController: CPInterfaceController) {
        browser?.disconnect(); browser = nil
    }
}

/// An audio-template browser. There is deliberately no custom window, animation,
/// editor, model download, or generation flow on the vehicle's display.
@MainActor final class DriftCarPlayBrowser {
    private let session: DriftSession
    private weak var interface: CPInterfaceController?
    private let home = CPListTemplate(title: "Nodus Drift", sections: [])
    private let saved = CPListTemplate(title: "My mixes", sections: [])
    private let explore = CPListTemplate(title: "Explore", sections: [])
    private var subscriptions = Set<AnyCancellable>()
    private var refreshTask: Task<Void, Never>?
    private var playbackTask: Task<Void, Never>?

    init(session: DriftSession) { self.session = session }

    func connect(_ interface: CPInterfaceController) {
        self.interface = interface
        home.tabTitle = "Home"; home.tabImage = UIImage(systemName: "house")
        saved.tabTitle = "My mixes"; saved.tabImage = UIImage(systemName: "square.grid.2x2")
        explore.tabTitle = "Explore"; explore.tabImage = UIImage(systemName: "leaf")
        let nowPlaying = CPNowPlayingTemplate.shared
        nowPlaying.isUpNextButtonEnabled = false; nowPlaying.isAlbumArtistButtonEnabled = false
        nowPlaying.updateNowPlayingButtons([])
        // Respect runtime limits rather than assuming a particular car/display.
        let tabs = Array([home, saved, explore].prefix(max(1, CPTabBarTemplate.maximumTabCount)))
        interface.setRootTemplate(CPTabBarTemplate(templates: tabs), animated: false, completion: nil)
        Publishers.MergeMany([
            session.store.$config.map { _ in () }.eraseToAnyPublisher(),
            session.studio.$saved.map { _ in () }.eraseToAnyPublisher(),
            session.studio.$scene.map { _ in () }.eraseToAnyPublisher(),
            session.store.audio.$owner.map { _ in () }.eraseToAnyPublisher(),
            session.store.audio.$playing.map { _ in () }.eraseToAnyPublisher(),
            session.carPlay.$recentIDs.map { _ in () }.eraseToAnyPublisher()
        ]).debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] in self?.refresh() }.store(in: &subscriptions)
        refresh()
    }

    func disconnect() {
        refreshTask?.cancel(); playbackTask?.cancel(); subscriptions.removeAll(); interface = nil
        // Disconnecting the screen never replaces or restarts the phone's session.
    }

    private func refresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self, let interface = self.interface else { return }
            let library = self.session.carPlay
            let mixes = library.mixes, scenes = library.scenes, places = library.explore, recents = library.recents
            let entries = mixes + scenes + places + recents
            let scale = interface.carTraitCollection.displayScale
            let pixels = Self.thumbnailPixels(scale: scale)
            for landscape in Set(entries.map(\.landscape)) {
                _ = await self.session.artwork.cover(landscape, pixels: pixels)
                guard !Task.isCancelled, self.interface != nil else { return }
            }
            var homeSections: [CPListSection] = []
            if let current = library.current {
                let row = CPListItem(text: "Continue listening", detailText: current.title,
                                     image: self.image(current, pixels: pixels))
                row.handler = { [weak self] _, completion in self?.start(current.id, completion: completion) ?? completion() }
                homeSections.append(CPListSection(items: [row]))
            }
            if !recents.isEmpty { homeSections.append(self.section("Recently played", entries: recents, pixels: pixels)) }
            if homeSections.isEmpty { homeSections = [self.section("Places to begin", entries: places, pixels: pixels)] }
            self.home.updateSections(homeSections)
            var sections: [CPListSection] = []
            if !mixes.isEmpty { sections.append(self.section("Saved mixes", entries: mixes, pixels: pixels)) }
            if !scenes.isEmpty { sections.append(self.section("Studio scenes", entries: scenes, pixels: pixels)) }
            if sections.isEmpty {
                let empty = CPListItem(text: "No saved mixes yet", detailText: "Explore ready-to-play soundscapes.")
                empty.isEnabled = false; sections = [CPListSection(items: [empty])]
            }
            self.saved.updateSections(sections)
            self.explore.updateSections([self.section("Soundscapes", entries: places, pixels: pixels)])
        }
    }

    static func thumbnailPixels(scale: CGFloat) -> Int {
        let size: CGSize
        if #available(iOS 26.0, *) { size = CPListImageRowItemImageGridElement.maximumImageSize }
        else { size = CPListImageRowItem.maximumImageSize }
        return min(768, max(128, Int(ceil(max(size.width, size.height) * max(1, scale)))))
    }

    private func image(_ entry: DriftCarPlayEntry, pixels: Int) -> UIImage {
        session.artwork.cached(entry.landscape, pixels: pixels) ?? UIImage(systemName: entry.landscape.icon) ?? UIImage()
    }

    /// Multi-line native artwork grids on iOS 26; titled image rows on 17.4+;
    /// named thumbnail rows on 17.0. No custom-drawn CarPlay interface.
    func section(_ title: String, entries: [DriftCarPlayEntry], pixels: Int) -> CPListSection {
        let rows = Self.chunks(entries, limit: CPMaximumNumberOfGridImages).map { chunk -> CPListTemplateItem in
            let row: CPListImageRowItem
            if #available(iOS 26.0, *) {
                let elements = chunk.map { entry in
                    let element = CPListImageRowItemImageGridElement(image: image(entry, pixels: pixels),
                        imageShape: .roundedRectangle, title: entry.title, accessorySymbolName: nil)
                    element.isEnabled = entry.isAvailable()
                    if #available(iOS 26.4, *) { element.accessibilityLabel = entry.title }
                    return element
                }
                row = CPListImageRowItem(text: nil, imageGridElements: elements, allowsMultipleLines: true)
            } else if #available(iOS 17.4, *) {
                row = CPListImageRowItem(text: "", images: chunk.map { image($0, pixels: pixels) }, imageTitles: chunk.map(\.title))
            } else {
                // This branch is handled below to keep every item labelled.
                return CPListItem(text: "", detailText: nil)
            }
            row.listImageRowHandler = { [weak self] _, index, completion in
                guard chunk.indices.contains(index), let self else { completion(); return }
                self.start(chunk[index].id, completion: completion)
            }
            return row
        }
        if #available(iOS 17.4, *) {
            return CPListSection(items: Array(rows.prefix(CPListTemplate.maximumItemCount)), header: title, sectionIndexTitle: nil)
        }
        let items = entries.prefix(CPListTemplate.maximumItemCount).map { entry in
            let row = CPListItem(text: entry.title, detailText: nil, image: image(entry, pixels: pixels))
            row.isEnabled = entry.isAvailable()
            row.handler = { [weak self] _, completion in self?.start(entry.id, completion: completion) ?? completion() }
            return row
        }
        return CPListSection(items: items, header: title, sectionIndexTitle: nil)
    }

    static func chunks<T>(_ entries: [T], limit: Int) -> [[T]] {
        let width = max(1, limit)
        return stride(from: 0, to: entries.count, by: width).map { Array(entries[$0..<min($0 + width, entries.count)]) }
    }

    private func start(_ id: String, completion: @escaping () -> Void) {
        playbackTask?.cancel()
        playbackTask = Task { [weak self] in
            defer { completion() }
            guard let self else { return }
            do {
                try self.session.carPlay.play(id)
                // Complete the native selection spinner only when audio is ready.
                for _ in 0..<150 {
                    try Task.checkCancellation()
                    let audio = self.session.store.audio
                    if !audio.errors.isEmpty { throw StudioError.invalid("This soundscape could not start. Try another from your library or Explore.") }
                    if !audio.playing { return } // An explicit pause cancels loading without an error alert.
                    if audio.playing && audio.activeVoiceCount > 0 {
                        guard let interface = self.interface else { return }
                        if interface.topTemplate !== CPNowPlayingTemplate.shared {
                            interface.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
                        }
                        return
                    }
                    try await Task.sleep(for: .milliseconds(100))
                }
                throw StudioError.invalid("Audio is taking too long to start. Please try again.")
            } catch is CancellationError { return }
            catch {
                guard let interface = self.interface else { return }
                let dismiss = CPAlertAction(title: "OK", style: .default) { [weak self] _ in
                    self?.interface?.dismissTemplate(animated: true, completion: nil)
                }
                interface.presentTemplate(CPAlertTemplate(titleVariants: [error.localizedDescription], actions: [dismiss]),
                                          animated: true, completion: nil)
            }
        }
    }
}
