import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ScreenContextImageEncoder {
    public static func pngData(
        from pixelBuffer: CVPixelBuffer,
        maxDimension: CGFloat = 1024
    ) -> Data? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return pngData(from: ciImage, maxDimension: maxDimension)
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
    static func pngData(from ciImage: CIImage, maxDimension: CGFloat) -> Data? {
        let scaled = scale(ciImage: ciImage, maxDimension: maxDimension)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }

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
}
