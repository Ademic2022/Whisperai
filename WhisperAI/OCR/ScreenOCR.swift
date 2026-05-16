import Vision
import AppKit

enum ScreenOCR {
    static func captureText() async -> String {
        guard let screen = NSScreen.main else { return "" }
        let bounds = screen.frame

        guard let cgImage = CGWindowListCreateImage(
            bounds, .optionOnScreenOnly, kCGNullWindowID, .bestResolution
        ) else { return "" }

        return await withCheckedContinuation { cont in
            let request = VNRecognizeTextRequest { req, _ in
                let texts = (req.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n") ?? ""
                cont.resume(returning: texts)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage)
            try? handler.perform([request])
        }
    }
}
