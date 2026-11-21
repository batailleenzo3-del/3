//
//  DocumentStore.swift
//  La bibliothèque : documents et pages enregistrés sur l'iPhone (dossier de l'app,
//  inclus dans la sauvegarde iCloud de l'appareil). Rien n'est envoyé sur internet.
//
//  Organisation des fichiers :
//    Application Support/Scans/library.json        ← la liste des documents
//    Application Support/Scans/<id du document>/   ← les images des pages
//    Application Support/Scans/signature.png       ← la signature enregistrée
//

import Foundation
import Combine
import SwiftUI
import UIKit

@MainActor
final class DocumentStore: ObservableObject {
    @Published private(set) var documents: [ScanDocument] = []
    /// Documents en cours de traitement (filtre, reconnaissance du texte).
    @Published private(set) var busy: Set<UUID> = []
    @Published private(set) var signature: UIImage?

    let root: URL
    private let libraryURL: URL
    private let signatureURL: URL
    private let cache = NSCache<NSString, UIImage>()

    init() {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        root = base.appendingPathComponent("Scans", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        libraryURL = root.appendingPathComponent("library.json")
        signatureURL = root.appendingPathComponent("signature.png")
        cache.countLimit = 120
        load()
        signature = UIImage(contentsOfFile: signatureURL.path)
        resumeTextRecognition()
    }

    // MARK: Accès

    func document(_ id: UUID) -> ScanDocument? {
        documents.first { $0.id == id }
    }

    func folder(_ id: UUID) -> URL {
        root.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    func fileURL(_ docID: UUID, _ file: String) -> URL {
        folder(docID).appendingPathComponent(file)
    }

    /// Image d'une page (mise en cache).
    func image(_ docID: UUID, _ file: String) -> UIImage? {
        let key = "\(docID.uuidString)/\(file)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = UIImage(contentsOfFile: fileURL(docID, file).path) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    /// Miniature de la première page (ou d'une page donnée).
    func thumbnail(_ docID: UUID, _ file: String) -> UIImage? {
        let key = "thumb/\(docID.uuidString)/\(file)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let full = UIImage(contentsOfFile: fileURL(docID, file).path) else { return nil }
        let thumb = ImageProcessing.thumbnail(full)
        cache.setObject(thumb, forKey: key)
        return thumb
    }

    func sorted(_ list: [ScanDocument], by sort: LibrarySort) -> [ScanDocument] {
        switch sort {
        case .recent: return list.sorted { $0.updatedAt > $1.updatedAt }
        case .name: return list.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .pages: return list.sorted { $0.pages.count > $1.pages.count }
        }
    }

    /// Recherche dans le nom ET dans le texte reconnu des pages.
    func search(_ query: String) -> [ScanDocument] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return documents }
        return documents.filter {
            $0.name.localizedStandardContains(text) || $0.fullText.localizedStandardContains(text)
        }
    }

    /// Extrait du texte autour du mot cherché (affiché sous le document).
    func snippet(_ doc: ScanDocument, for query: String) -> String? {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        for page in doc.pages {
            for line in page.lines where line.text.localizedStandardContains(text) {
                return line.text
            }
        }
        return nil
    }

    func fileSize(_ doc: ScanDocument) -> Int {
        doc.pages.reduce(0) { total, page in
            let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL(doc.id, page.file).path)
            return total + ((attributes?[.size] as? Int) ?? 0)
        }
    }

    // MARK: Version gratuite

    func canAdd(isPro: Bool) -> Bool {
        isPro || documents.count < AppConfig.freeDocumentLimit
    }

    var freeSlotsLeft: Int { max(0, AppConfig.freeDocumentLimit - documents.count) }

    // MARK: Création

