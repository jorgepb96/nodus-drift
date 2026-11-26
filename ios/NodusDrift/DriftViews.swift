// SPDX-License-Identifier: MIT
import SwiftUI

extension View {
    func driftPanel() -> some View {
        self.background(DriftTheme.panel, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(DriftTheme.line, lineWidth: 1))
    }
    func driftPageLayout() -> some View {
        self.frame(maxWidth: .infinity, alignment: .leading)
            .padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
    }
}

/// Each destination opens at its beginning without discarding its filters or edits.
struct DriftTabScrollView<Content: View>: View {
    @EnvironmentObject private var store: DriftStore
    let tab: Int
    @ViewBuilder var content: (ScrollViewProxy) -> Content
    private var top: String { "drift-tab-top-\(tab)" }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView { content(proxy).id(top) }
                .contentShape(Rectangle())
                .onAppear { if store.tab == tab { proxy.scrollTo(top, anchor: .top) } }
                .onChange(of: store.tab) { _, selected in
                    if selected == tab { proxy.scrollTo(top, anchor: .top) }
                }
        }
    }
}

/// Shared scale and margins for the mixer and saved soundscapes.
private struct DriftPageHeader: View {
    let title: String
    let subtitle: String
    @ScaledMetric(relativeTo: .largeTitle) private var headingSize = 35.0
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: headingSize, design: .serif)).tracking(-0.8)
            Text(subtitle).font(.subheadline).foregroundStyle(DriftTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DriftEmptyState: View {
    let title: String
    let icon: String
    let description: String
    let actionTitle: String
    let action: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            NodiCompanion()
            ContentUnavailableView(title, systemImage: icon, description: Text(description))
            Button(action: action) {
                Text(actionTitle).frame(maxWidth: .infinity).padding(18)
                    .foregroundStyle(DriftTheme.background)
                    .background(DriftTheme.accent, in: Capsule())
            }
        }.frame(maxWidth: .infinity)
    }
}

