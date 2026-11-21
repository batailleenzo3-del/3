//
//  ExportSheet.swift
//  Partager un document : PDF (avec ou sans mot de passe), images JPEG ou texte,
//  en choisissant la taille du fichier. Et la feuille « Texte reconnu ».
//

import SwiftUI
import Combine
import UIKit

struct ExportSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: DocumentStore
    let docID: UUID

    @AppStorage(SettingsKey.exportQuality) private var qualityRaw = ExportQuality.medium.rawValue
    @State private var format: ExportFormat = .pdf
    @State private var usePassword = false
    @State private var password = ""
    @State private var working = false
    @State private var shareItem: ShareItem?
    @State private var failed = false

    private var quality: ExportQuality { ExportQuality(rawValue: qualityRaw) ?? .medium }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(loc("export_format"), selection: $format) {
                        ForEach(ExportFormat.allCases) { item in
                            Label(item.title, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text(loc("export_format"))
                }

                if format != .text {
                    Section {
                        Picker(loc("export_quality"), selection: $qualityRaw) {
                            ForEach(ExportQuality.allCases) { item in
                                VStack(alignment: .leading) {
                                    Text(item.title)
                                    Text(item.caption).font(.caption).foregroundStyle(.secondary)
                                }
                                .tag(item.rawValue)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    } header: {
                        Text(loc("export_quality"))
                    }
                }

                if format == .pdf {
                    Section {
                        Toggle(isOn: $usePassword.animation()) {
                            Label(loc("export_password"), systemImage: "lock.fill")
                        }
                        if usePassword {
                            SecureField(loc("export_password_placeholder"), text: $password)
                                .textContentType(.newPassword)
                        }
                    } footer: {
                        Text(usePassword ? loc("export_password_footer") : loc("export_pdf_footer"))
                    }
                }

                Section {
                    Button {
                        Task { await export() }
                    } label: {
                        PrimaryButtonLabel(title: loc("share"), icon: "square.and.arrow.up", isLoading: working)
                    }
                    .buttonStyle(.plain)
                    .disabled(working || (format == .pdf && usePassword && password.trimmingCharacters(in: .whitespaces).isEmpty))
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .tint(theme.primary)
            .navigationTitle(loc("share"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("close")) { dismiss() }
                }
            }
            .sheet(item: $shareItem) { item in
                ActivityView(items: item.urls) { completed in
                    if completed {
                        Haptics.success()
                        dismiss()
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .alert(loc("export_failed"), isPresented: $failed) {
                Button(loc("ok"), role: .cancel) {}
            }
        }
    }

    private func export() async {
        guard let doc = store.document(docID) else { return }
        working = true
        let pages = store.exportPages(docID)
        let name = doc.name
        let text = doc.fullText
        let chosenQuality = self.quality
        let chosenFormat = self.format
        let chosenPassword: String? = usePassword ? self.password : nil
        let urls = await Task.detached(priority: .userInitiated) { () -> [URL] in
            switch chosenFormat {
            case .pdf:
                return PDFExporter.makePDF(name: name, pages: pages, quality: chosenQuality, password: chosenPassword).map { [$0] } ?? []
            case .images:
                return PDFExporter.makeImages(name: name, pages: pages, quality: chosenQuality)
            case .text:
                return PDFExporter.makeText(name: name, text: text).map { [$0] } ?? []
            }
        }.value
        working = false
        if urls.isEmpty {
            failed = true
        } else {
            shareItem = ShareItem(urls: urls)
        }
    }
}

// MARK: - Texte reconnu

struct TextSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: DocumentStore
    let docID: UUID

    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let doc = store.document(docID) {
                        if !doc.isTextReady {
                            Label(loc("ocr_running"), systemImage: "text.viewfinder")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if doc.fullText.isEmpty && doc.isTextReady {
                            ContentUnavailableView(loc("text_empty_title"), systemImage: "text.magnifyingglass",
                                                   description: Text(loc("text_empty_text")))
                        }
                        ForEach(Array(doc.pages.enumerated()), id: \.element.id) { index, page in
                            if !page.text.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(loc("page_n", index + 1))
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                    Text(page.text)
                                        .font(.body)
                                        .textSelection(.enabled)
                                }
                                .glassCard(cornerRadius: 20, padding: 16)
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background { AppBackground() }
            .navigationTitle(loc("text_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("close")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        UIPasteboard.general.string = store.document(docID)?.fullText ?? ""
                        Haptics.success()
                        withAnimation { copied = true }
                    } label: {
                        Label(copied ? loc("copied") : loc("copy_all"), systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .disabled(store.document(docID)?.fullText.isEmpty ?? true)
                }
            }
        }
    }
}
