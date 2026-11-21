//
//  LibraryView.swift
//  Écran principal : la bibliothèque des documents, la recherche (dans le texte des
//  scans aussi), le bouton Scanner, l'import (Photos, Fichiers), la sélection (fusionner,
//  partager, supprimer).
//

import SwiftUI
import Combine
import PhotosUI
import UniformTypeIdentifiers
import StoreKit

struct LibraryView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.requestReview) private var requestReview
    @ObservedObject var store: DocumentStore
    @ObservedObject var purchases: PurchaseManager
    @ObservedObject var lock: AppLock

    @AppStorage(SettingsKey.librarySort) private var sortRaw = LibrarySort.recent.rawValue
    @AppStorage(SettingsKey.reviewRequested) private var reviewRequested = false

    @State private var path: [UUID] = []
    @State private var search = ""
    @State private var favoritesOnly = false
    @State private var showScanner = false
    @State private var showPhotos = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showFiles = false
    @State private var showPaywall = false
    @State private var showSettings = false
    @State private var showFeedback = false
    @State private var working = false
    @State private var selecting = false
    @State private var selection: [UUID] = []
    @State private var confirmDelete = false
    @State private var shareItem: ShareItem?
    @State private var noCameraAlert = false
    @State private var renaming: ScanDocument?
    @State private var renameText = ""

    private var sort: LibrarySort { LibrarySort(rawValue: sortRaw) ?? .recent }

    private var visible: [ScanDocument] {
        var list = store.search(search)
        if favoritesOnly { list = list.filter(\.isFavorite) }
        return store.sorted(list, by: sort)
    }

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 230), spacing: 12)]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 18) {
                    if store.documents.isEmpty {
                        emptyState
                    } else {
                        if !selecting { filterBar }
                        if visible.isEmpty {
                            ContentUnavailableView.search(text: search)
                                .padding(.top, 40)
                        }
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(visible) { doc in
                                card(doc)
                            }
                        }
                        if !purchases.isPro && !selecting { freeCounter }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 120)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.immediately)
            .background { AppBackground() }
            .overlay(alignment: .bottom) {
                if selecting {
                    selectionBar
                } else if !store.documents.isEmpty {
                    scanBar
                }
            }
            .overlay {
                if working {
                    ProgressView(loc("working"))
                        .padding(24)
                        .glassBackground(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
            }
            .navigationTitle(selecting ? loc("selected_count", selection.count) : loc("library_title"))
            .searchable(text: $search, prompt: loc("search_prompt"))
            .toolbar { toolbar }
            .navigationDestination(for: UUID.self) { id in
                DocumentView(store: store, purchases: purchases, docID: id)
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScanner { images in
                showScanner = false
                Task { await create(from: images) }
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showPhotos, selection: $photoItems, maxSelectionCount: 50, matching: .images)
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            photoItems = []
            Task { await importPhotos(items) }
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                Task { await importFiles(urls) }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(purchases: purchases).appAppearance()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(store: store, purchases: purchases, lock: lock).appAppearance()
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView().appAppearance()
        }
        .sheet(item: $shareItem) { item in
            ActivityView(items: item.urls)
                .presentationDetents([.medium, .large])
        }
        .alert(loc("no_camera_title"), isPresented: $noCameraAlert) {
            Button(loc("import_photos")) { showPhotos = true }
            Button(loc("ok"), role: .cancel) {}
        } message: {
            Text(loc("no_camera_text"))
        }
        .alert(loc("rename"), isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField(loc("name_placeholder"), text: $renameText)
            Button(loc("save")) {
                if let doc = renaming { store.rename(doc.id, to: renameText) }
                renaming = nil
            }
            Button(loc("cancel"), role: .cancel) { renaming = nil }
        }
        .confirmationDialog(loc("delete_many_confirm", selection.count), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(loc("delete"), role: .destructive) {
                store.delete(Set(selection))
                endSelection()
            }
            Button(loc("cancel"), role: .cancel) {
                if !selecting { selection = [] }
            }
        }
    }

    // MARK: Barre d'outils

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if selecting {
            ToolbarItem(placement: .topBarTrailing) {
                Button(loc("done")) { endSelection() }.fontWeight(.bold)
            }
        } else {
            ToolbarItem(placement: .topBarLeading) {
                Button { showFeedback = true } label: { Image(systemName: "lightbulb") }
                    .accessibilityLabel(loc("feedback_title"))
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !store.documents.isEmpty {
                    Button {
                        withAnimation(.snappy) { selecting = true }
                    } label: {
                        Image(systemName: "checkmark.circle")
                    }
                    .accessibilityLabel(loc("select"))
                }
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel(loc("settings_title"))
            }
        }
    }

    // MARK: Vide

    private var emptyState: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 30)
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 58))
                .foregroundStyle(theme.diagonalGradient)
                .frame(width: 140, height: 140)
                .glassBackground(in: Circle())
            VStack(spacing: 10) {
                Text(loc("empty_title"))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(loc("empty_text"))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button(action: scanTapped) {
                PrimaryButtonLabel(title: loc("scan_button"), icon: "camera.viewfinder")
            }
            .buttonStyle(.plain)
            HStack(spacing: 12) {
                Button { importTapped(files: false) } label: {
                    GlassButtonLabel(title: loc("import_photos"), icon: "photo.on.rectangle")
                }
                .buttonStyle(.plain)
                Button { importTapped(files: true) } label: {
                    GlassButtonLabel(title: loc("import_files"), icon: "folder")
                }
                .buttonStyle(.plain)
            }
            Label(loc("empty_privacy"), systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: 520)
    }

    // MARK: Filtres

    private var filterBar: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.snappy) { favoritesOnly.toggle() }
                Haptics.tap()
            } label: {
                Label(loc("favorites"), systemImage: favoritesOnly ? "star.fill" : "star")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(favoritesOnly ? AnyShapeStyle(.yellow) : AnyShapeStyle(.primary))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassBackground(in: Capsule(), interactive: true)
            }
            .buttonStyle(.plain)
            Spacer()
            Menu {
                Picker(loc("sort_title"), selection: $sortRaw) {
                    ForEach(LibrarySort.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
            } label: {
                Label(sort.title, systemImage: "arrow.up.arrow.down")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassBackground(in: Capsule(), interactive: true)
            }
        }
    }

    // MARK: Carte

    @ViewBuilder
    private func card(_ doc: ScanDocument) -> some View {
        if selecting {
            let index = selection.firstIndex(of: doc.id)
            Button {
                Haptics.tap()
                if let index { selection.remove(at: index) } else { selection.append(doc.id) }
            } label: {
                DocumentCard(store: store, document: doc, selected: index != nil)
                    .overlay(alignment: .topLeading) {
                        if let index {
                            Text("\(index + 1)")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(theme.primary))
                                .padding(18)
                        }
                    }
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: doc.id) {
                DocumentCard(store: store, document: doc, snippet: doc.name.localizedStandardContains(search) ? nil : store.snippet(doc, for: search))
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    Task { await share([doc.id]) }
                } label: { Label(loc("share"), systemImage: "square.and.arrow.up") }
                Button {
                    renameText = doc.name
                    renaming = doc
                } label: { Label(loc("rename"), systemImage: "pencil") }
                Button {
                    store.toggleFavorite(doc.id)
                } label: {
                    Label(doc.isFavorite ? loc("unfavorite") : loc("favorite"), systemImage: doc.isFavorite ? "star.slash" : "star")
                }
                Button {
                    if store.canAdd(isPro: purchases.isPro) { store.duplicate(doc.id) } else { showPaywall = true }
                } label: { Label(loc("duplicate"), systemImage: "plus.square.on.square") }
                Button(role: .destructive) {
                    selection = [doc.id]
                    confirmDelete = true
                } label: { Label(loc("delete"), systemImage: "trash") }
            }
        }
    }

    // MARK: Barres du bas

    private var scanBar: some View {
        HStack(spacing: 12) {
            Menu {
                Button { importTapped(files: false) } label: { Label(loc("import_photos"), systemImage: "photo.on.rectangle") }
                Button { importTapped(files: true) } label: { Label(loc("import_files"), systemImage: "folder") }
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 58, height: 58)
                    .glassBackground(in: Circle(), interactive: true)
            }
            .accessibilityLabel(loc("import"))
            Button(action: scanTapped) {
                Label(loc("scan_button"), systemImage: "camera.viewfinder")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 30)
                    .frame(height: 58)
                    .background(theme.diagonalGradient, in: Capsule())
                    .shadow(color: theme.primary.opacity(0.45), radius: 14, y: 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 14)
    }

    private var selectionBar: some View {
        HStack(spacing: 4) {
            ActionButton(title: loc("merge"), icon: "rectangle.stack.badge.plus") { mergeSelection() }
                .disabled(selection.count < 2)
                .opacity(selection.count < 2 ? 0.4 : 1)
            ActionButton(title: loc("share"), icon: "square.and.arrow.up") {
                Task { await share(selection) }
            }
            .disabled(selection.isEmpty)
            .opacity(selection.isEmpty ? 0.4 : 1)
            ActionButton(title: loc("delete"), icon: "trash") { confirmDelete = true }
                .disabled(selection.isEmpty)
                .opacity(selection.isEmpty ? 0.4 : 1)
        }
        .padding(.horizontal, 10)
        .glassBackground(in: Capsule())
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
        .frame(maxWidth: 520)
    }

    private var freeCounter: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "crown.fill").foregroundStyle(.yellow)
                Text(loc("free_counter", store.documents.count, AppConfig.freeDocumentLimit))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(loc("unlock"))
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(theme.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassBackground(in: Capsule(), interactive: true)
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

    private func scanTapped() {
        Haptics.tap()
        guard store.canAdd(isPro: purchases.isPro) else { showPaywall = true; return }
        if DocumentScanner.isAvailable {
            showScanner = true
        } else {
            noCameraAlert = true
        }
    }

    private func importTapped(files: Bool) {
        Haptics.tap()
        guard store.canAdd(isPro: purchases.isPro) else { showPaywall = true; return }
        if files { showFiles = true } else { showPhotos = true }
    }

    private func create(from images: [UIImage], name: String? = nil, open: Bool = true) async {
        guard !images.isEmpty else { return }
        working = true
        let id = await store.createDocument(from: images, name: name)
        working = false
        guard let id else { return }
        Haptics.success()
        if open { path.append(id) }
        askReviewIfNeeded()
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        working = true
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                images.append(image)
            }
        }
        working = false
        await create(from: images)
    }

    private func importFiles(_ urls: [URL]) async {
        working = true
        var looseImages: [UIImage] = []
        var pdfs: [(String, [UIImage])] = []
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            if url.pathExtension.lowercased() == "pdf" {
                let pages = PDFExporter.images(fromPDF: url)
                if !pages.isEmpty { pdfs.append((url.deletingPathExtension().lastPathComponent, pages)) }
            } else if let image = UIImage(contentsOfFile: url.path) {
                looseImages.append(image)
            }
        }
        working = false
        var created = 0
        for (name, pages) in pdfs {
            guard store.canAdd(isPro: purchases.isPro) else { showPaywall = true; return }
            await create(from: pages, name: name, open: pdfs.count == 1 && looseImages.isEmpty)
            created += 1
        }
        if !looseImages.isEmpty {
            guard store.canAdd(isPro: purchases.isPro) else { showPaywall = true; return }
            await create(from: looseImages, open: created == 0)
        }
    }

    private func mergeSelection() {
        guard selection.count >= 2 else { return }
        guard store.canAdd(isPro: purchases.isPro) else { showPaywall = true; return }
        let firstName = store.document(selection[0])?.name ?? L10n.defaultScanName()
        if let id = store.merge(selection, name: loc("merged_name", firstName)) {
            Haptics.success()
            endSelection()
            path.append(id)
        }
    }

    private func share(_ ids: [UUID]) async {
        guard !ids.isEmpty else { return }
        working = true
        let quality = ExportQuality.saved
        let jobs = ids.compactMap { id in store.document(id).map { (name: $0.name, pages: store.exportPages(id)) } }
        let urls = await Task.detached(priority: .userInitiated) { () -> [URL] in
            jobs.compactMap { PDFExporter.makePDF(name: $0.name, pages: $0.pages, quality: quality, password: nil) }
        }.value
        working = false
        if !urls.isEmpty { shareItem = ShareItem(urls: urls) }
    }

    private func endSelection() {
        withAnimation(.snappy) {
            selecting = false
            selection = []
        }
    }

    private func askReviewIfNeeded() {
        guard !reviewRequested, UserDefaults.standard.integer(forKey: SettingsKey.scanCount) >= 3 else { return }
        reviewRequested = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            requestReview()
        }
    }
}
