// SPDX-License-Identifier: MIT
import SwiftUI
import StableAudioMLX

struct StudioGenerationView: View {
    @ObservedObject var studio: StudioStore
    @ObservedObject private var generator: StudioGenerator
    var replacing: UUID?
    @Environment(\.dismiss) private var dismiss
    @State private var prompt = ""
    @State private var kind = SA3ModelKind.sfx
    @State private var seconds = 30
    @State private var wholeScene = false
    @State private var suggestionsOnly = false
    init(studio: StudioStore, replacing: UUID? = nil) {
        self.studio = studio; self.replacing = replacing; generator = studio.generator
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Give your world a new sound.").font(.system(size: 27, design: .serif))
                    Text("Audio is composed on this device and becomes an editable layer. Use a short, concrete prompt in English.").font(.subheadline).foregroundStyle(DriftTheme.muted)
                    Text("Powered by Stable Audio 3 · Stability AI").font(.caption).foregroundStyle(DriftTheme.muted)
                }
                if replacing == nil && !studio.scene.layers.isEmpty {
                    Section { Toggle("Generate the whole scene's audio", isOn: $wholeScene) }
                }
                if wholeScene {
                    Section("Layers to generate") {
                        if studio.scene.layers.contains(where: { $0.requestedPrompt != nil }) { Toggle("Only suggested new recordings", isOn: $suggestionsOnly) }
                        ForEach(studio.scene.layers.filter { !suggestionsOnly || $0.requestedPrompt != nil }) { layer in
                            VStack(alignment: .leading, spacing: 6) {
                                Label(layer.name, systemImage: layer.icon)
                                if let prompt = layer.requestedPrompt { Text(prompt).font(.footnote).foregroundStyle(DriftTheme.muted) }
                            }
                        }
                        Text("One recording at a time. Existing catalogue layers are replaced after each successful generation. Music remains instrumental.").font(.footnote).foregroundStyle(DriftTheme.muted)
                    }
                } else {
                    Section("Your sound") {
                        Picker("Type", selection: $kind) { Text("Ambient sound / SFX").tag(SA3ModelKind.sfx); Text("Instrumental music").tag(SA3ModelKind.music) }
                        TextField(kind == .music ? "Soft ambient piano, slowly evolving" : "Steady rain on a cabin roof, distant wind", text: $prompt, axis: .vertical)
                            .lineLimit(3...6).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("studio-audio-prompt")
                        Picker("Recording length", selection: $seconds) { ForEach(kind == .music ? [30, 60, 90, 120] : [5, 10, 20, 30, 60], id: \.self) { Text("\($0) seconds").tag($0) } }
                        if kind == .music { Text("Instrumental, without singing. Music plays once and can be continued from its layer controls.").font(.footnote).foregroundStyle(DriftTheme.muted) }
                    }
                }
                Section {
                    if studio.generating {
                        HStack { ProgressView(); Text(generator.stage).font(.subheadline) }
                        Button("Stop generation", role: .destructive) { studio.cancelGeneration() }
                    } else {
                        Button(wholeScene ? "Generate scene audio" : (replacing == nil ? "Generate and add layer" : "Generate replacement"), systemImage: "sparkles") {
                            if wholeScene { studio.generateSceneAudio(onlyRequests: suggestionsOnly) }
                            else { studio.generate(prompt: prompt, kind: kind, seconds: Double(seconds), replacing: replacing) }
                        }.disabled((!wholeScene && prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || !SA3Engine.isSupported)
                            .accessibilityIdentifier("studio-generate-audio")
                    }
                    if !SA3Engine.isSupported { Text("Local audio generation requires a real iPhone or iPad. Scene editing and catalogue playback are available here.").font(.footnote).foregroundStyle(DriftTheme.muted) }
                    NavigationLink("Models & licenses") { StudioModelsView(models: generator.models, generator: generator) }
                }
                Section {
                    Text("Optional models. No prompts or recordings are sent to a server. Generation pauses in the background, Low Power Mode or high temperatures.").font(.footnote).foregroundStyle(DriftTheme.muted)
                    if let measurement = generator.lastMeasurement {
                        DisclosureGroup("Last generation on this device") {
                            LabeledContent("Inference", value: String(format: "%.1f s", measurement.timings.total))
                            LabeledContent("Peak app memory", value: ByteCountFormatter.string(fromByteCount: measurement.peakFootprintBytes, countStyle: .memory))
                            LabeledContent("Temperature", value: measurement.thermalEnd)
                        }.font(.footnote)
                    }
                }
            }.navigationTitle("Create audio").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .onAppear {
                    if let recording = studio.scene.layers.first(where: { $0.id == replacing })?.recording {
                        prompt = recording.prompt; kind = recording.model == "music" ? .music : .sfx
                        seconds = kind == .music ? 60 : 30
                    } else if replacing == nil && studio.scene.layers.contains(where: { $0.requestedPrompt != nil }) {
                        wholeScene = true; suggestionsOnly = true
                    }
                }
                .onChange(of: kind) { _, value in if value == .music && seconds < 30 { seconds = 30 } }
                .alert("Audio generation", isPresented: Binding(get: { studio.notice != nil }, set: { if !$0 { studio.notice = nil } })) { Button("Done") { studio.notice = nil } } message: { Text(studio.notice ?? "") }
        }.tint(DriftTheme.accent)
    }
}

