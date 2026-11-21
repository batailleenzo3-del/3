//
//  ContentView.swift
//  Écran racine : tutoriel → bibliothèque, avec verrouillage Face ID et écran masqué
//  dans le sélecteur d'apps.
//

import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var store = DocumentStore()
    @StateObject private var purchases = PurchaseManager()
    @StateObject private var lock = AppLock()
    @AppStorage(SettingsKey.onboardingDone) private var onboardingDone = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var hideContent = false

    var body: some View {
        ZStack {
            AppBackground()

            if !onboardingDone {
                OnboardingView {
                    withAnimation(.snappy) { onboardingDone = true }
                }
                .transition(.opacity)
            } else {
                LibraryView(store: store, purchases: purchases, lock: lock)
            }

            if lock.isLocked && onboardingDone {
                LockScreen(lock: lock)
                    .transition(.opacity)
            } else if hideContent && lock.isEnabled {
                PrivacyCover()
            }
        }
        .appAppearance()
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                lock.lockIfNeeded()
            case .inactive:
                hideContent = true
            case .active:
                hideContent = false
            @unknown default:
                break
            }
        }
    }
}

#Preview {
    ContentView()
}