    /// Crée un document à partir de pages scannées ou importées. Renvoie son identifiant.
    @discardableResult
    func createDocument(from images: [UIImage], name: String? = nil) async -> UUID? {
        guard !images.isEmpty else { return nil }
        let doc = ScanDocument(name: name ?? L10n.defaultScanName())
        let folder = folder(doc.id)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        busy.insert(doc.id)
        let pages = await Self.writePages(images, to: folder, filter: ScanFilter.defaultFilter)
        busy.remove(doc.id)
        guard !pages.isEmpty else {
            try? FileManager.default.removeItem(at: folder)
            return nil
        }
        var created = doc
        created.pages = pages
        documents.append(created)
        save()
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: SettingsKey.scanCount) + 1,
                                  forKey: SettingsKey.scanCount)
        recognizeText(in: created.id)
        return created.id
    }

    /// Ajoute des pages à la fin d'un document.
    func addPages(_ images: [UIImage], to docID: UUID) async {
        guard !images.isEmpty, document(docID) != nil else { return }
        busy.insert(docID)
        let pages = await Self.writePages(images, to: folder(docID), filter: ScanFilter.defaultFilter)
        busy.remove(docID)
        mutate(docID) { $0.pages.append(contentsOf: pages) }
        recognizeText(in: docID)
    }

    /// Enregistre l'original et la version filtrée de chaque page (en arrière-plan).
    private nonisolated static func writePages(_ images: [UIImage], to folder: URL, filter: ScanFilter) async -> [ScanPage] {
        await Task.detached(priority: .userInitiated) { () -> [ScanPage] in
            var pages: [ScanPage] = []
            for image in images {
                autoreleasepool {
                    let id = UUID()
                    let normalized = ImageProcessing.normalized(image)
                    let processed = ImageProcessing.apply(filter, to: normalized)
                    let original = "orig-\(id.uuidString).jpg"
                    let file = "page-\(id.uuidString).jpg"
                    guard let originalData = ImageProcessing.jpeg(normalized, quality: 0.85),
                          let processedData = ImageProcessing.jpeg(processed),
                          (try? originalData.write(to: folder.appendingPathComponent(original), options: .atomic)) != nil,
                          (try? processedData.write(to: folder.appendingPathComponent(file), options: .atomic)) != nil
                    else { return }
                    pages.append(ScanPage(id: id, file: file, original: original, filter: filter))
                }
            }
            return pages
        }.value
    }

    // MARK: Reconnaissance du texte

    /// Lance l'OCR sur les pages qui ne l'ont pas encore eu.
    func recognizeText(in docID: UUID) {
        guard let doc = document(docID) else { return }
        let todo = doc.pages.filter { !$0.ocrDone }.map { (id: $0.id, url: fileURL(docID, $0.file)) }
        guard !todo.isEmpty else { return }
        Task {
            for item in todo {
                let lines = await Task.detached(priority: .utility) { () -> [TextLine] in
                    guard let image = UIImage(contentsOfFile: item.url.path) else { return [] }
                    return TextRecognizer.recognize(image)
                }.value
                mutate(docID, touch: false) { doc in
                    if let index = doc.pages.firstIndex(where: { $0.id == item.id }) {
                        doc.pages[index].lines = lines
                        doc.pages[index].ocrDone = true
                    }
                }
            }
        }
    }

    /// Au lancement : termine l'OCR interrompu (app fermée pendant le traitement).
    private func resumeTextRecognition() {
        for doc in documents where !doc.isTextReady {
            recognizeText(in: doc.id)
        }
    }

    // MARK: Modifications

    func rename(_ docID: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mutate(docID) { $0.name = String(trimmed.prefix(120)) }
    }

    func toggleFavorite(_ docID: UUID) {
        mutate(docID, touch: false) { $0.isFavorite.toggle() }
    }

    func delete(_ ids: Set<UUID>) {
        for id in ids {
            try? FileManager.default.removeItem(at: folder(id))
        }
        documents.removeAll { ids.contains($0.id) }
        save()
    }

    func deletePages(_ docID: UUID, at offsets: IndexSet) {
        guard let doc = document(docID) else { return }
        let removed = offsets.compactMap { doc.pages.indices.contains($0) ? doc.pages[$0] : nil }
        if removed.count >= doc.pages.count {
            delete([docID])
            return
        }
        mutate(docID) { $0.pages.remove(atOffsets: offsets) }
        for page in removed { removeFiles(docID, page) }
    }

    func movePages(_ docID: UUID, from source: IndexSet, to destination: Int) {
        mutate(docID) { $0.pages.move(fromOffsets: source, toOffset: destination) }
    }

    func rotatePage(_ docID: UUID, pageID: UUID, clockwise: Bool) async {
        await transformPage(docID, pageID: pageID, keepText: false) { original, filter in
            let rotated = ImageProcessing.rotated(original, clockwise: clockwise)
            return (rotated, ImageProcessing.apply(filter, to: rotated))
        }
    }

    func setFilter(_ filter: ScanFilter, docID: UUID, pageID: UUID) async {
        await transformPage(docID, pageID: pageID, keepText: true, newFilter: filter) { original, filter in
            (original, ImageProcessing.apply(filter, to: original))
        }
    }

    func setFilterForAllPages(_ filter: ScanFilter, docID: UUID) async {
        guard let doc = document(docID) else { return }
        for page in doc.pages where page.filter != filter {
            await setFilter(filter, docID: docID, pageID: page.id)
        }
    }

    /// Signe une page : la signature est posée sur l'original et sur la page affichée.
    func sign(_ docID: UUID, pageID: UUID, signature: UIImage, rect: CGRect) async {
        await transformPage(docID, pageID: pageID, keepText: true) { original, filter in
            let signedOriginal = ImageProcessing.stamp(signature, on: original, in: rect)
            return (signedOriginal, ImageProcessing.apply(filter, to: signedOriginal))
        }
    }

    /// Remplace les images d'une page (nouveaux noms de fichiers : le cache reste juste).
    private func transformPage(_ docID: UUID, pageID: UUID, keepText: Bool, newFilter: ScanFilter? = nil,
                               _ work: @escaping @Sendable (UIImage, ScanFilter) -> (UIImage, UIImage)) async {
        guard let doc = document(docID), let page = doc.pages.first(where: { $0.id == pageID }) else { return }
        let filter = newFilter ?? page.filter
        let folder = folder(docID)
        let originalURL = fileURL(docID, page.original)
        busy.insert(docID)
        let result: (String, String)? = await Task.detached(priority: .userInitiated) { () -> (String, String)? in
            guard let original = UIImage(contentsOfFile: originalURL.path) else { return nil }
            let (newOriginal, processed) = work(original, filter)
            let token = UUID().uuidString
            let originalName = "orig-\(token).jpg"
            let fileName = "page-\(token).jpg"
            guard let originalData = ImageProcessing.jpeg(newOriginal, quality: 0.85),
                  let processedData = ImageProcessing.jpeg(processed),
                  (try? originalData.write(to: folder.appendingPathComponent(originalName), options: .atomic)) != nil,
                  (try? processedData.write(to: folder.appendingPathComponent(fileName), options: .atomic)) != nil
            else { return nil }
            return (originalName, fileName)
        }.value
        busy.remove(docID)
        guard let names = result else { return }
        let (originalName, fileName) = names
        mutate(docID) { doc in
            guard let index = doc.pages.firstIndex(where: { $0.id == pageID }) else { return }
            doc.pages[index].original = originalName
            doc.pages[index].file = fileName
            doc.pages[index].filter = filter
            if !keepText {
                doc.pages[index].lines = []
                doc.pages[index].ocrDone = false
            }
        }
        removeFiles(docID, page)
        if !keepText { recognizeText(in: docID) }
    }

    /// Fusionne plusieurs documents (dans l'ordre donné) en un nouveau.
    @discardableResult
    func merge(_ ids: [UUID], name: String) -> UUID? {
        let sources = ids.compactMap { document($0) }
        guard sources.count >= 2 else { return nil }
        var merged = ScanDocument(name: name)
        let target = folder(merged.id)
        try? FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        for source in sources {
            for page in source.pages {
                var copy = page
                copy.id = UUID()
                copy.file = "page-\(copy.id.uuidString).jpg"
                copy.original = "orig-\(copy.id.uuidString).jpg"
                let fm = FileManager.default
                guard (try? fm.copyItem(at: fileURL(source.id, page.file), to: target.appendingPathComponent(copy.file))) != nil,
                      (try? fm.copyItem(at: fileURL(source.id, page.original), to: target.appendingPathComponent(copy.original))) != nil
                else { continue }
                merged.pages.append(copy)
            }
        }
        guard !merged.pages.isEmpty else { return nil }
        documents.append(merged)
        save()
        return merged.id
    }

    /// Copie d'un document.
    @discardableResult
    func duplicate(_ id: UUID) -> UUID? {
        guard let source = document(id) else { return nil }
        var copy = ScanDocument(name: loc("copy_name", source.name))
        let target = folder(copy.id)
        try? FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        for page in source.pages {
            var newPage = page
            newPage.id = UUID()
            newPage.file = "page-\(newPage.id.uuidString).jpg"
            newPage.original = "orig-\(newPage.id.uuidString).jpg"
            try? FileManager.default.copyItem(at: fileURL(id, page.file), to: target.appendingPathComponent(newPage.file))
            try? FileManager.default.copyItem(at: fileURL(id, page.original), to: target.appendingPathComponent(newPage.original))
            copy.pages.append(newPage)
        }
        documents.append(copy)
        save()
        return copy.id
    }

    private func removeFiles(_ docID: UUID, _ page: ScanPage) {
        try? FileManager.default.removeItem(at: fileURL(docID, page.file))
        if page.original != page.file {
            try? FileManager.default.removeItem(at: fileURL(docID, page.original))
        }
    }

    private func mutate(_ docID: UUID, touch: Bool = true, _ change: (inout ScanDocument) -> Void) {
        guard let index = documents.firstIndex(where: { $0.id == docID }) else { return }
        change(&documents[index])
        if touch { documents[index].updatedAt = .now }
        save()
    }

    // MARK: Export

    func exportPages(_ docID: UUID) -> [ExportPage] {
        guard let doc = document(docID) else { return [] }
        return doc.pages.map { ExportPage(imageURL: fileURL(docID, $0.file), lines: $0.lines) }
    }

    // MARK: Signature

    func saveSignature(_ image: UIImage?) {
        signature = image
        if let image, let data = image.pngData() {
            try? data.write(to: signatureURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: signatureURL)
        }
    }

    // MARK: Sauvegarde

    private func load() {
        guard let data = try? Data(contentsOf: libraryURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let list = try? decoder.decode([ScanDocument].self, from: data) {
            documents = list
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(documents) {
            try? data.write(to: libraryURL, options: [.atomic])
        }
    }

    // MARK: Tests

    #if DEBUG
    /// Crée 3 documents d'exemple (utile dans le simulateur, qui n'a pas d'appareil photo).
    func debugAddSamples() async {
        let samples: [(String, [[String]])] = [
            (loc("sample_invoice"), [["FACTURE N° 2026-118", "Atelier Martin – Plomberie", "Remplacement chauffe-eau 200 L", "Main d'œuvre : 3 h", "Total TTC : 1 284,00 €", "À régler avant le 30/11/2026"]]),
            (loc("sample_contract"), [["CONTRAT DE LOCATION", "Entre les soussignés…", "Loyer mensuel : 780 € charges comprises", "Durée : 3 ans"], ["Article 4 – Dépôt de garantie", "Article 5 – Entretien", "Fait à Lyon, le 2 septembre 2026", "Signature du locataire :"]]),
            (loc("sample_receipt"), [["SUPERMARCHÉ DU CENTRE", "Pommes 1,8 kg     3,42", "Pain complet      2,10", "Lait x2           2,38", "TOTAL             7,90 €", "Merci de votre visite"]])
        ]
        for (name, pages) in samples {
            let images = pages.map { Self.sampleImage(lines: $0) }
            await createDocument(from: images, name: name)
        }
    }

    private static func sampleImage(lines: [String]) -> UIImage {
        let size = CGSize(width: 1240, height: 1754)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(white: 0.97, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            var y: CGFloat = 140
            for (index, line) in lines.enumerated() {
                let font = index == 0 ? UIFont.boldSystemFont(ofSize: 64) : UIFont.systemFont(ofSize: 42)
                (line as NSString).draw(at: CGPoint(x: 110, y: y), withAttributes: [.font: font, .foregroundColor: UIColor.black])
                y += index == 0 ? 140 : 90
            }
            UIColor(white: 0.8, alpha: 1).setFill()
            for row in 0..<8 {
                context.fill(CGRect(x: 110, y: y + 60 + CGFloat(row) * 60, width: CGFloat.random(in: 600...1000), height: 14))
            }
        }
    }

    func debugRemoveAll() {
        delete(Set(documents.map(\.id)))
    }
    #endif
}
