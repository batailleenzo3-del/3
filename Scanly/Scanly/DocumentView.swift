//
//  DocumentView.swift
//  Un document : ses pages (zoom en touchant une page), et les actions —
//  partager (PDF, images, texte, mot de passe), texte reconnu, signer, pages, ajouter.
//

import SwiftUI
import Combine

struct DocumentView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: DocumentStore
    @ObservedObject var purchases: PurchaseManager
    let docID: UUID

    @State private var showExport = false
    @State private var showText = false
    @State private var showPages = false
    @State private var showSign = false
    @State private var showScanner = false
    @State private var zoomPage: ScanPage?
    @State private var renaming = false
    @State private var renameText = ""
    @State private var confirmDelete = false
    @State private var showPaywall = false

    var body: some View {
        Group {
            if let doc = store.document(docID) {
                content(doc)
            } else {
                ContentUnavailableView(loc("doc_missing"), systemImage: "questionmark.circle")
            }
        }
        .background { AppBackground() }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(_ doc: ScanDocument) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                header(doc)
                ForEach(Array(doc.pages.enumerated()), id: \.element.id) { index, page in
                    pageView(doc, page: page, index: index)
                }
            }
            .padding(16)
            .padding(.bottom, 110)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .bottom) { actionBar(doc) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { menu(doc) }
        }
        .sheet(isPresented: $showExport) {
            ExportSheet(store: store, docID: docID).appAppearance()
        }
        .sheet(isPresented: $showText) {
            TextSheet(store: store, docID: docID).appAppearance()
        }
        .sheet(isPresented: $showPages) {
            PagesEditor(store: store, docID: docID).appAppearance()
        }
        .sheet(isPresented: $showSign) {
            SignFlow(store: store, docID: docID).appAppearance()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(purchases: purchases).appAppearance()
        }
        .fullScreenCover(item: $zoomPage) { page in
            ZoomPageView(image: store.image(docID, page.file)) { zoomPage = nil }
        }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScanner { images in
                showScanner = false
                Task { await store.addPages(images, to: docID) }
            }
            .ignoresSafeArea()
        }
        .alert(loc("rename"), isPresented: $renaming) {
            TextField(loc("name_placeholder"), text: $renameText)
            Button(loc("save")) { store.rename(docID, to: renameText) }
            Button(loc("cancel"), role: .cancel) {}
        } message: {
            if let suggestion = doc.suggestedName, suggestion != doc.name {
                Text(loc("rename_suggestion", suggestion))
            }
        }
        .confirmationDialog(loc("delete_confirm", doc.name), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(loc("delete"), role: .destructive) {
                store.delete([docID])
                dismiss()
            }
            Button(loc("cancel"), role: .cancel) {}
        }
    }

    // MARK: En-tête

    private func header(_ doc: ScanDocument) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                renameText = doc.name
                renaming = true
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(doc.name)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.leading)
                    Image(systemName: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            HStack(spacing: 6) {
                Text("\(L10n.shortDate(doc.createdAt)) · \(L10n.pages(doc.pages.count)) · \(L10n.fileSize(store.fileSize(doc)))")
                if store.busy.contains(doc.id) {
                    ProgressView().controlSize(.mini)
                } else if !doc.isTextReady {
                    Label(loc("ocr_running"), systemImage: "text.viewfinder")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            if let suggestion = doc.suggestedName, doc.name.hasPrefix(L10n.t("default_name_prefix")) {
                Button {
                    store.rename(docID, to: suggestion)
                    Haptics.tap()
                } label: {
                    Label(loc("use_name", suggestion), systemImage: "sparkles")
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .glassBackground(in: Capsule(), tint: theme.primary.opacity(0.18), interactive: true)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Page

    private func pageView(_ doc: ScanDocument, page: ScanPage, index: Int) -> some View {
        Button {
            zoomPage = page
        } label: {
            ZStack {
                if let image = store.image(doc.id, page.file) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    Rectangle().fill(.white).aspectRatio(0.707, contentMode: .fit)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
            .overlay(alignment: .bottomTrailing) {
                Text("\(index + 1) / \(doc.pages.count)")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.black.opacity(0.55)))
                    .foregroundStyle(.white)
                    .padding(10)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(loc("page_n", index + 1))
    }

    // MARK: Actions

    private func actionBar(_ doc: ScanDocument) -> some View {
        HStack(spacing: 2) {
            ActionButton(title: loc("share"), icon: "square.and.arrow.up") { showExport = true }
            ActionButton(title: loc("text"), icon: "text.viewfinder") { showText = true }
            ActionButton(title: loc("sign"), icon: "signature") { showSign = true }
            ActionButton(title: loc("pages"), icon: "square.grid.2x2") { showPages = true }
            ActionButton(title: loc("add_pages"), icon: "plus.viewfinder") {
                if DocumentScanner.isAvailable { showScanner = true }
            }
            .disabled(!DocumentScanner.isAvailable)
            .opacity(DocumentScanner.isAvailable ? 1 : 0.4)
        }
        .padding(.horizontal, 8)
        .glassBackground(in: Capsule())
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: 560)
    }

    private func menu(_ doc: ScanDocument) -> some View {
        Menu {
            Button {
                store.toggleFavorite(docID)
            } label: {
                Label(doc.isFavorite ? loc("unfavorite") : loc("favorite"), systemImage: doc.isFavorite ? "star.slash" : "star")
            }
            Button {
                renameText = doc.name
                renaming = true
            } label: { Label(loc("rename"), systemImage: "pencil") }
            Menu {
                ForEach(ScanFilter.allCases) { filter in
                    Button {
                        Task { await store.setFilterForAllPages(filter, docID: docID) }
                    } label: { Label(filter.title, systemImage: filter.icon) }
                }
            } label: { Label(loc("filter_all"), systemImage: "camera.filters") }
            Button {
                if store.canAdd(isPro: purchases.isPro) { store.duplicate(docID) } else { showPaywall = true }
            } label: { Label(loc("duplicate"), systemImage: "plus.square.on.square") }
            Button(role: .destructive) {
                confirmDelete = true
            } label: { Label(loc("delete"), systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel(loc("more"))
    }
}

// MARK: - Page en plein écran (zoom)

struct ZoomPageView: View {
    let image: UIImage?
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let image {
                ZoomableImage(image: image)
                    .ignoresSafeArea()
            }
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .glassBackground(in: Circle(), interactive: true)
            }
            .buttonStyle(.plain)
            .padding(16)
            .accessibilityLabel(loc("close"))
        }
    }
}

/// Image zoomable (pincer, double-tap).
struct ZoomableImage: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.delegate = context.coordinator
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 5
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.backgroundColor = .black
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            imageView.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor)
        ])
        context.coordinator.imageView = imageView
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)
        return scroll
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        @objc func doubleTapped(_ gesture: UITapGestureRecognizer) {
            guard let scroll = gesture.view as? UIScrollView else { return }
            if scroll.zoomScale > 1 {
                scroll.setZoomScale(1, animated: true)
            } else {
                let point = gesture.location(in: imageView)
                let size = CGSize(width: scroll.bounds.width / 2.5, height: scroll.bounds.height / 2.5)
                scroll.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                                       width: size.width, height: size.height), animated: true)
            }
        }
    }
}
