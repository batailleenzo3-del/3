//
//  SettingsView.swift
//  Réglages : version illimitée, scan, sécurité (Face ID), signature, personnalisation,
//  aide, à propos.
//

import SwiftUI
import Combine
import StoreKit
import UIKit

struct SettingsView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var store: DocumentStore
    @ObservedObject var purchases: PurchaseManager
    @ObservedObject var lock: AppLock
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview

    @AppStorage(SettingsKey.appearance) private var appearanceRaw = AppearanceOption.system.rawValue
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.ocean.rawValue
    @AppStorage(SettingsKey.glassLevel) private var glassRaw = GlassLevel.balanced.rawValue
    @AppStorage(SettingsKey.haptics) private var hapticsEnabled = true
    @AppStorage(SettingsKey.onboardingDone) private var onboardingDone = true
    @AppStorage(SettingsKey.defaultFilter) private var filterRaw = ScanFilter.auto.rawValue
    @AppStorage(SettingsKey.exportQuality) private var qualityRaw = ExportQuality.medium.rawValue

    @State private var showPaywall = false
    @State private var showFeedback = false
    @State private var showSignaturePad = false
    @State private var lockOn = UserDefaults.standard.bool(forKey: SettingsKey.appLock)

    var body: some View {
        NavigationStack {
            Form {
                proSection

                Section {
                    Picker(selection: $filterRaw) {
                        ForEach(ScanFilter.allCases) { filter in
                            Label(filter.title, systemImage: filter.icon).tag(filter.rawValue)
                        }
                    } label: {
                        Label(loc("settings_default_filter"), systemImage: "camera.filters")
                    }
                    Picker(selection: $qualityRaw) {
                        ForEach(ExportQuality.allCases) { quality in
                            Text(quality.title).tag(quality.rawValue)
                        }
                    } label: {
                        Label(loc("export_quality"), systemImage: "arrow.down.right.and.arrow.up.left")
                    }
                } header: {
                    Text(loc("settings_scan"))
                } footer: {
                    Text(loc("settings_scan_footer"))
                }

                Section {
                    Toggle(isOn: Binding(get: { lockOn }, set: { newValue in
                        Task {
                            if await lock.setEnabled(newValue) { lockOn = newValue }
                        }
                    })) {
                        Label(loc("settings_lock", AppLock.biometryName), systemImage: "faceid")
                    }
                    .disabled(!AppLock.canUseLock)
                    if let signature = store.signature {
                        HStack {
                            Label(loc("settings_signature"), systemImage: "signature")
                            Spacer()
                            Image(uiImage: signature)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 30)
                                .padding(4)
                                .background(RoundedRectangle(cornerRadius: 6).fill(.white))
                        }
                        Button {
                            showSignaturePad = true
                        } label: {
                            Label(loc("sign_new"), systemImage: "pencil.and.scribble")
                        }
                        Button(role: .destructive) {
                            store.saveSignature(nil)
                        } label: {
                            Label(loc("settings_signature_delete"), systemImage: "trash")
                        }
                    }
                } header: {
                    Text(loc("settings_security"))
                } footer: {
                    Text(loc("settings_security_footer"))
                }

                personalizationSection

                Section(loc("settings_appearance")) {
                    Picker(selection: $appearanceRaw) {
                        ForEach(AppearanceOption.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    } label: {
                        Label(loc("settings_theme"), systemImage: "circle.lefthalf.filled")
                    }
                    Toggle(isOn: $hapticsEnabled) {
                        Label(loc("settings_haptics"), systemImage: "hand.tap.fill")
                    }
                }

                Section {
                    LabeledContent {
                        Text("\(store.documents.count)")
                    } label: {
                        Label(loc("settings_documents"), systemImage: "doc.on.doc.fill")
                    }
                } header: {
                    Text(loc("settings_data"))
                } footer: {
                    Text(loc("settings_data_footer"))
                }

                Section(loc("settings_help")) {
                    Button {
                        showFeedback = true
                    } label: {
                        Label(loc("feedback_title"), systemImage: "lightbulb.fill")
                    }
                    Button {
                        onboardingDone = false
                        dismiss()
                    } label: {
                        Label(loc("settings_tutorial"), systemImage: "questionmark.circle")
                    }
                }

                #if DEBUG
                debugSection
                #endif

                Section(loc("settings_about")) {
                    Button {
                        rateApp()
                    } label: {
                        Label(loc("settings_rate"), systemImage: "star.bubble")
                    }
                    if !AppConfig.supportEmail.isEmpty, let url = URL(string: "mailto:\(AppConfig.supportEmail)") {
                        Button {
                            openURL(url)
                        } label: {
                            Label(loc("settings_contact"), systemImage: "envelope")
                        }
                    }
                    if !AppConfig.privacyPolicyURL.isEmpty, let url = URL(string: AppConfig.privacyPolicyURL) {
                        Button {
                            openURL(url)
                        } label: {
                            Label(loc("settings_privacy"), systemImage: "hand.raised.fill")
                        }
                    }
                    HStack {
                        Label(loc("settings_version"), systemImage: "info.circle")
                        Spacer()
                        Text(appVersion).foregroundStyle(.secondary)
                    }
                }

                Section {
                    Text(loc("brand_promise"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .tint(theme.primary)
            .navigationTitle(loc("settings_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("done")) { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(purchases: purchases).appAppearance()
            }
            .sheet(isPresented: $showFeedback) {
                FeedbackView().appAppearance()
            }
            .sheet(isPresented: $showSignaturePad) {
                NavigationStack {
                    SignaturePad { image in
                        store.saveSignature(image)
                        showSignaturePad = false
                    }
                    .background { AppBackground() }
                    .navigationTitle(loc("sign_draw_title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(loc("cancel")) { showSignaturePad = false }
                        }
                    }
                }
                .appAppearance()
            }
        }
    }

    // MARK: Personnalisation

    private var personalizationSection: some View {
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 16) {
                ForEach(AppTheme.allCases) { item in
                    let selected = item.rawValue == themeRaw
                    Button {
                        withAnimation(.snappy) { themeRaw = item.rawValue }
                    } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(item.diagonalGradient)
                                .frame(width: 46, height: 46)
                                .overlay {
                                    if selected {
                                        Image(systemName: "checkmark")
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .padding(4)
                                .overlay(Circle().strokeBorder(item.primary, lineWidth: selected ? 2.5 : 0))
                                .shadow(color: item.primary.opacity(selected ? 0.5 : 0), radius: 8)
                            Text(item.title)
                                .font(.caption2.weight(selected ? .bold : .regular))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(item.title)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 10) {
                Label(loc("settings_transparency"), systemImage: "drop.halffull")
                Picker(loc("settings_transparency"), selection: $glassRaw) {
                    ForEach(GlassLevel.allCases) { level in
                        Text(level.title).tag(level.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(.vertical, 4)
        } header: {
            Text(loc("settings_personalize"))
        } footer: {
            Text(loc("settings_transparency_footer"))
        }
    }

    // MARK: Version illimitée

    private var proSection: some View {
        Section {
            if purchases.isPro {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.yellow)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc("pro_active_title")).font(.headline)
                        Text(loc("pro_active_text")).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.title2)
                            .foregroundStyle(.yellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc("pro_upgrade_title")).font(.headline).foregroundStyle(.primary)
                            Text(loc("free_counter", store.documents.count, AppConfig.freeDocumentLimit))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let price = purchases.priceText {
                            Text(price)
                                .font(.subheadline.weight(.bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(theme.gradient, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Button(loc("restore_purchases")) {
                    Task { await purchases.restore() }
                }
            }
        }
    }

    // MARK: Mode test

    #if DEBUG
    private var debugSection: some View {
        Section {
            LabeledContent("Documents", value: "\(store.documents.count) / \(AppConfig.freeDocumentLimit) gratuits")
            LabeledContent("Version illimitée", value: purchases.isPro ? "Achetée" : "Non")
            LabeledContent("Produit StoreKit", value: purchases.product?.displayPrice ?? "non chargé")
            LabeledContent("Scanner disponible", value: DocumentScanner.isAvailable ? "Oui" : "Non (simulateur)")
            Button("Ajouter 3 documents d'exemple") {
                Task { await store.debugAddSamples() }
            }
            Button("Revenir à la version gratuite") {
                Task { await purchases.debugReset() }
            }
            Button("Tout effacer", role: .destructive) {
                store.debugRemoveAll()
            }
        } header: {
            Text("🧪 Mode test (invisible sur l'App Store)")
        } footer: {
            Text("Les exemples permettent de tester sans appareil photo (simulateur) et de faire les captures. Pour effacer un faux achat : dans Xcode, menu Debug → StoreKit → Manage Transactions.")
        }
    }
    #endif

    // MARK: Actions

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func rateApp() {
        if !AppConfig.appStoreID.isEmpty,
           let url = URL(string: "https://apps.apple.com/app/id\(AppConfig.appStoreID)?action=write-review") {
            openURL(url)
        } else {
            requestReview()
        }
    }
}