struct StudioDirectionView: View {
    @ObservedObject var studio: StudioStore
    @ObservedObject private var director: StudioDirector
    var didCreate: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var prompt = ""
    @State private var modifying = false
    @State private var work: Task<Void, Never>?
    init(studio: StudioStore, didCreate: @escaping () -> Void) { self.studio = studio; director = studio.director; self.didCreate = didCreate }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Describe a place.\nWe'll find its atmosphere.").font(.system(size: 28, design: .serif))
                    Text("Apple's on-device model directs the layers, movement and scenery. Stable Audio composes requested new sounds when its models are installed; existing sounds keep every scene playable.").font(.subheadline).foregroundStyle(DriftTheme.muted)
                }
                if let reason = director.availability {
                    Section { Label(reason, systemImage: "sparkles"); Text("Use Create manually to choose every sound, position, keyframe and visual element.").font(.footnote).foregroundStyle(DriftTheme.muted) }
                } else {
                    Section {
                        Toggle("Modify the current scene", isOn: $modifying)
                        TextField(modifying ? "Make the rain stronger and move the thunder further away" : "A cabin in a rainy forest at night, a nearby fire and a storm slowly approaching", text: $prompt, axis: .vertical)
                            .lineLimit(4...8).accessibilityIdentifier("studio-scene-prompt")
                        if director.busy { HStack { ProgressView(); Text("Directing your scene locally…") } }
                        Button(modifying ? "Apply instruction" : "Create scene", systemImage: "sparkles") {
                            work = Task {
                                await studio.direct(prompt, modifying: modifying)
                                guard !Task.isCancelled, studio.notice == nil else { return }
                                didCreate(); dismiss()
                            }
                        }.disabled(director.busy || studio.generating || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || prompt.count > 1200)
                    }
                }
                Section { Text("Manual editing is always available. No external AI service is used.").font(.footnote).foregroundStyle(DriftTheme.muted) }
            }.navigationTitle("Create with words").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { work?.cancel(); dismiss() } } }
                .onDisappear { work?.cancel() }
                .alert("Scene direction", isPresented: Binding(get: { studio.notice != nil }, set: { if !$0 { studio.notice = nil } })) { Button("Done") { studio.notice = nil } } message: { Text(studio.notice ?? "") }
        }.tint(DriftTheme.accent)
    }
}

