// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI

@main struct NodusDriftApp: App {
    @StateObject private var store = DriftStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            DriftRootView(store: store)
                .preferredColorScheme(.dark)
                .tint(DriftTheme.accent)
                .onChange(of: scenePhase) { _, phase in
                    store.updateCountdown()
                    UIApplication.shared.isIdleTimerDisabled = phase == .active && store.immersive && store.config.keepAwake
                }
        }
    }
}
