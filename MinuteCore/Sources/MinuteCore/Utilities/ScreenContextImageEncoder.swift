import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers
import VideoToolbox

public enum ScreenContextImageEncoder {
    public static func pngData(
        from pixelBuffer: CVPixelBuffer,
        maxDimension: CGFloat = 1024
    ) -> Data? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        if let data = pngData(from: ciImage, maxDimension: maxDimension) {
            return data
        }

        var cgImage: CGImage?
        let status = VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        guard status == noErr, let cgImage else { return nil }

        if let data = pngData(from: CIImage(cgImage: cgImage), maxDimension: maxDimension) {
            return data
        }

        return pngData(from: cgImage)
    }

    public static func pngData(
        from image: CGImage,
        maxDimension: CGFloat = 1024
    ) -> Data? {
        let ciImage = CIImage(cgImage: image)
        return pngData(from: ciImage, maxDimension: maxDimension)
    }
}

private extension ScreenContextImageEncoder {
    static let sharedContext = CIContext(options: nil)

    static func pngData(from ciImage: CIImage, maxDimension: CGFloat) -> Data? {
        let scaled = scale(ciImage: ciImage, maxDimension: maxDimension)
        guard let cgImage = sharedContext.createCGImage(scaled, from: scaled.extent) else { return nil }
        return pngData(from: cgImage)
    }

    static func scale(ciImage: CIImage, maxDimension: CGFloat) -> CIImage {
        let extent = ciImage.extent
        let width = extent.width
        let height = extent.height
        let maxSide = max(width, height)
        guard maxSide > maxDimension, maxSide > 0 else { return ciImage }

        let scale = maxDimension / maxSide
        guard let filter = CIFilter(name: "CILanczosScaleTransform") else { return ciImage }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(scale, forKey: kCIInputScaleKey)
        filter.setValue(1.0, forKey: kCIInputAspectRatioKey)
        return filter.outputImage ?? ciImage
    }

    static func pngData(from cgImage: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