struct StudioModelsView: View {
    @ObservedObject var models: StudioModels
    @ObservedObject var generator: StudioGenerator
    @State private var token = ""
    @State private var legal: LegalDocument?
    var body: some View {
        Form {
            Section {
                Text("Compose on your own device.").font(.system(size: 25, design: .serif))
                Text("Powered by Stability AI").font(.subheadline.weight(.medium))
                Text("Stable Audio 3 Small-SFX and Small-Music · Stability AI. The two models share T5Gemma and SAME-S. About 1.9 GB for the first model and 0.92 GB for the second, including the encoder for continuation.").font(.footnote).foregroundStyle(DriftTheme.muted)
            }
            Section("Hugging Face account") {
                if let account = models.account {
                    Label(account, systemImage: "person.crop.circle")
                    Button("Sign out") { models.signOut() }.disabled(models.busy)
                } else {
                    SecureField("Hugging Face read token", text: $token).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Sign in") { Task { await models.signIn(token: token); token = "" } }.disabled(models.busy || token.isEmpty)
                    Link("Create a read token on Hugging Face", destination: URL(string: "https://huggingface.co/settings/tokens")!)
                    Text("The token is stored in this device's Keychain and used only for Hugging Face downloads. Your prompts stay local.").font(.footnote).foregroundStyle(DriftTheme.muted)
                }
            }
            Section("Model terms") {
                Button("Stability AI Community License") { legal = LegalDocument(title: "Stability AI Community License", file: "STABLE_AUDIO_COMMUNITY.md") }
                Button("Gemma Terms of Use · Google") { legal = LegalDocument(title: "Gemma Terms of Use", file: "GEMMA_TERMS.md") }
                Link("Stability AI Acceptable Use Policy", destination: URL(string: "https://stability.ai/use-policy")!)
                Link("Gemma prohibited uses", destination: URL(string: "https://ai.google.dev/gemma/prohibited_use_policy")!)
                Link("Official model licenses and registration", destination: URL(string: "https://stability.ai/license")!)
                Toggle("I have read and accept the model licenses and use restrictions", isOn: $models.acceptedTerms).font(.subheadline)
                Text("The weights have separate licenses from Drift's MIT source. Commercial use requires Stability registration; the Community License's revenue threshold and other conditions apply. Downloading models does not grant unrestricted use.").font(.footnote).foregroundStyle(DriftTheme.muted)
            }
            Section("Optional downloads") {
                ForEach(SA3ModelKind.allCases, id: \.self) { kind in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(kind == .sfx ? "Stable Audio 3 Small-SFX" : "Stable Audio 3 Small-Music").font(.headline)
                        Text(kind == .sfx ? "Environmental sounds and effects" : "Instrumental music and ambient scores").font(.caption).foregroundStyle(DriftTheme.muted)
                        Link("Model card", destination: URL(string: "https://huggingface.co/stabilityai/stable-audio-3-small-\(kind == .sfx ? "sfx" : "music")")!)
                        if models.installed.contains(kind) {
                            Button("Remove model", role: .destructive) { models.remove(kind) }.disabled(models.busy || generator.busy)
                        } else {
                            Button("Download on this device", systemImage: "arrow.down.circle") { models.install(kind) }
                                .disabled(models.busy || generator.busy || !models.acceptedTerms || models.account == nil || !SA3Engine.isSupported)
                        }
                    }.padding(.vertical, 6)
                }
                if models.busy { ProgressView(value: models.progress); Button("Cancel download") { models.cancel() } }
                if !models.status.isEmpty { Text(models.status).font(.footnote).textSelection(.enabled) }
                LabeledContent("Model storage", value: ByteCountFormatter.string(fromByteCount: models.bytesOnDisk, countStyle: .file))
                Button("Clear temporary downloads") { models.clearDownloads() }.disabled(models.busy)
                Text("Removing the last model also removes shared weights. Generated recordings remain in your scenes. Downloads are excluded from device backups.").font(.footnote).foregroundStyle(DriftTheme.muted)
            }
            Section("Credits & source") {
                Link("Stable Audio 3 · Stability AI", destination: URL(string: "https://github.com/Stability-AI/stable-audio-3")!)
                Link("Pinned optimized weights", destination: URL(string: "https://huggingface.co/stabilityai/stable-audio-3-optimized/tree/\(SA3Manifest.revision)")!)
                Button("Runtime and dependency licenses") { legal = LegalDocument(title: "Inference runtime licenses", file: "STABLE_AUDIO_MLX_MIT.txt", notices: [LegalNotice(title: "MLX Swift · MIT", file: "MLX_MIT.txt"), LegalNotice(title: "Swift Numerics · Apache 2.0", file: "SWIFT_NUMERICS_LICENSE.txt"), LegalNotice(title: "Model NOTICE", file: "NOTICE.txt")]) }
                Text("MLX Swift · Apple / ml-explore. StableAudio3-IOS · kellyvv and contributors. Native inference package adapted in Nodus Reader and reused here under its MIT license.").font(.footnote).foregroundStyle(DriftTheme.muted)
            }
        }.navigationTitle("Models & licenses").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $legal) { LegalDocumentView(document: $0) }
    }
}