struct DriftRootView: View {
    @ObservedObject var store: DriftStore
    @ObservedObject private var audio: DriftAudioEngine
    @ObservedObject private var studio: StudioStore
    init(store: DriftStore, studio: StudioStore) {
        self.store = store; audio = store.audio
        self.studio = studio
    }
    var body: some View {
        TabView(selection: $store.tab) {
            NavigationStack { SoundsView() }.tag(0).tabItem { Label("Sounds", systemImage: "waveform") }
            NavigationStack { MixView() }.tag(1).tabItem { Label("My mix", systemImage: "slider.horizontal.3") }
            NavigationStack { StudioView(studio: studio) }.tag(4).tabItem { Label("Studio", systemImage: "sparkles.rectangle.stack") }
            NavigationStack { SavedView() }.tag(2).tabItem { Label("Saved", systemImage: "bookmark") }
            NavigationStack { SettingsView(studio: studio) }.tag(3).tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .environmentObject(store).environmentObject(audio).environmentObject(studio)
        .onOpenURL { url in
            do { try studio.importScene(from: url); store.tab = 4 }
            catch { store.notice = error.localizedDescription }
        }
        .foregroundStyle(DriftTheme.text)
        .fullScreenCover(isPresented: $store.immersive) { ImmersiveView().environmentObject(store).environmentObject(audio) }
        .fullScreenCover(isPresented: $studio.immersive) { StudioImmersiveView(studio: studio) }
        .alert("A little heads-up", isPresented: Binding(get: { store.notice != nil }, set: { if !$0 { store.notice = nil } })) {
            Button("Got it", role: .cancel) { store.notice = nil }
        } message: { Text(store.notice ?? "") }
    }
}

struct DriftBrand: View {
    var body: some View {
        HStack(spacing: 7) {
            NodusMark().frame(width: 19, height: 21)
            Text("NODUS").font(.system(size: 11, weight: .semibold)).tracking(3)
            Text("/ DRIFT").font(.system(size: 10, weight: .medium)).tracking(2).foregroundStyle(DriftTheme.muted)
        }.foregroundStyle(DriftTheme.accent).fixedSize().accessibilityElement(children: .combine)
            .accessibilityLabel("Nodus Drift").accessibilityIdentifier("nodus-brand")
    }
}

/// The same canvas dimensions keep Nodi's actual drawing scale identical on tabs.
struct NodiCompanion: View {
    var awake = false
    var body: some View { NodiView(awake: awake).frame(height: 185).frame(maxWidth: .infinity) }
}

struct BrandToolbar: ViewModifier {
    @EnvironmentObject var store: DriftStore
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .principal) {
                DriftBrand()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { store.immersive = true } label: { Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 16)).frame(width: 44, height: 44) }
                    .accessibilityLabel("Enter meditation mode").accessibilityIdentifier("enter-meditation")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(DriftTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(DriftTheme.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

struct SoundsView: View {
    @EnvironmentObject private var store: DriftStore
    @EnvironmentObject private var audio: DriftAudioEngine
    @State private var search = ""
    @State private var category = "all"
    @State private var favoritesOnly = false
    @State private var awake = false
    @State private var wakeTask: Task<Void, Never>?
    @State private var filterTask: Task<Void, Never>?
    @State private var controlsHeight: CGFloat = 180
    @State private var libraryOffset: CGFloat = .infinity
    @FocusState private var searchFocused: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var headingSize = 39.0
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var compactLandscape: Bool { verticalSizeClass == .compact }
    private var filtered: [DriftSound] {
        let query = search.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en"))
        return store.sorted(DriftCatalog.sounds.filter {
            (category == "all" || $0.category == category) && (!favoritesOnly || store.config.favorites.contains($0.id)) &&
            (query.isEmpty || "\($0.name) \($0.detail) \(DriftCatalog.categoryName($0.category))".folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en")).contains(query))
        })
    }
    private var libraryRevision: [String] {
        // A filter choice also resets the results when it happens to match the
        // same sounds, for example when all 89 sounds are favorites.
        [search, category, String(favoritesOnly), store.config.sort.rawValue] + filtered.map(\.id)
    }
    var body: some View {
        GeometryReader { viewport in
            // Compact-height windows use normal document flow. A pinned search
            // panel must never reserve the space needed to read a whole card.
            let pinControls = !compactLandscape
            ZStack(alignment: .top) {
                DriftTabScrollView(tab: 0) { proxy in
                    // Eager section geometry prevents a shrinking lazy grid from
                    // retaining an estimated origin thousands of points away.
                    VStack(alignment: .leading, spacing: compactLandscape ? 12 : 24) {
                        companion
                        starters
                        if compactLandscape {
                            // Use intrinsic height directly, rather than keeping
                            // a portrait-sized placeholder after rotation.
                            libraryControls
                                .background(GeometryReader { geometry in
                                    Color.clear.preference(key: LibraryControlsPositionKey.self,
                                                           value: geometry.frame(in: .named("sounds-viewport")).minY)
                                })
                                .id("sound-library")
                        } else {
                        Color.clear.frame(height: controlsHeight)
                            .background(GeometryReader { geometry in
                                Color.clear.preference(key: LibraryControlsPositionKey.self,
                                                       value: geometry.frame(in: .named("sounds-viewport")).minY)
                            })
                            .overlay(alignment: .top) {
                                // Keep the controls in the scroll view's gesture
                                // hierarchy while pinning their rendered position.
                                libraryControls.fixedSize(horizontal: false, vertical: true)
                                    .offset(y: pinControls && libraryOffset.isFinite ? max(0, -libraryOffset) : 0)
                            }
                            .zIndex(1)
                            .id("sound-library")
                        }
                        libraryResults(minimumHeight: max(0, viewport.size.height - (pinControls ? controlsHeight + 32 : 16)))
                            .id(filtered.map(\.id)).id("sound-results")
                    }.padding(.horizontal, 24).padding(.top, compactLandscape ? 8 : 18).padding(.bottom, 24)
                        .frame(maxWidth: 860).frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onChange(of: libraryRevision) { _, _ in
                            filterTask?.cancel()
                            filterTask = Task {
                                await Task.yield()
                                if !Task.isCancelled && store.tab == 0 && libraryOffset <= 1 {
                                    proxy.scrollTo(pinControls ? "sound-library" : "sound-results", anchor: .top)
                                }
                            }
                        }
                        .onChange(of: verticalSizeClass) { _, _ in
                            guard libraryOffset <= 1 else { return }
                            filterTask?.cancel()
                            filterTask = Task {
                                await Task.yield()
                                if !Task.isCancelled && store.tab == 0 {
                                    proxy.scrollTo(pinControls ? "sound-library" : "sound-results", anchor: .top)
                                }
                            }
                        }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .coordinateSpace(name: "sounds-viewport")
            .clipped()
        }
        .background(DriftTheme.background)
        .safeAreaInset(edge: .bottom, spacing: 0) { if !store.selection.isEmpty || audio.owner == .studio { MiniPlayer() } }
        .modifier(BrandToolbar())
        .onPreferenceChange(LibraryControlsHeightKey.self) { height in
            // Only the portrait pinned header needs a placeholder. Do not carry
            // a compact row's height back into the portrait layout after rotation.
            if height > 0 && !compactLandscape { controlsHeight = height }
        }
        .onPreferenceChange(LibraryControlsPositionKey.self) { top in
            if top.isFinite { libraryOffset = top }
        }
        .onDisappear { wakeTask?.cancel(); filterTask?.cancel(); awake = false }
        .onChange(of: store.selection) { _, _ in searchFocused = false }
    }
    // Filtering retains the introduction and the persistent library controls.
    private var companion: some View {
    VStack(spacing: 0) {
        HStack {
            VStack(alignment: .leading, spacing: 7) {
                Text("A little space\nto be.").font(.system(size: headingSize, weight: .regular, design: .serif)).tracking(-1.2)
                Text("Sounds for reading, focus & rest.").font(.subheadline).foregroundStyle(DriftTheme.muted)
            }
            Spacer(minLength: 0)
        }
        Button {
            awake = true; store.feedback(); wakeTask?.cancel()
            wakeTask = Task { try? await Task.sleep(for: .milliseconds(2500)); if !Task.isCancelled { awake = false } }
        } label: {
            NodiCompanion(awake: awake)
        }.buttonStyle(.plain).accessibilityLabel("Wake Nodi").accessibilityIdentifier("wake-nodi")
        HStack(spacing: 6) {
            Circle().fill(DriftTheme.accent).frame(width: 5, height: 5)
            Text("YOUR QUIET COMPANION").font(.system(size: 9, weight: .medium)).tracking(2.2).foregroundStyle(DriftTheme.muted)
        }.padding(.top, -3)
    }
    }
    private var libraryControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            if compactLandscape && !typeSize.isAccessibilitySize {
                HStack(spacing: 12) {
                    librarySearchControls.frame(width: 240)
                    libraryCategories
                }
            } else {
                if !compactLandscape {
                    HStack {
                        Text("Find your sound").font(.system(size: 25, design: .serif))
                        Spacer()
                        Text("89 SOUNDS").font(.system(size: 9, weight: .medium)).tracking(1.8).foregroundStyle(DriftTheme.muted)
                    }
                }
                librarySearchControls
                libraryCategories
            }
        }.padding(.bottom, compactLandscape ? 8 : 16).background(DriftTheme.background)
            .background(GeometryReader { geometry in
                Color.clear.preference(key: LibraryControlsHeightKey.self, value: geometry.size.height)
            })
            .accessibilityElement(children: .contain).accessibilityIdentifier("sound-library-controls")
    }
    private var librarySearchControls: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(DriftTheme.muted)
                TextField("Search sounds", text: $search).font(.subheadline).autocorrectionDisabled().focused($searchFocused).submitLabel(.search).onSubmit { searchFocused = false }.accessibilityIdentifier("sound-search")
                if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Clear search") }
            }.padding(14).background(DriftTheme.panel, in: Capsule()).overlay(Capsule().stroke(DriftTheme.line))
            Menu {
                Picker("Sort by", selection: Binding(get: { store.config.sort }, set: store.setSort)) {
                    ForEach(DriftSort.allCases) { Text($0.title).tag($0) }
                }
            } label: { Image(systemName: "arrow.up.arrow.down").frame(width: 44, height: 44).background(DriftTheme.panel, in: Circle()) }
                .accessibilityLabel("Sort sounds").accessibilityIdentifier("sort-sounds")
        }
    }
    private var libraryCategories: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip("All", icon: "square.grid.2x2", selected: category == "all" && !favoritesOnly) { category = "all"; favoritesOnly = false }
                filterChip("Favorites", icon: "heart", selected: favoritesOnly) { category = "all"; favoritesOnly = true }
                ForEach(DriftCatalog.categories, id: \.id) { item in
                    filterChip(item.name, icon: item.icon, selected: category == item.id && !favoritesOnly) { category = item.id; favoritesOnly = false }
                }
            }
        }.frame(height: 44).contentMargins(.trailing, 3)
    }
    private func libraryResults(minimumHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
        if category == "binaural" {
            Label("Use stereo headphones to hear the separate tones.", systemImage: "headphones").font(.footnote).foregroundStyle(DriftTheme.muted)
        }
        if DriftCatalog.sounds.isEmpty {
            ContentUnavailableView("The sound library is missing", systemImage: "waveform", description: Text("Reinstall the app to restore its offline library."))
        } else if filtered.isEmpty {
            ContentUnavailableView(favoritesOnly && search.isEmpty ? "Keep your favorites close" : "No sounds found", systemImage: favoritesOnly ? "heart" : "magnifyingglass", description: Text(favoritesOnly && search.isEmpty ? "Tap the heart on a sound to find it here." : "Try a different search or category."))
        } else {
            LazyVGrid(columns: typeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                ForEach(filtered) { SoundCard(sound: $0) }
            }
        }
        Text("Mix up to 6 sounds. Make this moment yours.").font(.footnote).foregroundStyle(DriftTheme.muted).frame(maxWidth: .infinity).padding(.vertical, 12)
        }.frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .topLeading)
    }
    private var starters: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("A PLACE TO BEGIN").font(.system(size: 10, weight: .medium)).tracking(2).foregroundStyle(DriftTheme.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    starter("Rainy pages", detail: "Rain · brown noise", icon: "book", ids: ["light-rain", "brown-noise"], color: 0x21352F)
                    starter("By the sea", detail: "Waves · seabirds", icon: "water.waves", ids: ["waves", "seagulls"], color: 0x233439)
                    starter("Nightfall", detail: "Crickets · gentle wind", icon: "moon", ids: ["crickets", "wind"], color: 0x302D36)
                }
            }
        }
    }
    private func starter(_ name: String, detail: String, icon: String, ids: [String], color: UInt32) -> some View {
        Button {
            store.load(DriftPreset(name: name, icon: icon, selection: ids, volumes: [:], master: 0.35))
        } label: {
            VStack(alignment: .leading, spacing: 13) {
                HStack { Image(systemName: icon).font(.system(size: 22, weight: .light)); Spacer(); Image(systemName: "arrow.up.right").font(.system(size: 12)) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(name).font(.system(size: 17, weight: .medium, design: .serif))
                    Text(detail).font(.system(size: 10)).foregroundStyle(DriftTheme.muted)
                }
            }.padding(18).frame(width: 167).background(Color(hex: color), in: RoundedRectangle(cornerRadius: 20)).foregroundStyle(DriftTheme.accent)
        }.buttonStyle(.plain).accessibilityLabel("Load \(name)").accessibilityIdentifier("starter-\(ids[0])")
    }
    private func filterChip(_ text: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(text, systemImage: icon).font(.system(size: 12, weight: .medium)).padding(.horizontal, 15).frame(minHeight: 44)
                .background(selected ? DriftTheme.accent : DriftTheme.panel, in: Capsule()).foregroundStyle(selected ? DriftTheme.background : DriftTheme.muted)
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : []).accessibilityIdentifier("filter-\(text.lowercased())")
    }
}

