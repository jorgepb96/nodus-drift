// SPDX-License-Identifier: MIT
import SwiftUI
import StableAudioMLX

struct StudioLayerEditor: View {
    @ObservedObject var studio: StudioStore
    let layerID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var generating = false
    @State private var repairStart = 2.0
    @State private var repairEnd = 5.0
    private var layer: StudioLayer? { studio.scene.layers.first { $0.id == layerID } }
    var body: some View {
        NavigationStack {
            if let layer {
                Form {
                    Section("Your layer") {
                        TextField("Name", text: binding(\.name, fallback: layer.name))
                        Slider(value: binding(\.volume, fallback: layer.volume), in: 0...1) { Text("Volume") }
                        Toggle("Muted", isOn: binding(\.muted, fallback: layer.muted))
                        Picker("Connect to visuals", selection: binding(\.role, fallback: layer.role)) {
                            Text("Automatic").tag(Optional<StudioRole>.none)
                            ForEach(StudioRole.allCases) { Text($0.rawValue.capitalized).tag(Optional($0)) }
                        }
                        if !layer.isMusic && layer.catalogID.flatMap(DriftCatalog.sound)?.kind != "binaural" { Toggle("Spatial placement", isOn: binding(\.spatial, fallback: layer.spatial)) }
                    }
                    Section("When it appears") {
                        LabeledContent("Starts", value: "\(Int(layer.start)) s")
                        Slider(value: Binding(get: { self.layer?.start ?? 0 }, set: { value in change { $0.start = min(value, $0.end - 1) } }), in: 0...max(1, studio.scene.duration - 1)).accessibilityLabel("Layer start")
                        LabeledContent("Ends", value: "\(Int(layer.end)) s")
                        Slider(value: Binding(get: { self.layer?.end ?? studio.scene.duration }, set: { value in change { $0.end = max($0.start + 1, value) } }), in: 1...studio.scene.duration).accessibilityLabel("Layer end")
                        LabeledContent("Fade in", value: "\(Int(layer.fadeIn)) s")
                        Slider(value: binding(\.fadeIn, fallback: layer.fadeIn), in: 0...30).accessibilityLabel("Fade in")
                        LabeledContent("Fade out", value: "\(Int(layer.fadeOut)) s")
                        Slider(value: binding(\.fadeOut, fallback: layer.fadeOut), in: 0...30).accessibilityLabel("Fade out")
                    }
                    if !layer.isMusic {
                        Section {
                            Toggle("Natural random events", isOn: binding(\.randomEvents, fallback: layer.randomEvents))
                            if layer.randomEvents {
                                LabeledContent("Space between events", value: "~\(Int(layer.eventGap)) s")
                                Slider(value: binding(\.eventGap, fallback: layer.eventGap), in: 3...120).accessibilityLabel("Event spacing")
                                LabeledContent("Event length", value: "\(Int(layer.eventLength)) s")
                                Slider(value: binding(\.eventLength, fallback: layer.eventLength), in: 1...30).accessibilityLabel("Event length")
                            }
                        } footer: { Text("For thunder, birds and other occasional sounds. Each event has a different wait and starts at a varied point in the recording.") }
                    }
                    Section {
                        Button("Add keyframe at \(Int(studio.time)) s", systemImage: "diamond") {
                            let time = floor(studio.time)
                            change { value in
                                guard value.keyframes.count < 64, !value.keyframes.contains(where: { $0.time == time }) else { return }
                                let evaluated = value.evaluated(at: time, seed: studio.scene.seed)
                                value.keyframes.append(.init(time: time, intensity: 1, position: evaluated.position)); value.keyframes.sort { $0.time < $1.time }
                            }
                        }
                        Button("Make a gradual build", systemImage: "chart.line.uptrend.xyaxis") {
                            change { $0.keyframes = [.init(time: $0.start, intensity: 0.15, position: $0.position), .init(time: $0.end, intensity: 1, position: $0.position)] }
                        }
                        ForEach(layer.keyframes.sorted { $0.time < $1.time }) { key in
                            DisclosureGroup("\(Int(key.time)) s · \(Int(key.intensity * 100))% intensity") {
                                LabeledContent("Time", value: "\(Int(key.time)) s")
                                Slider(value: keyBinding(key.id, \.time, fallback: key.time), in: 0...studio.scene.duration).accessibilityLabel("Keyframe time")
                                Text("Intensity").font(.caption)
                                Slider(value: keyBinding(key.id, \.intensity, fallback: key.intensity), in: 0...1).accessibilityLabel("Keyframe intensity")
                                Text("Left ↔ right").font(.caption)
                                Slider(value: keyBinding(key.id, \.position.x, fallback: key.position.x), in: -20...20).accessibilityLabel("Keyframe left to right")
                                Text("In front ↔ behind").font(.caption)
                                Slider(value: keyBinding(key.id, \.position.z, fallback: key.position.z), in: -20...20).accessibilityLabel("Keyframe front to back")
                                Button("Remove keyframe", role: .destructive) { change { $0.keyframes.removeAll { $0.id == key.id } } }
                            }
                        }
                        if !layer.keyframes.isEmpty { Button("Clear automation", role: .destructive) { change { $0.keyframes = [] } } }
                    } header: { Text("Intensity & movement") } footer: { Text("Keyframes blend smoothly. Spatial positions are in metres, with the listener at the centre.") }
                    if let recording = layer.recording {
                        Section("Generated recording") {
                            Text(recording.prompt).font(.footnote).foregroundStyle(DriftTheme.muted)
                            LabeledContent("Length", value: "\(Int(recording.seconds)) s")
                            Button("Regenerate or modify the sound", systemImage: "arrow.clockwise") { generating = true }
                            if recording.seconds < 118 {
                                Button("Continue another 30 seconds", systemImage: "arrow.right") {
                                    studio.generate(prompt: recording.prompt, kind: recording.model == "music" ? .music : .sfx,
                                                    seconds: min(120, recording.seconds + 30), replacing: layerID, continuing: true); dismiss()
                                }.disabled(studio.generating)
                            }
                            DisclosureGroup("Repair a fragment") {
                                Stepper("From \(Int(repairStart)) s", value: $repairStart, in: 0...max(0, recording.seconds - 1), step: 1)
                                Stepper("To \(Int(repairEnd)) s", value: $repairEnd, in: 1...recording.seconds, step: 1)
                                Button("Regenerate this fragment") {
                                    studio.generate(prompt: recording.prompt, kind: recording.model == "music" ? .music : .sfx, seconds: recording.seconds, replacing: layerID, repair: repairStart...repairEnd); dismiss()
                                }.disabled(studio.generating || repairEnd <= repairStart || repairEnd > recording.seconds)
                            }
                        }
                    }
                    Section { Button("Remove layer", role: .destructive) { studio.removeLayer(layerID); dismiss() } }
                }.navigationTitle(layer.name).navigationBarTitleDisplayMode(.inline)
                    .sheet(isPresented: $generating) { StudioGenerationView(studio: studio, replacing: layerID) }
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            } else {
                ContentUnavailableView("Layer updated", systemImage: "waveform", description: Text("Your new recording is in the scene."))
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            }
        }.tint(DriftTheme.accent)
    }
    private func change(_ body: (inout StudioLayer) -> Void) {
        guard let index = studio.scene.layers.firstIndex(where: { $0.id == layerID }) else { return }
        body(&studio.scene.layers[index]); studio.changed()
    }
    private func binding<T>(_ key: WritableKeyPath<StudioLayer, T>, fallback: T) -> Binding<T> {
        Binding(get: { layer?[keyPath: key] ?? fallback }, set: { value in change { $0[keyPath: key] = value } })
    }
    private func keyBinding<T>(_ id: UUID, _ key: WritableKeyPath<StudioKeyframe, T>, fallback: T) -> Binding<T> {
        Binding(get: { layer?.keyframes.first { $0.id == id }?[keyPath: key] ?? fallback }, set: { value in
            change { layer in
                guard let index = layer.keyframes.firstIndex(where: { $0.id == id }) else { return }
                if key == \StudioKeyframe.time, let time = value as? Double, layer.keyframes.contains(where: { $0.id != id && abs($0.time - time) < 0.1 }) { return }
                layer.keyframes[index][keyPath: key] = value
            }
        })
    }
}

