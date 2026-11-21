//
//  PDFExporter.swift
//  Fabrique les fichiers à partager : PDF « recherchable » (le texte reconnu est caché
//  sous l'image, on peut le sélectionner et le chercher), protégé ou non par mot de passe,
//  images JPEG, ou texte brut. Tout se fait sur l'iPhone.
//

import UIKit
import PDFKit

nonisolated enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case pdf, images, text

    var id: String { rawValue }

    var title: String { L10n.t("format_\(rawValue)") }

    var icon: String {
        switch self {
        case .pdf: return "doc.richtext.fill"
        case .images: return "photo.on.rectangle.angled"
        case .text: return "text.alignleft"
        }
    }
}

nonisolated struct ExportPage: Sendable {
    let imageURL: URL
    let lines: [TextLine]
}

nonisolated enum PDFExporter {

    /// Largeur d'une page PDF (points). La hauteur suit les proportions du scan (A4 ≈ 595 × 842).
    private static let pageWidth: CGFloat = 595

    /// Dossier temporaire propre à chaque export.
    private static func exportFolder() -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("Export-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Nom de fichier sans caractères interdits.
    static func safeName(_ name: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = name.components(separatedBy: forbidden).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Scan" : String(cleaned.prefix(80))
    }

    // MARK: PDF

    static func makePDF(name: String, pages: [ExportPage], quality: ExportQuality, password: String?) -> URL? {
        let url = exportFolder().appendingPathComponent(safeName(name) + ".pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageWidth * 1.414))
        let data = renderer.pdfData { context in
            for page in pages {
                autoreleasepool {
                    guard let source = UIImage(contentsOfFile: page.imageURL.path) else { return }
                    let resized = ImageProcessing.normalized(source, maxDimension: quality.maxDimension)
                    guard let jpeg = resized.jpegData(compressionQuality: quality.jpegQuality),
                          let provider = CGDataProvider(data: jpeg as CFData),
                          // Image JPEG « telle quelle » : le PDF reste léger.
                          let cgImage = CGImage(jpegDataProviderSource: provider, decode: nil,
                                                shouldInterpolate: true, intent: .defaultIntent) else { return }

                    let height = pageWidth * resized.size.height / max(1, resized.size.width)
                    let bounds = CGRect(x: 0, y: 0, width: pageWidth, height: height)
                    context.beginPage(withBounds: bounds, pageInfo: [:])
                    let cg = context.cgContext

                    // Texte invisible d'abord (sous l'image) : le PDF devient sélectionnable et cherchable.
                    cg.saveGState()
                    cg.setTextDrawingMode(.invisible)
                    for line in page.lines {
                        let rect = CGRect(x: line.x * pageWidth, y: line.y * height,
                                          width: line.w * pageWidth, height: line.h * height)
                        let fontSize = max(2, rect.height * 0.82)
                        let font = UIFont.systemFont(ofSize: fontSize)
                        var attributes: [NSAttributedString.Key: Any] = [.font: font]
                        // Étire le texte pour couvrir la largeur de la ligne (sélection précise).
                        let natural = (line.text as NSString).size(withAttributes: attributes).width
                        if natural > 0 {
                            let ratio = rect.width / natural
                            attributes[.expansion] = log(max(0.2, min(5, ratio)))
                        }
                        (line.text as NSString).draw(at: rect.origin, withAttributes: attributes)
                    }
                    cg.restoreGState()

                    // L'image par-dessus (le repère PDF est inversé verticalement).
                    cg.saveGState()
                    cg.translateBy(x: 0, y: height)
                    cg.scaleBy(x: 1, y: -1)
                    cg.draw(cgImage, in: CGRect(x: 0, y: 0, width: pageWidth, height: height))
                    cg.restoreGState()
                }
            }
        }

        let trimmed = password?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty, let document = PDFDocument(data: data) {
            let options: [PDFDocumentWriteOption: Any] = [
                .userPasswordOption: trimmed,
                .ownerPasswordOption: trimmed
            ]
            return document.write(to: url, withOptions: options) ? url : nil
        }
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // MARK: Images

    static func makeImages(name: String, pages: [ExportPage], quality: ExportQuality) -> [URL] {
        let folder = exportFolder()
        let base = safeName(name)
        var urls: [URL] = []
        for (index, page) in pages.enumerated() {
            autoreleasepool {
                guard let source = UIImage(contentsOfFile: page.imageURL.path) else { return }
                let resized = ImageProcessing.normalized(source, maxDimension: quality.maxDimension)
                guard let data = resized.jpegData(compressionQuality: quality.jpegQuality) else { return }
                let suffix = pages.count > 1 ? " \(index + 1)" : ""
                let url = folder.appendingPathComponent("\(base)\(suffix).jpg")
                if (try? data.write(to: url, options: .atomic)) != nil { urls.append(url) }
            }
        }
        return urls
    }

    // MARK: Texte

    static func makeText(name: String, text: String) -> URL? {
        let url = exportFolder().appendingPathComponent(safeName(name) + ".txt")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    // MARK: Import d'un PDF

    /// Transforme chaque page d'un PDF en image (pour l'importer comme un scan).
    static func images(fromPDF url: URL, maxPages: Int = 200) -> [UIImage] {
        guard let document = PDFDocument(url: url) else { return [] }
        var result: [UIImage] = []
        for index in 0..<min(document.pageCount, maxPages) {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let scale = min(3, AppConfig.maxPageDimension / max(1, max(bounds.width, bounds.height)))
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            result.append(page.thumbnail(of: size, for: .mediaBox))
        }
        return result
    }
}
