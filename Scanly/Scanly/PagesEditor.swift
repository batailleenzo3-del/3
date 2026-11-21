//
//  PagesEditor.swift
//  Gérer les pages : réordonner (glisser), supprimer, tourner, changer de filtre.
//

import SwiftUI
import Combine

struct PagesEditor: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: DocumentStore
    let docID: UUID

    var body: some View {
        NavigationStack {
            Group {
                if let doc = store.document(docID) {
                    List {
                        Section {
                            ForEach(Array(doc.pages.enumerated()), id: \.element.id) { index, page in
                                row(doc, page: page, index: index)
                            }
                            .onMove { source, destination in
                                store.movePages(docID, from: source, to: destination)
                            }
                            .onDelete { offsets in
                                store.deletePages(docID, at: offsets)
                                if store.document(docID) == nil { dismiss() }
                            }
                        } footer: {
                            Text(loc("pages_footer"))
                        }
                    }
                    .environment(\.editMode, .constant(.active))
                } else {
                    Color.clear
                }
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .tint(theme.primary)
            .navigationTitle(loc("pages"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("done")) { dismiss() }.fontWeight(.bold)
                }
            }
        }
    }

    private func row(_ doc: ScanDocument, page: ScanPage, index: Int) -> some View {
        HStack(spacing: 14) {
            PageThumbnail(store: store, docID: doc.id, file: page.file, cornerRadius: 8)
                .frame(width: 62, height: 82)
                .overlay {
                    if store.busy.contains(doc.id) { ProgressView() }
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(loc("page_n", index + 1))
                    .font(.headline)
                Label(page.filter.title, systemImage: page.filter.icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button {
                    Task { await store.rotatePage(docID, pageID: page.id, clockwise: false) }
                } label: { Label(loc("rotate_left"), systemImage: "rotate.left") }
                Button {
                    Task { await store.rotatePage(docID, pageID: page.id, clockwise: true) }
                } label: { Label(loc("rotate_right"), systemImage: "rotate.right") }
                Section(loc("filter")) {
                    ForEach(ScanFilter.allCases) { filter in
                        Button {
                            Task { await store.setFilter(filter, docID: docID, pageID: page.id) }
                        } label: {
                            Label(filter.title, systemImage: page.filter == filter ? "checkmark" : filter.icon)
                        }
                    }
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(loc("edit_page"))
        }
        .padding(.vertical, 4)
    }
}