private struct LibraryControlsHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct LibraryControlsPositionKey: PreferenceKey {
    static var defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = min(value, nextValue()) }
}

struct SoundCard: View {
    let sound: DriftSound
    @EnvironmentObject private var store: DriftStore
    @EnvironmentObject private var audio: DriftAudioEngine
    @ScaledMetric(relativeTo: .body) private var nameSize = 14.0
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    private var compactLandscape: Bool { verticalSizeClass == .compact && !typeSize.isAccessibilitySize }
    private var selected: Bool { store.selection.contains(sound.id) }
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button { store.toggle(sound.id) } label: {
                VStack(alignment: .leading, spacing: compactLandscape ? 10 : 16) {
                    Image(systemName: sound.icon).font(.system(size: compactLandscape ? 24 : 28, weight: .ultraLight))
                        .frame(height: compactLandscape ? 28 : 32).foregroundStyle(DriftTheme.accent)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(sound.name).font(.system(size: nameSize, weight: .medium))
                            .foregroundStyle(DriftTheme.text).fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 5) {
                            if selected { Circle().fill(DriftTheme.accent).frame(width: 4, height: 4) }
                            Text(selected ? (audio.loading.contains(sound.id) ? "Loading…" : audio.errors[sound.id] != nil ? "Tap to remove" : audio.listening ? "In your mix" : "Paused") : DriftCatalog.categoryName(sound.category))
                                .font(.system(size: 11)).foregroundStyle(DriftTheme.muted)
                        }
                    }
                    // Reserve the volume row in both states so selection does
                    // not move nearby cards under the user's finger.
                    Color.clear.frame(height: compactLandscape ? 24 : 28)
                }.padding(compactLandscape ? 14 : 18).frame(maxWidth: .infinity, minHeight: compactLandscape ? 132 : 148, alignment: .topLeading)
                    .contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityLabel("\(selected ? "Remove" : "Add") \(sound.name)")
                .accessibilityValue(selected ? "Selected" : "Not selected")
                .accessibilityHint(sound.detail).accessibilityIdentifier("sound-\(sound.id)")
            Button { store.favorite(sound.id) } label: {
                Image(systemName: store.config.favorites.contains(sound.id) ? "heart.fill" : "heart")
                    .font(.system(size: 13)).frame(width: 44, height: 44)
                    .foregroundStyle(store.config.favorites.contains(sound.id) ? DriftTheme.accent : DriftTheme.muted.opacity(0.8))
                    .contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityLabel("\(store.config.favorites.contains(sound.id) ? "Unfavorite" : "Favorite") \(sound.name)")
                .accessibilityIdentifier("favorite-\(sound.id)").padding(6)
            if selected {
                VStack {
                    Spacer(minLength: 0)
                    Slider(value: Binding(get: { Double(store.volume(sound.id)) }, set: { store.setVolume(sound.id, Float($0)) }), in: 0...1)
                        .accessibilityLabel("\(sound.name) volume").accessibilityIdentifier("volume-\(sound.id)")
                        .padding(.horizontal, 18).padding(.bottom, 10)
                }
            }
        }
        .background(selected ? Color(hex: 0x20312C) : DriftTheme.panel, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(selected ? DriftTheme.accent.opacity(0.4) : DriftTheme.line, lineWidth: 1))
    }
}

