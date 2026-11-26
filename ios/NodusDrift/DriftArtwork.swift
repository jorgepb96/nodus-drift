// SPDX-License-Identifier: MIT
import UIKit
import ImageIO

/// Static, bounded thumbnails of bundled photographs. Never creates a Metal view.
@MainActor final class DriftArtwork {
    private let cache = NSCache<NSString, UIImage>()
    private var pending: [String: Task<UIImage?, Never>] = [:]

    init() { cache.totalCostLimit = 12 * 1024 * 1024; cache.countLimit = 48 }

    func cached(_ landscape: StudioLandscape, pixels: Int = 512) -> UIImage? {
        cache.object(forKey: "\(landscape.rawValue)-\(pixels)" as NSString)
    }

    func cover(_ landscape: StudioLandscape, pixels: Int = 512) async -> UIImage? {
        let pixels = min(768, max(64, pixels))
        if let image = cached(landscape, pixels: pixels) { return image }
        let key = "\(landscape.rawValue)-\(pixels)"
        if let task = pending[key] { return await task.value }
        let url = StudioLandscapePlate(landscape: landscape, wide: true).photographURL
        let task = Task.detached(priority: .utility) { Self.render(url: url, pixels: pixels) }
        pending[key] = task
        let image = await task.value
        pending[key] = nil
        if let image { cache.setObject(image, forKey: key as NSString, cost: pixels * pixels * 4) }
        return image
    }

    nonisolated private static func render(url: URL?, pixels: Int) -> UIImage? {
        guard let url, let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: min(1536, pixels * 2),
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let side = CGFloat(pixels)
        let scale = max(side / CGFloat(cg.width), side / CGFloat(cg.height))
        let size = CGSize(width: CGFloat(cg.width) * scale, height: CGFloat(cg.height) * scale)
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            UIImage(cgImage: cg).draw(in: CGRect(x: (side - size.width) / 2, y: (side - size.height) / 2,
                                               width: size.width, height: size.height))
        }
    }
}
