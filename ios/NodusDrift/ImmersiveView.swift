// SPDX-License-Identifier: MIT
import SwiftUI

struct ImmersiveView: View {
    @EnvironmentObject private var store: DriftStore
    @EnvironmentObject private var audio: DriftAudioEngine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.scenePhase) private var scenePhase
    @State private var awake = false
    @State private var controlsVisible = false
    @State private var gaze = CGPoint.zero
    @State private var wakeTask: Task<Void, Never>?
    @State private var controlsTask: Task<Void, Never>?
    @State private var timerSheet = false
    @State private var landscapeMotion = true

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 500
            ZStack {
                Color.black.ignoresSafeArea()
                // Keep one native surface alive across appearance changes. Returning
                // from Nodi reuses the last frame instead of recreating a Metal view.
                StudioLandscapeView(scene: store.meditationScene, playing: audio.listening,
                                    animateWhenPaused: true,
                                    motionEnabled: landscapeMotion && store.meditationAppearance == .landscape)
                    .ignoresSafeArea()
                    .opacity(store.meditationAppearance == .landscape ? 1 : 0)
                    .transaction { $0.animation = nil; $0.disablesAnimations = true }
                if store.meditationAppearance == .landscape {
                    LinearGradient(colors: [.black.opacity(0.25), .clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                    if !controlsVisible {
                        VStack { HStack { DriftBrand().shadow(color: .black.opacity(0.5), radius: 6); Spacer() }; Spacer() }.padding(24)
                    }
                } else {
                    RadialGradient(colors: [Color(hex: 0x16211C).opacity(0.45), .black], center: .center, startRadius: 0, endRadius: min(proxy.size.width, proxy.size.height) * 0.65).ignoresSafeArea()
                    VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    NodiView(awake: awake, gaze: gaze, immersive: true)
                        .frame(width: min(380, proxy.size.width - 20), height: min(compact ? 200 : 310, proxy.size.height * (compact ? 0.62 : 0.5)))
                    if !compact {
                        Text("Just be here.").font(.system(size: 29, weight: .regular, design: .serif)).foregroundStyle(DriftTheme.text.opacity(0.8)).padding(.top, 28).opacity(controlsVisible ? 1 : 0)
                        Text("Nothing to do. Nowhere to go.").font(.system(size: 12)).foregroundStyle(DriftTheme.muted.opacity(0.7)).padding(.top, 10).opacity(controlsVisible ? 1 : 0)
                    }
                    Spacer(minLength: 0)
                    }.padding(.bottom, compact ? 95 : 80).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Color.clear.contentShape(Rectangle()).onTapGesture { location in
                    gaze = CGPoint(x: tanh((location.x - proxy.size.width / 2) / 180) * 3.5, y: tanh((location.y - proxy.size.height / 2) / 180) * 2.5)
                    wake()
                }
                // Once controls are visible, their own empty space handles wake
                // taps. The full-screen gesture must not compete with the selector.
                .allowsHitTesting(!controlsVisible)
                VStack {
                    HStack {
                        HStack(spacing: 10) {
                            NodusMark().frame(width: 16, height: 18)
                            Text("NODUS DRIFT").font(.system(size: 10, weight: .medium)).tracking(3).foregroundStyle(DriftTheme.muted)
                        }.accessibilityElement(children: .combine).accessibilityLabel("Nodus Drift")
                        Spacer()
                        ImmersiveRotationButton()
                        Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 15)).frame(width: 48, height: 48).background(.white.opacity(0.07), in: Circle()) }
                            .accessibilityLabel("Leave meditation mode").accessibilityIdentifier("leave-meditation")
                    }.padding(.horizontal, 24).padding(.top, 15)
                    MeditationAppearancePicker(identifier: "meditation-appearance-immersive").frame(maxWidth: 360).padding(.horizontal, 24)
                    Spacer().frame(maxWidth: .infinity).contentShape(Rectangle()).onTapGesture { wake() }
                    VStack(spacing: compact ? 6 : 20) {
                        if store.meditationAppearance == .landscape {
                            Text(store.meditationScene.visuals.landscape.title).font(.system(size: 27, design: .serif))
                                .accessibilityIdentifier("meditation-landscape-name")
                            if !compact {
                                Text(store.meditationScene.visuals.compositionSummary).font(.caption).foregroundStyle(DriftTheme.muted)
                                    .lineLimit(2).accessibilityIdentifier("meditation-scene-elements")
                                if !store.meditationScene.offscreenVisualSounds.isEmpty {
                                    Text(store.meditationScene.offscreenVisualSounds).font(.caption).foregroundStyle(DriftTheme.muted)
                                        .lineLimit(2).accessibilityIdentifier("meditation-offscreen-sounds")
                                }
                            }
                            if reduceMotion {
                                Text("Animation paused by Reduce Motion").font(.footnote).foregroundStyle(DriftTheme.muted)
                            } else {
                                Button { landscapeMotion.toggle(); reveal() } label: {
                                    Label(landscapeMotion ? "Pause visuals" : "Animate visuals", systemImage: landscapeMotion ? "pause" : "play")
                                }.font(.footnote).accessibilityIdentifier("meditation-visual-motion")
                            }
                        }
                        if !store.selection.isEmpty {
                            Text(store.summary).font(.system(size: 11)).foregroundStyle(DriftTheme.muted).lineLimit(2).multilineTextAlignment(.center).padding(.horizontal, 25)
                            HStack(spacing: 28) {
                                Button { timerSheet = true; reveal() } label: { Image(systemName: "moon.zzz").font(.system(size: 21, weight: .light)).frame(width: 48, height: 48) }.accessibilityLabel("Sleep timer")
                                Button { store.togglePlayback(); reveal() } label: {
                                    Image(systemName: audio.listening ? "pause.fill" : "play.fill").font(.system(size: 19)).frame(width: 64, height: 64).background(DriftTheme.accent.opacity(0.13), in: Circle()).overlay(Circle().stroke(DriftTheme.accent.opacity(0.22)))
                                }.accessibilityLabel(audio.listening ? "Pause mix" : "Play mix").accessibilityIdentifier("meditation-play")
                                Button { dismiss(); store.tab = 1 } label: { Image(systemName: "slider.horizontal.3").font(.system(size: 21, weight: .light)).frame(width: 48, height: 48) }.accessibilityLabel("Adjust your mix")
                            }.foregroundStyle(DriftTheme.accent)
                            if let remaining = store.remainingSeconds {
                                Text(String(format: "%d:%02d remaining", remaining / 60, remaining % 60)).font(.system(size: 11, design: .monospaced)).foregroundStyle(DriftTheme.muted)
                            }
                        } else {
                            Button { dismiss(); store.tab = 0 } label: { Label("Add a soundscape", systemImage: "waveform").font(.subheadline).padding(18).background(.white.opacity(0.07), in: Capsule()) }.foregroundStyle(DriftTheme.accent)
                        }
                        if store.meditationAppearance == .landscape {
                            Button("Hide controls") {
                                controlsTask?.cancel()
                                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { controlsVisible = false }
                            }.font(.footnote).accessibilityIdentifier("hide-meditation-controls")
                        } else {
                            Text("TAP ANYWHERE TO WAKE NODI").font(.system(size: 8, weight: .medium)).tracking(2).foregroundStyle(DriftTheme.muted.opacity(0.65))
                        }
                    }.padding(.bottom, compact ? 8 : 26)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(controlsVisible ? 1 : 0)
                .allowsHitTesting(controlsVisible)
                .accessibilityHidden(!controlsVisible)
                .zIndex(1)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .accessibilityAction(named: Text("Show meditation controls")) { wake() }
            .accessibilityAction(.escape) { dismiss() }
        }
        .statusBarHidden(true).persistentSystemOverlays(.hidden)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = store.config.keepAwake
            if store.meditationAppearance == .nodi || voiceOver { reveal() }
        }
        .onDisappear { wakeTask?.cancel(); controlsTask?.cancel(); UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: scenePhase) { _, phase in
            UIApplication.shared.isIdleTimerDisabled = phase == .active && store.config.keepAwake
            if phase == .active { store.updateCountdown() }
        }
        .onChange(of: voiceOver) { _, _ in reveal() }
        .onChange(of: store.meditationAppearance) { _, _ in
            // Selection keeps its controls in place; only the inactivity timer hides
            // them. Do not carry a wake gesture or an opacity animation to the new view.
            wakeTask?.cancel(); awake = false; gaze = .zero
            reveal(animated: false)
        }
        .sheet(isPresented: $timerSheet, onDismiss: { reveal() }) { SleepTimerView() }
        .preferredColorScheme(.dark)
    }
    private func reveal(animated: Bool = true) {
        controlsTask?.cancel()
        var transaction = Transaction(animation: animated && !reduceMotion ? .easeInOut(duration: 0.45) : nil)
        transaction.disablesAnimations = !animated
        withTransaction(transaction) { controlsVisible = true }
        guard !voiceOver else { return }
        controlsTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, !timerSheet else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.7)) { controlsVisible = false }
        }
    }
    private func wake() {
        awake = true; store.feedback(); reveal(); wakeTask?.cancel()
        wakeTask = Task {
            try? await Task.sleep(for: .milliseconds(2500))
            guard !Task.isCancelled else { return }
            awake = false; gaze = .zero
        }
    }
}