struct MiniPlayer: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var compactLandscape: Bool { verticalSizeClass == .compact }
    @EnvironmentObject private var store: DriftStore
    @EnvironmentObject private var audio: DriftAudioEngine
    @EnvironmentObject private var studio: StudioStore
    var body: some View {
        let sceneOwned = audio.owner == .studio
        let active = sceneOwned ? studio.playing : audio.listening
        HStack(spacing: 8) {
            Button { store.tab = sceneOwned ? 4 : 1 } label: {
                HStack(spacing: 10) {
                    Image(systemName: active ? "waveform" : "headphones").font(.system(size: 22, weight: .light)).foregroundStyle(DriftTheme.accent).frame(width: 38, height: 42)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Text(sceneOwned ? studio.scene.name : "Your soundscape").font(.system(size: 14, weight: .medium)).lineLimit(1)
                            if !sceneOwned { Text("\(store.selection.count)/6").font(.system(size: 10)).foregroundStyle(DriftTheme.muted) }
                        }
                        Text(sceneOwned ? studio.scene.layers.map(\.name).joined(separator: " · ") : store.summary)
                            .font(.system(size: 11)).foregroundStyle(DriftTheme.muted).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }.buttonStyle(.plain).accessibilityLabel(sceneOwned ? "Open your scene" : "Open your mix")
            Button {
                if sceneOwned { studio.immersive = true }
                else { store.setMeditationAppearance(.landscape); store.immersive = true }
            } label: {
                Image(systemName: "photo").font(.system(size: 20)).frame(width: 44, height: 48).foregroundStyle(DriftTheme.accent)
            }.accessibilityLabel("Open landscape").accessibilityIdentifier("mini-landscape")
            Button { if sceneOwned { studio.togglePlayback() } else { store.togglePlayback() } } label: {
                Image(systemName: active ? "pause.fill" : "play.fill").font(.system(size: 16)).frame(width: 48, height: 48).foregroundStyle(DriftTheme.background).background(DriftTheme.accent, in: Circle())
            }.accessibilityLabel(active ? "Pause mix" : "Play mix").accessibilityIdentifier("mini-play")
        }.padding(compactLandscape ? 4 : 12).background(Color(hex: 0x1C2A25), in: RoundedRectangle(cornerRadius: compactLandscape ? 18 : 24))
            .overlay(RoundedRectangle(cornerRadius: compactLandscape ? 18 : 24).stroke(DriftTheme.accent.opacity(0.13)))
            .padding(.horizontal, 16).padding(.vertical, compactLandscape ? 4 : 8).background(DriftTheme.background)
            .accessibilityElement(children: .contain).accessibilityIdentifier("mini-player")
    }
}

