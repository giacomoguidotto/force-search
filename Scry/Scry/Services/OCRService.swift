import CoreGraphics
import NaturalLanguage
import Vision

struct OCRResult {
    let fullText: String
    let lineNearestCenter: String?
}

final class OCRService {
    private let debugLog = DebugLogStore.shared

    /// Performs on-device OCR on the given image and returns recognized text.
    func recognizeText(in image: CGImage) async -> OCRResult? {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    DebugLogStore.shared.log("OCR", "Recognition error: \(error.localizedDescription)", level: .error)
                    continuation.resume(returning: nil)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation],
                      !observations.isEmpty else {
                    DebugLogStore.shared.log("OCR", "No text recognized", level: .debug)
                    continuation.resume(returning: nil)
                    return
                }

                let fullText = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ")

                let centerLine = Self.findLineNearestCenter(observations: observations)

                DebugLogStore.shared.log("OCR", "Recognized \(observations.count) lines, center line: \(centerLine ?? "none")", level: .debug)
                continuation.resume(returning: OCRResult(fullText: fullText, lineNearestCenter: centerLine))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                debugLog.log("OCR", "Handler error: \(error.localizedDescription)", level: .error)
                continuation.resume(returning: nil)
            }
        }
    }

    /// Finds the text line whose bounding box is nearest to the center of the image.
    static func findLineNearestCenter(observations: [VNRecognizedTextObservation]) -> String? {
        let imageCenter = CGPoint(x: 0.5, y: 0.5)
        var bestLine: String?
        var bestDistance: CGFloat = .greatestFiniteMagnitude

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }

            let box = observation.boundingBox
            let center = CGPoint(
                x: box.origin.x + box.width / 2,
                y: box.origin.y + box.height / 2
            )

            let dx = center.x - imageCenter.x
            let dy = center.y - imageCenter.y
            let distance = dx * dx + dy * dy

            if distance < bestDistance {
                bestDistance = distance
                bestLine = candidate.string
            }
        }

        return bestLine
    }
}
