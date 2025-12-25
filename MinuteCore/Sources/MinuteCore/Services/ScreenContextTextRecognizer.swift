import CoreGraphics
import CoreVideo
import Foundation
import Vision

public final class ScreenContextTextRecognizer: @unchecked Sendable {
    private let recognitionLanguages: [String]

    public init(recognitionLanguages: [String]? = nil) {
        if let recognitionLanguages, !recognitionLanguages.isEmpty {
            self.recognitionLanguages = recognitionLanguages
        } else {
            self.recognitionLanguages = Array(Locale.preferredLanguages.prefix(3))
        }
    }

    public func recognizeText(from pixelBuffer: CVPixelBuffer) throws -> [String] {
        let request = Self.makeRequest(recognitionLanguages: recognitionLanguages)
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try handler.perform([request])
        return Self.extractLines(from: request)
    }

    public func recognizeText(from image: CGImage) throws -> [String] {
        let request = Self.makeRequest(recognitionLanguages: recognitionLanguages)
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        return Self.extractLines(from: request)
    }

    private static func makeRequest(recognitionLanguages: [String]) -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = recognitionLanguages
        request.minimumTextHeight = 0.02
        return request
    }

    private static func extractLines(from request: VNRecognizeTextRequest) -> [String] {
        let observations = request.results ?? []
        return observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }
    }
}