struct MixView: View {
    @EnvironmentObject private var store: DriftStore
    @EnvironmentObject private var audio: DriftAudioEngine
    @State private var save = false
    @State private var timer = false
    var body: some View {
        DriftTabScrollView(tab: 1) { _ in
            VStack(alignment: .leading, spacing: 24) {
                DriftPageHeader(title: "Your soundscape", subtitle: "A balance that feels like you.")
                if store.selection.isEmpty {
                    DriftEmptyState(title: "Start with a sound", icon: "waveform",
                                    description: "Choose up to 6 sounds, then adjust each one to find your quiet.",
                                    actionTitle: "Explore sounds") { store.tab = 0 }
                } else {
                    HStack(spacing: 12) {
                        Label("\(store.selection.count) of 6 sounds", systemImage: "waveform").font(.footnote).foregroundStyle(DriftTheme.accent)
                        Spacer()
                        Button { store.clear() } label: { Text("Clear").font(.footnote).padding(.vertical, 12) }.foregroundStyle(DriftTheme.muted)
                            .accessibilityIdentifier("clear-mix")
                    }
                    ForEach(store.sorted(store.activeSounds)) { sound in
                        VStack(spacing: 16) {
                            HStack(spacing: 14) {
                                Image(systemName: sound.icon).font(.system(size: 26, weight: .light)).foregroundStyle(DriftTheme.accent).frame(width: 42)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(sound.name).font(.system(size: 16, weight: .medium))
                                    Text(audio.loading.contains(sound.id) ? "Preparing your sound…" : sound.detail).font(.system(size: 11)).foregroundStyle(DriftTheme.muted)
                                }
                                Spacer()
                                Button { store.remove(sound.id) } label: { Image(systemName: "xmark").font(.system(size: 13)).frame(width: 44, height: 44) }
                                    .accessibilityLabel("Remove \(sound.name)").accessibilityIdentifier("remove-\(sound.id)")
                            }
                            HStack(spacing: 15) {
                                Image(systemName: "speaker.wave.1").font(.system(size: 13)).foregroundStyle(DriftTheme.muted)
                                Slider(value: Binding(get: { Double(store.volume(sound.id)) }, set: { store.setVolume(sound.id, Float($0)) }), in: 0...1).accessibilityLabel("\(sound.name) volume")
                                Text("\(Int(store.volume(sound.id) * 100))%").font(.system(size: 11, design: .monospaced)).foregroundStyle(DriftTheme.muted).frame(width: 35, alignment: .trailing)
                            }
                            if let error = audio.errors[sound.id] {
                                HStack { Text(error).font(.footnote); Spacer(); Button("Retry") { audio.retry(sound.id); if !audio.listening { store.togglePlayback() } } }.foregroundStyle(Color(hex: 0xE8BD99))
                            }
                        }.padding(18).driftPanel()
                            .accessibilityElement(children: .contain).accessibilityIdentifier("mix-card-\(sound.id)")
                    }
                    VStack(alignment: .leading, spacing: 15) {
                        HStack { Label("Master volume", systemImage: "speaker.wave.2").font(.subheadline); Spacer(); Text("\(Int(store.config.master * 100))%").font(.system(size: 12, design: .monospaced)).foregroundStyle(DriftTheme.accent) }
                        Slider(value: Binding(get: { Double(store.config.master) }, set: { store.setMaster(Float($0)) }), in: 0...1).accessibilityLabel("Master volume").accessibilityIdentifier("master-volume")
                    }.padding(20).driftPanel()
                    HStack(spacing: 12) {
                        Button { save = true } label: { Label("Save mix", systemImage: "bookmark").font(.subheadline).frame(maxWidth: .infinity).frame(height: 54).driftPanel() }
                            .disabled(store.config.presets.count >= 48).accessibilityIdentifier("save-mix")
                        Button { timer = true } label: { Label(timerLabel, systemImage: "moon.zzz").font(.subheadline).frame(maxWidth: .infinity).frame(height: 54).driftPanel() }.accessibilityIdentifier("sleep-timer")
                    }
                    if store.activeSounds.contains(where: { $0.kind == "binaural" }) {
                        Label("Binaural tones use two separate channels. Listen with stereo headphones.", systemImage: "headphones").font(.footnote).foregroundStyle(DriftTheme.muted)
                    }
                    if let error = audio.errors["session"] { Text(error).font(.footnote).foregroundStyle(Color(hex: 0xE8BD99)) }
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Make room for a quiet moment.").font(.system(size: 22, design: .serif))
                        MeditationAppearancePicker()
                        Text("Your landscape follows the sounds in this mix.").font(.footnote).foregroundStyle(DriftTheme.muted)
                        Button { store.immersive = true } label: { HStack { Image(systemName: "sparkles"); Text("Drift into meditation"); Spacer(); Image(systemName: "arrow.up.right") }.font(.subheadline).padding(.vertical, 12) }
                            .accessibilityIdentifier("drift-into-meditation")
                    }.padding(20).driftPanel()
                }
            }.driftPageLayout()
        }.background(DriftTheme.background).modifier(BrandToolbar())
        .safeAreaInset(edge: .bottom) {
            if !store.selection.isEmpty {
                Button { store.togglePlayback() } label: {
                    Label(audio.listening ? "Pause soundscape" : "Play soundscape", systemImage: audio.listening ? "pause.fill" : "play.fill").font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 58).foregroundStyle(DriftTheme.background).background(DriftTheme.accent, in: Capsule())
                }.accessibilityIdentifier("mix-play").padding(.horizontal, 24).padding(.vertical, 12).background(DriftTheme.background)
            }
        }
        .sheet(isPresented: $save) { PresetEditor() }
        .sheet(isPresented: $timer) { SleepTimerView() }
    }
    private var timerLabel: String {
        guard let seconds = store.remainingSeconds else { return "Sleep timer" }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct SavedView: View {
    @EnvironmentObject private var audio: DriftAudioEngine
    @EnvironmentObject private var store: DriftStore
    @State private var editing: DriftPreset?
    @State private var search = ""
    @ScaledMetric(relativeTo: .title3) private var presetTitleSize = 21.0
    private var presets: [DriftPreset] {
        let filtered = store.config.presets.filter { search.isEmpty || $0.name.localizedStandardContains(search) }
        switch store.config.sort {
        case .recommended: return filtered
        case .alphabetical: return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .type: return filtered.sorted { $0.icon == $1.icon ? $0.name < $1.name : $0.icon < $1.icon }
        case .usage: return filtered.sorted { store.config.presetUsage[$0.id, default: 0] == store.config.presetUsage[$1.id, default: 0] ? $0.name < $1.name : store.config.presetUsage[$0.id, default: 0] > store.config.presetUsage[$1.id, default: 0] }
        }
    }
    var body: some View {
        DriftTabScrollView(tab: 2) { _ in
            VStack(alignment: .leading, spacing: 24) {
                DriftPageHeader(title: "Quiet, on repeat.", subtitle: "Your favorite moments, saved for later.")
                if store.config.presets.isEmpty {
                    DriftEmptyState(title: "Make a moment worth keeping", icon: "bookmark",
                                    description: "Create a mix and tap Save mix. Its sounds and volumes will be waiting here.",
                                    actionTitle: "Create your first mix") { store.tab = 0 }
                } else {
                    HStack {
                        TextField("Search saved mixes", text: $search).autocorrectionDisabled().padding(15).driftPanel()
                        Menu {
                            Picker("Sort by", selection: Binding(get: { store.config.sort }, set: store.setSort)) {
                                ForEach(DriftSort.allCases) { Text($0.title).tag($0) }
                            }
                        } label: { Image(systemName: "arrow.up.arrow.down").frame(width: 44, height: 44) }.accessibilityLabel("Sort saved mixes")
                    }
                    Text("Loading a saved mix leaves it paused. Press play when you’re ready.").font(.footnote).foregroundStyle(DriftTheme.muted)
                    if presets.isEmpty { ContentUnavailableView.search(text: search) }
                    ForEach(presets) { preset in
                        HStack(spacing: 12) {
                            Button { store.load(preset) } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: preset.icon).font(.system(size: 26, weight: .light)).foregroundStyle(DriftTheme.accent).frame(width: 48, height: 56).background(DriftTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(preset.name).font(.system(size: presetTitleSize, design: .serif)).foregroundStyle(DriftTheme.text)
                                        Text("\(preset.selection.count) sounds · \(Int(preset.master * 100))% volume").font(.subheadline).foregroundStyle(DriftTheme.muted)
                                    }
                                    Spacer(minLength: 0)
                                }.frame(maxWidth: .infinity, minHeight: 92, alignment: .leading).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel("Load \(preset.name)")
                            Menu {
                                Button("Edit name & icon", systemImage: "pencil") { editing = preset }
                                Button("Delete mix", systemImage: "trash", role: .destructive) { store.deletePreset(preset.id) }
                            } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel("Options for \(preset.name)")
                        }.padding(18).driftPanel()
                            .accessibilityElement(children: .contain).accessibilityIdentifier("saved-card-\(preset.name)")
                    }
                    Text("\(store.config.presets.count) of 48 saved mixes").font(.footnote).foregroundStyle(DriftTheme.muted)
                }
            }.driftPageLayout()
        }.background(DriftTheme.background).modifier(BrandToolbar())
        .safeAreaInset(edge: .bottom, spacing: 0) { if !store.selection.isEmpty || audio.owner == .studio { MiniPlayer() } }
        .sheet(item: $editing) { PresetEditor(preset: $0) }
    }
}

