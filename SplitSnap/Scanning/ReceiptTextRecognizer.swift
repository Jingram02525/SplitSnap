import UIKit
import Vision

/// Runs Vision text recognition on receipt images and hands the text to `ReceiptParser`.
enum ReceiptTextRecognizer {
    enum RecognitionError: LocalizedError {
        case unreadableImage
        case noTextFound

        var errorDescription: String? {
            switch self {
            case .unreadableImage: "That image couldn't be opened."
            case .noTextFound: "No text was found. Try again with the whole receipt in frame and good lighting."
            }
        }
    }

    /// Recognizes every page (long receipts can be scanned in several shots)
    /// and parses them as one continuous receipt.
    static func parseReceipt(from images: [UIImage]) async throws -> ParsedReceipt {
        var lines: [String] = []
        for image in images {
            let fragments = try await recognizeText(in: image)
            lines += ReceiptParser.groupIntoLines(fragments)
        }
        guard !lines.isEmpty else { throw RecognitionError.noTextFound }
        return ReceiptParser.parse(lines: lines)
    }

    static func recognizeText(in image: UIImage) async throws -> [ReceiptParser.TextFragment] {
        guard let cgImage = image.uprightCGImage() else { throw RecognitionError.unreadableImage }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                // Language correction "fixes" prices and menu abbreviations, so leave it off.
                request.usesLanguageCorrection = false

                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
                do {
                    try handler.perform([request])
                    let fragments = (request.results ?? []).compactMap { observation -> ReceiptParser.TextFragment? in
                        guard let text = observation.topCandidates(1).first?.string else { return nil }
                        let box = observation.boundingBox
                        return ReceiptParser.TextFragment(
                            text: text,
                            minX: Double(box.minX),
                            midY: Double(box.midY),
                            height: Double(box.height)
                        )
                    }
                    continuation.resume(returning: fragments)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private extension UIImage {
    /// Photos from the library can carry an EXIF rotation; redraw so Vision
    /// always sees the receipt upright.
    func uprightCGImage() -> CGImage? {
        if imageOrientation == .up, let cgImage { return cgImage }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format)
            .image { _ in draw(in: CGRect(origin: .zero, size: size)) }
            .cgImage
    }
}
