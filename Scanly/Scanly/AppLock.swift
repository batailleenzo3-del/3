//
//  AppLock.swift
//  Verrouillage par Face ID / Touch ID / code de l'iPhone (réglable), et écran masqué
//  dans le sélecteur d'apps pour que personne ne voie tes documents.
//

import SwiftUI
import Combine
import LocalAuthentication

@MainActor
final class AppLock: ObservableObject {
    @Published private(set) var isLocked: Bool
    @Published private(set) var isAuthenticating = false

    init() {
        isLocked = UserDefaults.standard.bool(forKey: SettingsKey.appLock)
    }

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: SettingsKey.appLock) }

    /// Nom de la méthode disponible : "Face ID", "Touch ID" ou "code".
    static var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return L10n.t("lock_passcode")
        }
    }

    static var canUseLock: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// À l'arrière-plan : on verrouille (si l'option est activée).
    func lockIfNeeded() {
        if isEnabled { isLocked = true }
    }

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        let context = LAContext()
        let ok = (try? await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                    localizedReason: L10n.t("lock_reason"))) ?? false
        if ok { isLocked = false }
    }

    /// Activer l'option demande d'abord une authentification.
    func setEnabled(_ enabled: Bool) async -> Bool {
        if enabled {
            let context = LAContext()
            let ok = (try? await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                        localizedReason: L10n.t("lock_reason"))) ?? false
            guard ok else { return false }
        }
        UserDefaults.standard.set(enabled, forKey: SettingsKey.appLock)
        objectWillChange.send()
        return true
    }
}

struct LockScreen: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var lock: AppLock

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 22) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(theme.diagonalGradient)
                    .frame(width: 120, height: 120)
                    .glassBackground(in: Circle())
                Text(loc("lock_title"))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Button {
                    Task { await lock.unlock() }
                } label: {
                    PrimaryButtonLabel(title: loc("lock_unlock", AppLock.biometryName), icon: "faceid")
                }
                .buttonStyle(.plain)
                .frame(maxWidth: 320)
            }
            .padding(32)
        }
        .task { await lock.unlock() }
    }
}

/// Cache le contenu dans le sélecteur d'apps.
struct PrivacyCover: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            AppBackground()
            Image(systemName: "doc.viewfinder.fill")
                .font(.system(size: 56))
                .foregroundStyle(theme.diagonalGradient)
        }
    }
}
