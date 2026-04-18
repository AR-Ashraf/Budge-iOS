import UIKit

enum ProfilePhotoProcessing {
    /// Downscales large images and re-encodes as JPEG for Storage upload.
    static func jpegForUpload(image: UIImage, maxDimension: CGFloat = 1024, quality: CGFloat = 0.82) -> Data? {
        let resized = resize(image, maxDimension: maxDimension)
        return resized.jpegData(compressionQuality: quality)
    }

    /// Downscales large images and re-encodes as JPEG for Storage upload.
    static func jpegForUpload(data: Data, maxDimension: CGFloat = 1024, quality: CGFloat = 0.82) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return jpegForUpload(image: image, maxDimension: maxDimension, quality: quality)
    }

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }
        let ratio = maxDimension / maxSide
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
