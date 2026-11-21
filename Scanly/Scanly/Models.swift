//
//  Models.swift
//  Les types de données (document, page, filtre, qualité d'export…) et les réglages.
//

import Foundation
import SwiftUI

// MARK: - Réglages (clés de sauvegarde)

nonisolated enum SettingsKey {
    static let onboardingDone = "settings.onboardingDone"
    static let appearance = "settings.appearance"
    static let haptics = "settings.haptics"
    static let reviewRequested = "settings.reviewRequested"
    static let theme = "settings.theme"
    static let glassLevel = "settings.glassLevel"
    static let defaultFilter = "settings.defaultFilter"
    static let exportQuality = "settings.exportQuality"
    static let appLock = "settings.appLock"
    static let librarySort = "settings.librarySort"
    static let scanCount = "settings.scanCount"
}

/// Thème clair / sombre.
nonisolated enum AppearanceOption: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    var id: String { rawValue }

    var title: String { L10n.t("appearance_\(rawValue)") }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Filtre d'une page

nonisolated enum ScanFilter: String, CaseIterable, Identifiable, Codable, Sendable {
    /// Amélioration automatique (fond blanc, texte net).
    case auto
    case color
    case gray
    case blackWhite

    var id: String { rawValue }

    var title: String { L10n.t("filter_\(rawValue)") }

    var icon: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .color: return "paintpalette.fill"
        case .gray: return "circle.lefthalf.filled"
        case .blackWhite: return "doc.plaintext.fill"
        }
    }

    static var defaultFilter: ScanFilter {
        ScanFilter(rawValue: UserDefaults.standard.string(forKey: SettingsKey.defaultFilter) ?? "") ?? .auto
    }
}

// MARK: - Qualité d'export (taille du PDF)

nonisolated enum ExportQuality: String, CaseIterable, Identifiable, Sendable {
    case high, medium, small

    var id: String { rawValue }

    var title: String { L10n.t("quality_\(rawValue)") }
    var caption: String { L10n.t("quality_\(rawValue)_caption") }

    var maxDimension: CGFloat {
        switch self {
        case .high: return 3000
        case .medium: return 2000
        case .small: return 1300
        }
    }

    var jpegQuality: CGFloat {
        switch self {
        case .high: return 0.85
        case .medium: return 0.6
        case .small: return 0.4
        }
    }

    static var saved: ExportQuality {
        ExportQuality(rawValue: UserDefaults.standard.string(forKey: SettingsKey.exportQuality) ?? "") ?? .medium
    }
}

/// Ordre de la bibliothèque.
nonisolated enum LibrarySort: String, CaseIterable, Identifiable, Sendable {
    case recent, name, pages

    var id: String { rawValue }

    var title: String { L10n.t("sort_\(rawValue)") }
}

// MARK: - Texte reconnu

/// Une ligne de texte reconnue sur une page. Position en proportion de la page
/// (0…1, origine en haut à gauche) : sert à rendre le PDF « recherchable ».
nonisolated struct TextLine: Codable, Hashable, Sendable {
    var text: String
    var x: Double
    var y: Double
    var w: Double
    var h: Double
}

// MARK: - Page

nonisolated struct ScanPage: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    /// Image affichée (avec le filtre).
    var file: String
    /// Image d'origine (pour changer de filtre sans perte).
    var original: String
    var filter: ScanFilter
    var lines: [TextLine]
    /// La reconnaissance du texte a été faite.
    var ocrDone: Bool

    init(id: UUID = UUID(), file: String, original: String, filter: ScanFilter,
         lines: [TextLine] = [], ocrDone: Bool = false) {
        self.id = id
        self.file = file
        self.original = original
        self.filter = filter
        self.lines = lines
        self.ocrDone = ocrDone
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        file = try c.decodeIfPresent(String.self, forKey: .file) ?? ""
        original = try c.decodeIfPresent(String.self, forKey: .original) ?? file
        filter = (try? c.decodeIfPresent(ScanFilter.self, forKey: .filter)) ?? .auto
        lines = try c.decodeIfPresent([TextLine].self, forKey: .lines) ?? []
        ocrDone = try c.decodeIfPresent(Bool.self, forKey: .ocrDone) ?? false
    }

    var text: String { lines.map(\.text).joined(separator: "\n") }
}

// MARK: - Document

nonisolated struct ScanDocument: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var pages: [ScanPage]
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, pages: [ScanPage] = [], isFavorite: Bool = false,
         createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.name = name
        self.pages = pages
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        pages = try c.decodeIfPresent([ScanPage].self, forKey: .pages) ?? []
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
    }

    /// Tout le texte reconnu, page par page.
    var fullText: String {
        pages.map(\.text).filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    var isTextReady: Bool { pages.allSatisfy(\.ocrDone) }

    /// Première ligne de texte significative : proposée comme nom.
    var suggestedName: String? {
        for page in pages {
            for line in page.lines {
                let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.count >= 4 && text.count <= 60 && text.contains(where: \.isLetter) {
                    return text
                }
            }
        }
        return nil
    }
}