struct StudioSpatialEditor: View {
    @ObservedObject var studio: StudioStore
    @State private var selected: UUID?
    @State private var radius = 12.0
    private var selectedLayer: StudioLayer? { studio.scene.layers.first { $0.id == selected } }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Give every sound a place").font(.system(size: 24, design: .serif))
            Text("Drag a sound around you. Its whole movement path follows. Use headphones to feel direction and distance.").font(.subheadline).foregroundStyle(DriftTheme.muted)
            GeometryReader { proxy in
                let side = proxy.size.width
                ZStack {
                    ForEach(1..<4, id: \.self) { index in Circle().stroke(DriftTheme.accent.opacity(0.12), lineWidth: 1).frame(width: side * Double(index) / 3, height: side * Double(index) / 3) }
                    Rectangle().fill(DriftTheme.line).frame(width: 1)
                    Rectangle().fill(DriftTheme.line).frame(height: 1)
                    VStack { Text("IN FRONT").font(.system(size: 8)).tracking(2); Spacer(); Text("BEHIND").font(.system(size: 8)).tracking(2) }.foregroundStyle(DriftTheme.muted).padding(8)
                    Image(systemName: "headphones").font(.title2).foregroundStyle(DriftTheme.text).accessibilityLabel("You are at the centre")
                    ForEach(studio.scene.layers.filter { $0.spatial && !$0.isMusic }) { layer in
                        let point = layer.evaluated(at: studio.time, seed: studio.scene.seed).position
                        VStack(spacing: 3) {
                            Image(systemName: layer.icon).font(.system(size: 19)).frame(width: 42, height: 42).background(selected == layer.id ? DriftTheme.accent : DriftTheme.panel, in: Circle()).foregroundStyle(selected == layer.id ? DriftTheme.background : DriftTheme.accent)
                            Text(layer.name).font(.system(size: 9)).lineLimit(1).frame(width: 80)
                        }.position(x: max(28, min(side - 28, side / 2 + Double(point.x) / (radius * 2) * side)), y: max(28, min(side - 28, side / 2 + Double(point.z) / (radius * 2) * side)))
                            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("studio-space")).onChanged { value in
                                selected = layer.id
                                move(layer, to: .init(x: Float(max(-20, min(20, (value.location.x / side - 0.5) * radius * 2))), z: Float(max(-20, min(20, (value.location.y / side - 0.5) * radius * 2)))))
                            })
                            .accessibilityElement(children: .ignore).accessibilityLabel("Position of \(layer.name)")
                            .accessibilityAddTraits(.isButton).accessibilityAction { selected = layer.id }
                    }
                }.coordinateSpace(name: "studio-space")
            }.aspectRatio(1, contentMode: .fit).padding(10).driftPanel()
            Picker("Map range", selection: $radius) { Text("Nearby · 12 m").tag(12.0); Text("Wide · 24 m").tag(24.0) }.pickerStyle(.segmented)
            Picker("Select a source", selection: $selected) {
                Text("Choose a sound").tag(Optional<UUID>.none)
                ForEach(studio.scene.layers) { Text($0.name).tag(Optional($0.id)) }
            }.pickerStyle(.menu)
            if let layer = selectedLayer {
                if layer.isMusic || layer.catalogID.flatMap(DriftCatalog.sound)?.kind == "binaural" {
                    Text("This layer keeps its original stereo image.").font(.footnote).foregroundStyle(DriftTheme.muted)
                } else {
                    Toggle("Spatial placement", isOn: Binding(get: { selectedLayer?.spatial ?? false }, set: { value in update(layer.id) { $0.spatial = value } }))
                    Text("Left ↔ right").font(.caption)
                    Slider(value: Binding(get: { selectedLayer?.evaluated(at: studio.time, seed: studio.scene.seed).position.x ?? 0 }, set: { value in
                        let p = layer.evaluated(at: studio.time, seed: studio.scene.seed).position; move(layer, to: .init(x: value, z: p.z))
                    }), in: -20...20).accessibilityLabel("Source left to right")
                    Text("In front ↔ behind").font(.caption)
                    Slider(value: Binding(get: { selectedLayer?.evaluated(at: studio.time, seed: studio.scene.seed).position.z ?? -3 }, set: { value in
                        let p = layer.evaluated(at: studio.time, seed: studio.scene.seed).position; move(layer, to: .init(x: p.x, z: value))
                    }), in: -20...20).accessibilityLabel("Source front to back")
                }
            }
            Text(studio.audio.spatialRouteDescription).font(.footnote).foregroundStyle(DriftTheme.muted)
        }
    }
    private func update(_ id: UUID, _ body: (inout StudioLayer) -> Void) {
        guard let index = studio.scene.layers.firstIndex(where: { $0.id == id }) else { return }
        body(&studio.scene.layers[index]); studio.changed()
    }
    private func move(_ layer: StudioLayer, to point: StudioPosition) {
        // Read current state for every drag callback, avoiding accumulated deltas from a stale view.
        guard let current = studio.scene.layers.first(where: { $0.id == layer.id }) else { return }
        let old = current.evaluated(at: studio.time, seed: studio.scene.seed).position
        let dx = point.x - old.x, dz = point.z - old.z
        update(layer.id) {
            $0.position = .init(x: max(-20, min(20, $0.position.x + dx)), z: max(-20, min(20, $0.position.z + dz)))
            for index in $0.keyframes.indices {
                $0.keyframes[index].position.x = max(-20, min(20, $0.keyframes[index].position.x + dx))
                $0.keyframes[index].position.z = max(-20, min(20, $0.keyframes[index].position.z + dz))
            }
        }
    }
}
