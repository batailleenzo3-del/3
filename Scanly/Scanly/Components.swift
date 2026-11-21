//
//  Components.swift
//  Petits éléments réutilisés partout : carte d'un document, bouton principal, vibrations.
//

import SwiftUI
import UIKit

// MARK: - Miniature d'une page

struct PageThumbnail: View {
    @ObservedObject var store: DocumentStore
    let docID: UUID
    let file: String?
    var cornerRadius: CGFloat = 12

    var body: some View {
        ZStack {
            Rectangle().fill(Color.white.opacity(0.9))
            if let file, let image = store.thumbnail(docID, file) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "doc.text")
                    .font(.title)
                    .foregroundStyle(.gray)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
        .accessibilityHidden(true)
    }
}

// MARK: - Carte d'un document (bibliothèque)

struct DocumentCard: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var store: DocumentStore
    let document: ScanDocument
    var snippet: String? = nil
    var selected: Bool? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PageThumbnail(store: store, docID: document.id, file: document.pages.first?.file)
                .aspectRatio(0.75, contentMode: .fit)
                .overlay(alignment: .topTrailing) {
                    if let selected {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(selected ? AnyShapeStyle(theme.primary) : AnyShapeStyle(.white))
                            .background(Circle().fill(.black.opacity(selected ? 0 : 0.25)))
                            .padding(8)
                    } else if document.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.yellow)
                            .padding(6)
                            .background(Circle().fill(.black.opacity(0.35)))
                            .padding(8)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if store.busy.contains(document.id) {
                        ProgressView()
                            .padding(8)
                            .background(Circle().fill(.ultraThinMaterial))
                            .padding(8)
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(document.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let snippet {
                    Text(snippet)
                        .font(.caption)
                        .foregroundStyle(theme.primary)
                        .lineLimit(2)
                } else {
                    Text("\(L10n.relativeDate(document.updatedAt)) · \(L10n.pages(document.pages.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .glassBackground(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Bouton principal (dégradé)

struct PrimaryButtonLabel: View {
    @Environment(\.appTheme) private var theme
    let title: String
    var icon: String? = nil
    var isLoading = false

    var body: some View {
        HStack(spacing: 8) {
            if isLoading { ProgressView().tint(.white) }
            if let icon { Image(systemName: icon) }
            Text(title)
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(theme.gradient, in: Capsule())
        .foregroundStyle(.white)
    }
}

/// Bouton secondaire en verre.
struct GlassButtonLabel: View {
    let title: String
    let icon: String
    var tint: Color = .primary

    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .glassBackground(in: Capsule(), interactive: true)
    }
}

// MARK: - Bouton d'action (barre du document)

struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .frame(height: 22)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Carte en verre

extension View {
    /// Carte en verre pleine largeur.
    func glassCard(cornerRadius: CGFloat = 26, padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassBackground(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Vibrations

enum Haptics {
    private static var enabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.haptics) as? Bool ?? true
    }

    static func tap() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
