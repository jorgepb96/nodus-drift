// SPDX-License-Identifier: MIT
import SwiftUI

/// An explicit rotation remains available when device rotation is locked or unavailable.
struct ImmersiveRotationButton: View {
    @State private var rotationError: String?
    var body: some View {
        Button {
            guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else { return }
            let size: CGSize
            if #available(iOS 26.0, *) { size = scene.effectiveGeometry.coordinateSpace.bounds.size }
            else { size = scene.coordinateSpace.bounds.size }
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: size.width > size.height ? .portrait : .landscapeRight)) {
                rotationError = $0.localizedDescription
            }
        } label: {
            Image(systemName: "rectangle.portrait.rotate").frame(width: 48, height: 48)
        }
        .accessibilityLabel("Rotate immersive view").accessibilityIdentifier("rotate-immersive-view")
        .alert("Rotation unavailable", isPresented: Binding(get: { rotationError != nil }, set: { if !$0 { rotationError = nil } })) {
            Button("OK", role: .cancel) { rotationError = nil }
        } message: { Text(rotationError ?? "") }
    }
}

/// Photographic plates with native, material-aware Metal motion and atmosphere.
struct StudioLandscapeView: View {
    let scene: StudioScene
    var sceneTime: Double = 0
    var playing = false
    var animateWhenPaused = false
    var motionEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var thermal = ProcessInfo.processInfo.thermalState
    @State private var visible = false
    private var animated: Bool {
        visible && (playing || animateWhenPaused) && motionEnabled && !reduceMotion && phase == .active &&
        thermal != .critical && scene.visuals.enabled
    }
    var body: some View {
        Group {
            if scene.visuals.enabled {
                StudioLandscapeSurface(state: StudioVisualState(scene: scene, time: previewTime, reduceMotion: reduceMotion || lowPower || thermal.rawValue >= ProcessInfo.ThermalState.serious.rawValue), animated: animated,
                                       framesPerSecond: thermal == .serious ? 10 : (lowPower ? 15 : 30))
            } else {
                DriftTheme.background
            }
        }
        .clipped()
        .accessibilityHidden(true)
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled }
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in thermal = ProcessInfo.processInfo.thermalState }
    }
    private var previewTime: Double {
        // A paused draft at t=0 must show its elements, rather than their silent fade-in.
        !playing && animateWhenPaused && sceneTime == 0 ? min(scene.duration * 0.1, 4) : sceneTime
    }
}

struct StudioImmersiveView: View {
    @ObservedObject var studio: StudioStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var controls = false
    @State private var motion = true
    var body: some View {
        ZStack {
            StudioLandscapeView(scene: studio.scene, sceneTime: studio.time, playing: studio.playing, animateWhenPaused: true, motionEnabled: motion).ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.3), .clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            Color.clear.contentShape(Rectangle()).onTapGesture { controls = true }
            if !controls && !voiceOver {
                VStack { HStack { DriftBrand().shadow(color: .black.opacity(0.5), radius: 6); Spacer() }; Spacer() }.padding(24)
            }
            if controls || voiceOver {
                VStack {
                    HStack {
                        DriftBrand()
                        Spacer()
                        ImmersiveRotationButton()
                        Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 48, height: 48).background(.black.opacity(0.3), in: Circle()) }.accessibilityLabel("Leave immersive landscape")
                    }
                    Spacer()
                    Text(studio.scene.name).font(.system(size: 30, design: .serif)).multilineTextAlignment(.center)
                    if !studio.scene.offscreenVisualSounds.isEmpty {
                        Text(studio.scene.offscreenVisualSounds).font(.caption).foregroundStyle(DriftTheme.muted).lineLimit(2)
                    }
                    Button { studio.togglePlayback() } label: { Image(systemName: studio.playing ? "pause.fill" : "play.fill").font(.title2).frame(width: 70, height: 70).background(.ultraThinMaterial, in: Circle()) }.accessibilityLabel(studio.playing ? "Pause scene" : "Play scene")
                    Button(motion ? "Pause visuals" : "Animate visuals") { motion.toggle() }.font(.footnote).padding(.top)
                    Button("Hide controls") { controls = false }.font(.footnote).padding(.top)
                }.padding(28)
            }
        }.foregroundStyle(DriftTheme.text)
            .accessibilityAction(.escape) { dismiss() }
            .statusBarHidden(!controls).persistentSystemOverlays(controls ? .automatic : .hidden)
    }
}

#if DEBUG
/// Isolated renderer fixture for visual/motion QA, without starting any audio.
struct StudioLandscapeQAView: View {
    let landscape: StudioLandscape
    var document: StudioScene?
    @State private var moving = true
    @State private var controls = false
    private var scene: StudioScene {
        if let document { return document }
        var value = StudioScene(name: landscape.title, seed: 20261107)
        value.visuals = StudioVisuals(landscape: landscape,
                                     rain: [.cabin, .forest].contains(landscape) ? 0.75 : (landscape == .snow ? 0.6 : 0),
                                     wind: 0.55, daylight: landscape == .night ? 0.07 : 0.42,
                                     fog: 0.4, fire: landscape == .cabin, stars: landscape == .night)
        return value
    }
    var body: some View {
        ZStack {
            StudioLandscapeView(scene: scene, sceneTime: 120, playing: moving).ignoresSafeArea()
            Color.clear.contentShape(Rectangle()).onTapGesture { controls.toggle() }
            VStack {
                HStack {
                    DriftBrand()
                        .shadow(color: .black.opacity(0.5), radius: 6)
                    Spacer()
                }
                Spacer()
                if controls {
                    ImmersiveRotationButton()
                    Button { moving.toggle() } label: { Image(systemName: moving ? "pause.fill" : "play.fill").frame(width: 48, height: 48).shadow(color: .black, radius: 6) }
                        .accessibilityLabel(moving ? "Pause animation" : "Resume animation").accessibilityIdentifier("landscape-motion")
                }
            }.padding(24)
        }.foregroundStyle(.white)
            .statusBarHidden(true).persistentSystemOverlays(.hidden)
    }
}
#endif