struct PresetEditor: View {
    var preset: DriftPreset?
    @EnvironmentObject private var store: DriftStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var icon = "headphones"
    var body: some View {
        NavigationStack {
            Form {
                Section("Mix name") { TextField("A name for this moment", text: $name).accessibilityIdentifier("preset-name").onChange(of: name) { _, value in if value.count > 80 { name = String(value.prefix(80)) } } }
                Section("Choose an icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 55))], spacing: 8) {
                        ForEach(DriftStore.presetIcons, id: \.self) { option in
                            Button { icon = option } label: {
                                Image(systemName: option).font(.system(size: 23, weight: .light)).frame(width: 52, height: 52).background(icon == option ? DriftTheme.accent.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 14))
                            }.buttonStyle(.plain).accessibilityLabel(presetIconLabel(option)).accessibilityAddTraits(icon == option ? .isSelected : [])
                        }
                    }
                }
                Section { Text(preset == nil ? "Your sounds, individual volumes and master volume will be saved." : "Changing the name or icon keeps the saved sounds and volumes.").font(.footnote).foregroundStyle(DriftTheme.muted) }
            }.scrollContentBackground(.hidden).background(DriftTheme.background)
                .navigationTitle(preset == nil ? "Save your mix" : "Edit saved mix").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { store.save(name: name, icon: icon, editing: preset?.id); dismiss(); store.tab = 2 }
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("preset-save")
                    }
                }
        }.onAppear { name = preset?.name ?? ""; icon = preset?.icon ?? "headphones" }.presentationDetents([.medium, .large])
    }
    private func presetIconLabel(_ icon: String) -> String {
        ["headphones": "Headphones", "book": "Reading", "moon": "Night", "cloud.rain": "Rain", "wind": "Wind", "flame": "Fire", "cup.and.saucer": "Café", "water.waves": "Waves", "star": "Favorite"][icon] ?? "Headphones"
    }
}

struct SleepTimerView: View {
    @EnvironmentObject private var store: DriftStore
    @Environment(\.dismiss) private var dismiss
    @State private var minutes = 30
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Let your soundscape end softly.").font(.system(size: 22, design: .serif))
                    Text("Playback fades out when the timer ends, even with the screen locked.").font(.footnote).foregroundStyle(DriftTheme.muted)
                }
                Section("Choose a duration") {
                    ForEach([5, 15, 30, 45, 60, 90], id: \.self) { value in
                        Button("\(value) minutes") { store.setSleepTimer(minutes: value); dismiss() }.accessibilityIdentifier("timer-\(value)")
                    }
                    Stepper("Custom: \(minutes) minutes", value: $minutes, in: 1...180)
                    Button("Start custom timer") { store.setSleepTimer(minutes: minutes); dismiss() }
                }
                if store.sleepDeadline != nil { Section { Button("Turn off timer", role: .destructive) { store.setSleepTimer(minutes: nil); dismiss() } } }
            }.scrollContentBackground(.hidden).background(DriftTheme.background)
                .navigationTitle("Sleep timer").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.presentationDetents([.medium, .large])
    }
}
