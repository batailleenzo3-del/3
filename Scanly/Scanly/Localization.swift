//
//  Localization.swift
//  Textes dans la langue de l'iPhone (français, anglais, espagnol, allemand, italien) et dates.
//
//  Usage dans les écrans : loc("library_title")  ou  loc("pages_count", 4)
//  Les traductions sont dans Strings.swift.
//

import Foundation

nonisolated enum L10n {
    static let supportedLanguages = ["fr", "en", "es", "de", "it"]

    /// Langue utilisée par l'app (la première langue de l'iPhone qu'on sait parler, sinon anglais).
    static let language: String = {
        for preferred in Locale.preferredLanguages {
            let code = String(preferred.prefix(2))
            if supportedLanguages.contains(code) { return code }
        }
        return "en"
    }()

    /// Texte traduit. Les {0}, {1}… sont remplacés par les valeurs données.
    static func t(_ key: String, _ args: CustomStringConvertible...) -> String {
        format(Strings.table(for: language)[key] ?? Strings.en[key] ?? key, args)
    }

    static func format(_ template: String, _ args: [CustomStringConvertible]) -> String {
        var text = template
        for (index, value) in args.enumerated() {
            text = text.replacingOccurrences(of: "{\(index)}", with: value.description)
        }
        return text
    }

    // MARK: Dates

    private static func formatter(_ template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language)
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    private static let shortFormatter = formatter("d MMM yyyy")
    private static let nameFormatter = formatter("d MMM yyyy HH:mm")

    /// "12 mars 2027"
    static func shortDate(_ date: Date) -> String { shortFormatter.string(from: date) }

    /// "Aujourd'hui", "Hier" ou "12 mars 2027".
    static func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return t("day_today") }
        if calendar.isDateInYesterday(date) { return t("day_yesterday") }
        return shortDate(date)
    }

    /// Nom par défaut d'un nouveau scan : "Scan 12 mars 2027 14:32"
    static func defaultScanName(_ date: Date = .now) -> String {
        t("default_name", nameFormatter.string(from: date))
    }

    /// "3 pages" / "1 page"
    static func pages(_ count: Int) -> String {
        count == 1 ? t("page_one") : t("pages_count", count)
    }

    /// "1,2 Mo"
    static func fileSize(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

/// Raccourci utilisé dans les écrans.
func loc(_ key: String, _ args: CustomStringConvertible...) -> String {
    L10n.format(L10n.t(key), args)
}
