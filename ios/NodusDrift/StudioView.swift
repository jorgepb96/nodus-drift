// SPDX-License-Identifier: MIT
import SwiftUI
import UniformTypeIdentifiers
import StableAudioMLX

struct StudioView: View {
    @ObservedObject var studio: StudioStore
    @State private var editing = false
    @State private var section = "Layers"
    @State private var catalog = false
    @State private var generate = false
    @State private var direct = false
    @State private var importing = false
    @State private var exporting = false
    @State private var archive: StudioArchive?
    @State private var sharing: URL?
    @State private var selectedLayer: StudioLayer?
    private let sections = ["Layers", "Timeline", "Space", "Visuals"]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if editing { editor } else { library }
            }.padding(24).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .background(DriftTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { DriftBrand() }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Save scene", systemImage: "bookmark") { studio.save() }
                    Button("Duplicate scene", systemImage: "plus.square.on.square") { studio.duplicate(studio.scene); editing = true }
                    Button("Export scene", systemImage: "square.and.arrow.up") { prepareArchive(share: false) }
                    Button("Share scene", systemImage: "person.2") { prepareArchive(share: true) }
                    Button("Import scene", systemImage: "square.and.arrow.down") { importing = true }
                } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }.accessibilityLabel("Scene actions")
            }
        }
        .toolbarBackground(DriftTheme.background, for: .navigationBar, .tabBar)
        .toolbarBackground(.visible, for: .navigationBar, .tabBar)
        .sheet(isPresented: $catalog) { StudioCatalogPicker(studio: studio) }
        .sheet(isPresented: $generate) { StudioGenerationView(studio: studio) }
        .sheet(isPresented: $direct) { StudioDirectionView(studio: studio) { editing = true } }
        .sheet(item: $selectedLayer) { StudioLayerEditor(studio: studio, layerID: $0.id) }
        .sheet(isPresented: Binding(get: { sharing != nil }, set: { if !$0 { sharing = nil } })) {
            if let sharing { StudioShareSheet(url: sharing) }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.driftScene, .json]) { result in
            do { try studio.importScene(from: result.get()); editing = true } catch { studio.notice = error.localizedDescription }
        }
        .fileExporter(isPresented: $exporting, document: archive, contentType: .driftScene, defaultFilename: "Nodus Drift scene") { result in
            if case .failure(let error) = result { studio.notice = error.localizedDescription }
        }
        .alert("Soundscape Studio", isPresented: Binding(get: { studio.notice != nil }, set: { if !$0 { studio.notice = nil } })) {
            Button("Done", role: .cancel) { studio.notice = nil }
        } message: { Text(studio.notice ?? "") }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SOUNDSCAPE STUDIO").font(.system(size: 10, weight: .semibold)).tracking(2.5).foregroundStyle(DriftTheme.accent)
            Text(editing ? "Shape your quiet." : "A world of your own.").font(.system(size: 35, design: .serif)).tracking(-0.7)
            Text(editing ? "Let sounds move, grow and find their place." : "Listen to a landscape, or bring one to life.").font(.subheadline).foregroundStyle(DriftTheme.muted)
            if editing { Button("Back to landscapes", systemImage: "arrow.left") { editing = false }.font(.subheadline).padding(.top, 4) }
        }
    }
    private var library: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                Button { studio.create(); editing = true } label: { Label("Create manually", systemImage: "plus").font(.subheadline.weight(.medium)).lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth: .infinity, minHeight: 44) }
                    .buttonStyle(.borderedProminent).foregroundStyle(DriftTheme.background).accessibilityIdentifier("studio-create-manual")
                Button { direct = true } label: { Label("Create with AI", systemImage: "sparkles").font(.subheadline.weight(.medium)).lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth: .infinity, minHeight: 44) }
                    .buttonStyle(.bordered).accessibilityIdentifier("studio-create-ai")
            }
            if !studio.scene.layers.isEmpty {
                player
                Button("Continue editing", systemImage: "slider.horizontal.3") { editing = true }.accessibilityIdentifier("studio-continue")
            }
            Text("Places to begin").font(.system(size: 25, design: .serif))
            ForEach(StudioScene.starters) { scene in sceneRow(scene, saved: false) }
            if !studio.saved.isEmpty {
                Text("Your landscapes").font(.system(size: 25, design: .serif)).padding(.top, 4)
                ForEach(studio.saved) { scene in sceneRow(scene, saved: true) }
            }
            Button("Import a shared scene", systemImage: "square.and.arrow.down") { importing = true }
            Text("Everything is editable. Your scenes, prompts and recordings stay on this device.").font(.footnote).foregroundStyle(DriftTheme.muted)
        }
    }
    private func sceneRow(_ scene: StudioScene, saved: Bool) -> some View {
        HStack(spacing: 14) {
            Button { studio.load(scene); studio.play() } label: {
                Image(systemName: "play.fill").frame(width: 48, height: 48).background(DriftTheme.accent.opacity(0.12), in: Circle())
            }.accessibilityLabel("Listen to \(scene.name)")
            VStack(alignment: .leading, spacing: 5) {
                Text(scene.name).font(.system(size: 18, design: .serif))
                Text("\(scene.layers.count) layers · \(Int(scene.duration / 60)) min · \(scene.visuals.landscape.title)").font(.caption).foregroundStyle(DriftTheme.muted)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Menu {
                Button("Edit scene", systemImage: "pencil") { studio.load(scene); editing = true }
                Button("Duplicate", systemImage: "plus.square.on.square") { studio.duplicate(scene); editing = true }
                if saved { Button("Delete scene", systemImage: "trash", role: .destructive) { studio.delete(scene) } }
            } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel("Actions for \(scene.name)")
        }.padding(16).driftPanel()
    }
    private var player: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                StudioLandscapeView(scene: studio.scene, sceneTime: studio.time, playing: studio.playing, animateWhenPaused: true).frame(height: 220)
                LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 8) {
                    Text(studio.scene.name).font(.system(size: 27, design: .serif))
                    Text(studio.playing ? "Your landscape is unfolding" : "Ready when you are").font(.caption).foregroundStyle(DriftTheme.accent)
                }.padding(22)
            }.frame(height: 220).clipped()
            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    Button { studio.togglePlayback() } label: { Image(systemName: studio.playing ? "pause.fill" : "play.fill").frame(width: 48, height: 48).background(DriftTheme.accent.opacity(0.12), in: Circle()) }
                        .accessibilityLabel(studio.playing ? "Pause scene" : "Play scene").accessibilityIdentifier("studio-play")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(studio.time) / 60):\(String(format: "%02d", Int(studio.time) % 60)) / \(Int(studio.scene.duration) / 60):\(String(format: "%02d", Int(studio.scene.duration) % 60))").font(.caption.monospacedDigit())
                        Text("\(studio.scene.layers.count) layers · on this device").font(.caption2).foregroundStyle(DriftTheme.muted)
                    }
                    Spacer()
                    Button { studio.immersive = true } label: { Image(systemName: "arrow.up.left.and.arrow.down.right").frame(width: 48, height: 48) }.accessibilityLabel("Enter immersive landscape")
                }
                Slider(value: Binding(get: { studio.time }, set: { studio.seek($0) }), in: 0...studio.scene.duration).accessibilityLabel("Scene playhead")
            }.padding(16)
        }.driftPanel().clipShape(RoundedRectangle(cornerRadius: 22))
    }
    private var editor: some View {
        VStack(alignment: .leading, spacing: 22) {
            TextField("Scene name", text: sceneBinding(\.name)).font(.title3).accessibilityIdentifier("studio-scene-name")
            player
            HStack {
                Button("Save", systemImage: "bookmark") { studio.save() }.buttonStyle(.borderedProminent).foregroundStyle(DriftTheme.background).accessibilityIdentifier("studio-save")
                Spacer()
                Button("Direct", systemImage: "sparkles") { direct = true }.buttonStyle(.bordered)
                Button("Generate", systemImage: "waveform.badge.plus") { generate = true }.buttonStyle(.bordered)
            }
            if studio.generating { Label(studio.generator.stage, systemImage: "sparkles").font(.footnote).foregroundStyle(DriftTheme.accent) }
            if studio.scene.layers.contains(where: { $0.requestedPrompt != nil }) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("New recordings for this scene", systemImage: "sparkles").font(.subheadline)
                    Text("The director suggested new audio. Catalogue sounds keep the scene playable until the recordings are ready. Download the matching models in Models & licenses, then choose Generate.").font(.footnote).foregroundStyle(DriftTheme.muted)
                    Button("Review suggested audio") { generate = true }
                }.padding(18).driftPanel()
            }
            Picker("Editor", selection: $section) { ForEach(sections, id: \.self) { Text($0) } }.pickerStyle(.segmented)
            switch section {
            case "Timeline": timeline
            case "Space": StudioSpatialEditor(studio: studio)
            case "Visuals": visuals
            default: layers
            }
        }
    }
    private var layers: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("The sounds in your world").font(.system(size: 22, design: .serif)); Spacer(); Text("\(studio.scene.layers.count)/12").font(.caption).foregroundStyle(DriftTheme.muted) }
            if studio.scene.layers.isEmpty { Text("Start with rain, a river, a fire — whatever feels like home.").font(.subheadline).foregroundStyle(DriftTheme.muted).padding(.vertical) }
            ForEach(studio.scene.layers) { layer in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: layer.icon).foregroundStyle(DriftTheme.accent).frame(width: 24)
                        Text(layer.name).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                        Button { updateLayer(layer.id) { $0.muted.toggle() } } label: { Image(systemName: layer.muted ? "speaker.slash" : "speaker.wave.2").frame(width: 40, height: 40) }.accessibilityLabel(layer.muted ? "Unmute \(layer.name)" : "Mute \(layer.name)")
                        Button { selectedLayer = layer } label: { Image(systemName: "slider.horizontal.3").frame(width: 40, height: 40) }.accessibilityLabel("Edit \(layer.name)")
                    }
                    Slider(value: Binding(get: { studio.scene.layers.first { $0.id == layer.id }?.volume ?? 0 }, set: { value in updateLayer(layer.id) { $0.volume = value } }), in: 0...1).accessibilityLabel("\(layer.name) volume")
                    if layer.randomEvents || !layer.keyframes.isEmpty || layer.recording != nil || layer.requestedPrompt != nil {
                        Text([layer.randomEvents ? "Natural random events" : nil, !layer.keyframes.isEmpty ? "Evolving over time" : nil, layer.recording != nil ? "Generated locally" : nil, layer.requestedPrompt != nil ? "New recording suggested" : nil].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption2).foregroundStyle(DriftTheme.muted)
                    }
                }.padding(18).driftPanel()
            }
            Button { catalog = true } label: { Label("Add a sound", systemImage: "plus").frame(maxWidth: .infinity).padding(14) }.buttonStyle(.bordered).disabled(studio.scene.layers.count >= 12).accessibilityIdentifier("studio-add-sound")
            VStack(alignment: .leading) {
                Text("Overall volume").font(.subheadline)
                Slider(value: sceneBinding(\.master), in: 0...1).accessibilityLabel("Scene master volume")
            }.padding(.top, 8)
        }
    }
    private var timeline: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Let your scene unfold").font(.system(size: 24, design: .serif))
            Text("Tap a layer to shape its intensity and journey. Events and fades follow the playhead.").font(.subheadline).foregroundStyle(DriftTheme.muted)
            Picker("Scene length", selection: Binding(get: { Int(studio.scene.duration) }, set: { studio.setDuration(Double($0)) })) {
                ForEach(Array(Set([60, 180, 300, 600, 1200, 1800, 3600, Int(studio.scene.duration)])).sorted(), id: \.self) { value in Text("\(value / 60) min \(value % 60 == 0 ? "" : "\(value % 60) s")").tag(value) }
            }.pickerStyle(.menu)
            Toggle("Repeat scene", isOn: sceneBinding(\.repeats))
            ForEach(studio.scene.layers) { layer in
                Button { selectedLayer = layer } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(layer.name, systemImage: layer.icon).font(.caption)
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.04))
                                RoundedRectangle(cornerRadius: 8).fill(DriftTheme.accent.opacity(0.18)).frame(width: max(4, proxy.size.width * (layer.end - layer.start) / studio.scene.duration)).offset(x: proxy.size.width * layer.start / studio.scene.duration)
                                Path { p in
                                    for step in 0...80 {
                                        let time = Double(step) / 80 * studio.scene.duration
                                        let state = layer.evaluated(at: time, seed: studio.scene.seed &+ UInt64((studio.scene.layers.firstIndex(where: { $0.id == layer.id }) ?? 0) * 7919))
                                        let point = CGPoint(x: Double(step) / 80 * proxy.size.width, y: 36 - Double(state.gain) * 30)
                                        if step == 0 { p.move(to: point) } else { p.addLine(to: point) }
                                    }
                                }.stroke(DriftTheme.accent, lineWidth: 1.5)
                                ForEach(layer.keyframes) { key in Circle().fill(DriftTheme.accent).frame(width: 6, height: 6).offset(x: proxy.size.width * key.time / studio.scene.duration - 3, y: 0) }
                                Rectangle().fill(.white.opacity(0.7)).frame(width: 1).offset(x: proxy.size.width * studio.time / studio.scene.duration)
                            }
                        }.frame(height: 42)
                    }.padding(14).driftPanel()
                }.buttonStyle(.plain).accessibilityLabel("Edit automation for \(layer.name)")
            }
            Text("Music recordings play once. Use Continue in a generated layer to develop the piece up to 120 seconds.").font(.footnote).foregroundStyle(DriftTheme.muted)
        }
    }
    private var visuals: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("A place to disappear into").font(.system(size: 24, design: .serif))
            Toggle("Visual landscape", isOn: visualBinding(\.enabled))
            if studio.scene.visuals.enabled {
                Picker("Landscape", selection: visualBinding(\.landscape)) { ForEach(StudioLandscape.allCases) { value in Label(value.title, systemImage: value.icon).tag(value) } }.pickerStyle(.menu)
                visualSlider("Rain", key: \.rain); visualSlider("Wind", key: \.wind)
                visualSlider("Daylight", key: \.daylight); visualSlider("Mist", key: \.fog); visualSlider("Sky tint", key: \.tint)
                if studio.scene.visuals.landscape == .cabin {
                    Toggle("Fire in the fireplace", isOn: visualBinding(\.fire))
                }
                Toggle("Stars", isOn: visualBinding(\.stars)); Toggle("Gradual sunrise", isOn: visualBinding(\.dawn))
                Text("A photographic landscape with animated weather, light and atmosphere. Visible fire stays in the cabin fireplace.").font(.footnote).foregroundStyle(DriftTheme.muted)
                Text("Rain follows its audio layer. Lightning follows random thunder. Reduce Motion pauses animation; Low Power Mode lowers its frame rate.").font(.footnote).foregroundStyle(DriftTheme.muted)
            }
        }
    }
    private func visualSlider(_ name: String, key: WritableKeyPath<StudioVisuals, Double>) -> some View {
        VStack(alignment: .leading, spacing: 5) { Text(name).font(.subheadline); Slider(value: visualBinding(key), in: 0...1).accessibilityLabel(name) }
    }
    private func sceneBinding<T>(_ key: WritableKeyPath<StudioScene, T>) -> Binding<T> {
        Binding(get: { studio.scene[keyPath: key] }, set: { studio.scene[keyPath: key] = $0; studio.changed() })
    }
    private func visualBinding<T>(_ key: WritableKeyPath<StudioVisuals, T>) -> Binding<T> {
        Binding(get: { studio.scene.visuals[keyPath: key] }, set: { studio.scene.visuals[keyPath: key] = $0; studio.changed() })
    }
    private func updateLayer(_ id: UUID, _ change: (inout StudioLayer) -> Void) {
        guard let index = studio.scene.layers.firstIndex(where: { $0.id == id }) else { return }; change(&studio.scene.layers[index]); studio.changed()
    }
    private func prepareArchive(share: Bool) {
        do {
            let document = try studio.archive(); archive = document
            if share {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("Nodus-\(studio.scene.id.uuidString).driftscene")
                try JSONEncoder().encode(document).write(to: url, options: .atomic); sharing = url
            } else { exporting = true }
        } catch { studio.notice = error.localizedDescription }
    }
}

private struct StudioShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct StudioCatalogPicker: View {
    @ObservedObject var studio: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    var body: some View {
        NavigationStack {
            List(DriftCatalog.sounds.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { sound in
                Button { studio.add(sound); dismiss() } label: { Label(sound.name, systemImage: sound.icon) }
            }.searchable(text: $search, prompt: "Find a sound").navigationTitle("Add to your world")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }.tint(DriftTheme.accent)
    }
}
