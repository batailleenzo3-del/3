//
//  DocumentScanner.swift
//  Le scanner d'Apple (VisionKit) : détection automatique des bords, redressement,
//  plusieurs pages d'affilée. Tout se passe sur l'iPhone.
//

import SwiftUI
import VisionKit

struct DocumentScanner: UIViewControllerRepresentable {
    /// Appelé avec les pages scannées (vide si l'utilisateur annule).
    let onFinish: ([UIImage]) -> Void

    static var isAvailable: Bool { VNDocumentCameraViewController.isSupported }

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onFinish: ([UIImage]) -> Void

        init(onFinish: @escaping ([UIImage]) -> Void) {
            self.onFinish = onFinish
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            onFinish(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onFinish([])
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            onFinish([])
        }
    }
}

// MARK: - Partage (feuille iOS : Mail, Messages, AirDrop, Fichiers, Imprimer…)

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    var onComplete: (Bool) -> Void = { _ in }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in onComplete(completed) }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Fichiers prêts à partager (pour `.sheet(item:)`).
struct ShareItem: Identifiable {
    let id = UUID()
    let urls: [URL]
}
