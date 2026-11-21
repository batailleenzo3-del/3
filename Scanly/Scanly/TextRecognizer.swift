//
//  TextRecognizer.swift
//  Reconnaissance du texte (OCR) avec Vision, sur l'iPhone, sans internet.
//

import UIKit
import Vision

nonisolated enum TextRecognizer {

    /// Lignes de texte de l'image, dans l'ordre de lecture.
    static func recognize(_ image: UIImage) -> [TextLine] {
        guard let cgImage = image.cgImage else { return [] }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["fr-FR", "en-US", "es-ES", "de-DE", "it-IT"]
        request.automaticallyDetectsLanguage = true

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        let observations = request.results ?? []
        let lines: [TextLine] = observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let box = observation.boundingBox // origine en bas à gauche
            return TextLine(text: candidate.string,
                            x: Double(box.minX), y: Double(1 - box.maxY),
                            w: Double(box.width), h: Double(box.height))
        }
        // Ordre de lecture : de haut en bas, puis de gauche à droite sur une même ligne.
        return lines.sorted { a, b in
            if abs(a.y - b.y) < min(a.h, b.h) * 0.5 { return a.x < b.x }
            return a.y < b.y
        }
    }
}
