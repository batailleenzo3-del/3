//
//  ImageProcessing.swift
//  Traitement des images, entièrement sur l'iPhone : redimensionnement, filtres
//  (amélioration automatique, couleur, gris, noir & blanc), rotation, signature.
//

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

nonisolated enum ImageProcessing {
    nonisolated(unsafe) private static let context = CIContext(options: [.useSoftwareRenderer: false])

    /// Redessine l'image à l'endroit (orientation .up) et à une taille raisonnable.
    static func normalized(_ image: UIImage, maxDimension: CGFloat = AppConfig.maxPageDimension) -> UIImage {
        // Taille en pixels (une capture peut avoir une échelle 2× ou 3×).
        let size = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longest = max(size.width, size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        if scale == 1 && image.imageOrientation == .up && image.scale == 1 { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// Applique un filtre de scan.
    static func apply(_ filter: ScanFilter, to image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let input = CIImage(cgImage: cgImage)
        let output: CIImage?

        switch filter {
        case .color:
            let controls = CIFilter.colorControls()
            controls.inputImage = input
            controls.saturation = 1.08
            controls.contrast = 1.06
            controls.brightness = 0.01
            output = controls.outputImage
        case .auto:
            let enhancer = CIFilter.documentEnhancer()
            enhancer.inputImage = input
            enhancer.amount = 1
            output = enhancer.outputImage
        case .gray:
            let controls = CIFilter.colorControls()
            controls.inputImage = input
            controls.saturation = 0
            controls.contrast = 1.15
            controls.brightness = 0.03
            output = controls.outputImage
        case .blackWhite:
            let enhancer = CIFilter.documentEnhancer()
            enhancer.inputImage = input
            enhancer.amount = 1.2
            let controls = CIFilter.colorControls()
            controls.inputImage = enhancer.outputImage ?? input
            controls.saturation = 0
            controls.contrast = 1.9
            controls.brightness = 0.06
            output = controls.outputImage
        }

        guard let output,
              let result = context.createCGImage(output, from: input.extent) else { return image }
        return UIImage(cgImage: result)
    }

    /// Tourne l'image d'un quart de tour.
    static func rotated(_ image: UIImage, clockwise: Bool) -> UIImage {
        let size = CGSize(width: image.size.height, height: image.size.width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            cg.translateBy(x: size.width / 2, y: size.height / 2)
            cg.rotate(by: clockwise ? .pi / 2 : -.pi / 2)
            image.draw(in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2,
                                  width: image.size.width, height: image.size.height))
        }
    }

    /// Pose la signature sur la page. `rect` est en proportion de la page (0…1).
    static func stamp(_ signature: UIImage, on image: UIImage, in rect: CGRect) -> UIImage {
        let size = image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
            signature.draw(in: CGRect(x: rect.minX * size.width, y: rect.minY * size.height,
                                      width: rect.width * size.width, height: rect.height * size.height))
        }
    }

    /// Petite image pour la bibliothèque.
    static func thumbnail(_ image: UIImage, maxDimension: CGFloat = 420) -> UIImage {
        normalized(image, maxDimension: maxDimension)
    }

    static func jpeg(_ image: UIImage, quality: CGFloat = 0.82) -> Data? {
        image.jpegData(compressionQuality: quality)
    }
}
