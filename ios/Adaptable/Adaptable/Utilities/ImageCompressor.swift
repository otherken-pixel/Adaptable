import UIKit

/// Downscales and re-encodes photos before upload/base64 so edge functions
/// and Storage stay under size limits (import caps ~4 MB base64).
enum ImageCompressor {
    /// Longest edge after resize. 1600 px is enough for OCR + plate shots.
    static let maxDimension: CGFloat = 1600
    static let jpegQuality: CGFloat = 0.72

    static func jpegData(from image: UIImage, maxDimension: CGFloat = maxDimension, quality: CGFloat = jpegQuality) -> Data? {
        let scaled = scale(image, maxDimension: maxDimension)
        return scaled.jpegData(compressionQuality: quality)
    }

    /// Compress arbitrary image bytes (e.g. from PhotosPicker). Returns JPEG.
    static func jpegData(from data: Data, maxDimension: CGFloat = maxDimension, quality: CGFloat = jpegQuality) -> Data? {
        guard let image = UIImage(data: data) else { return data }
        return jpegData(from: image, maxDimension: maxDimension, quality: quality)
    }

    static func scale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
