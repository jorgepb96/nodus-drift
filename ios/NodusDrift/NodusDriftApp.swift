// SPDX-License-Identifier: MIT
import SwiftUI

final class DriftAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        window?.traitCollection.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }
}

@main struct NodusDriftApp: App {
    @UIApplicationDelegateAdaptor(DriftAppDelegate.self) private var appDelegate
    @StateObject private var store = DriftSession.shared.store
    @Environment(\.scenePhase) private var scenePhase
    #if DEBUG
    private var landscapePreview: StudioLandscape? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-landscape-preview"), args.indices.contains(index + 1) else { return nil }
        return StudioLandscape(rawValue: args[index + 1])
    }
    private var compositionPreview: StudioScene? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-composition-preview"), args.indices.contains(index + 1) else { return nil }
        let sounds = args[index + 1].split(separator: ",").compactMap { DriftCatalog.sound(String($0)) }
        return MeditationComposition.scene(sounds: sounds, volumes: [:])
    }
    #endif
    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if let scene = compositionPreview {
                    StudioLandscapeQAView(landscape: scene.visuals.landscape, document: scene)
                } else if let preview = landscapePreview {
                    StudioLandscapeQAView(landscape: preview)
                } else {
                    DriftRootView(store: store, studio: DriftSession.shared.studio)
                }
                #else
                DriftRootView(store: store, studio: DriftSession.shared.studio)
                #endif
            }
                .preferredColorScheme(.dark)
                .tint(DriftTheme.accent)
                .onChange(of: scenePhase) { _, phase in
                    store.updateCountdown()
                    UIApplication.shared.isIdleTimerDisabled = phase == .active && store.immersive && store.config.keepAwake
                }
        }
    }
}
