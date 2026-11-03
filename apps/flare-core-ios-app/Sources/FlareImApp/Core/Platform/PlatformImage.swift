import ImageIO
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// The single place that bridges UIKit/AppKit image APIs. Views stay pure SwiftUI
// and call these helpers instead of branching on the platform themselves.

extension Image {
    /// Loads a SwiftUI `Image` from a local file URL, bridging `UIImage`/`NSImage`.
    /// Returns `nil` when the file can't be decoded (or on platforms with no image backend).
    init?(localFileURL url: URL) {
        #if canImport(UIKit)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        self.init(uiImage: image)
        #elseif canImport(AppKit)
        guard let image = NSImage(contentsOf: url) else { return nil }
        self.init(nsImage: image)
        #else
        return nil
        #endif
    }
}

/// Pixel dimensions of an encoded image, bridging `UIImage`/`NSImage`. `nil` if undecodable.
func platformImageSize(data: Data) -> (width: Int, height: Int)? {
    #if canImport(UIKit)
    guard let image = UIImage(data: data) else { return nil }
    return (
        width: Int(image.size.width * image.scale),
        height: Int(image.size.height * image.scale)
    )
    #elseif canImport(AppKit)
    guard let image = NSImage(data: data) else { return nil }
    if let rep = image.representations.first {
        return (width: rep.pixelsWide, height: rep.pixelsHigh)
    }
    return (width: Int(image.size.width), height: Int(image.size.height))
    #else
    return nil
    #endif
}

struct PlatformAnimatedImageView: View {
    let url: URL
    let fallbackSystemImage: String
    let accessibilityLabel: String

    var body: some View {
        #if canImport(UIKit)
        UIKitAnimatedImageView(
            url: url,
            fallbackSystemImage: fallbackSystemImage,
            accessibilityLabel: accessibilityLabel
        )
        #elseif canImport(AppKit)
        AppKitAnimatedImageView(
            url: url,
            fallbackSystemImage: fallbackSystemImage,
            accessibilityLabel: accessibilityLabel
        )
        #else
        Image(systemName: fallbackSystemImage)
            .accessibilityLabel(accessibilityLabel)
        #endif
    }
}

#if canImport(UIKit)
private final class AspectFitAnimatedUIImageView: UIImageView {
    override var intrinsicContentSize: CGSize {
        .zero
    }
}

private struct UIKitAnimatedImageView: UIViewRepresentable {
    let url: URL
    let fallbackSystemImage: String
    let accessibilityLabel: String

    func makeUIView(context: Context) -> UIImageView {
        let view = AspectFitAnimatedUIImageView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        view.accessibilityLabel = accessibilityLabel
        view.image = animatedUIImage(from: url) ?? UIImage(systemName: fallbackSystemImage)
        if view.image?.images?.isEmpty == false {
            view.startAnimating()
        }
    }
}

private func animatedUIImage(from url: URL) -> UIImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
        return UIImage(contentsOfFile: url.path)
    }
    let frameCount = CGImageSourceGetCount(source)
    guard frameCount > 1 else {
        return UIImage(contentsOfFile: url.path)
    }

    var frames: [UIImage] = []
    var duration: TimeInterval = 0
    for index in 0..<frameCount {
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
        frames.append(UIImage(cgImage: cgImage))
        duration += imageFrameDuration(source: source, index: index)
    }
    guard !frames.isEmpty else {
        return UIImage(contentsOfFile: url.path)
    }
    return UIImage.animatedImage(with: frames, duration: max(duration, 0.08 * Double(frames.count)))
}
#elseif canImport(AppKit)
private struct AppKitAnimatedImageView: NSViewRepresentable {
    let url: URL
    let fallbackSystemImage: String
    let accessibilityLabel: String

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        return view
    }

    func updateNSView(_ view: NSImageView, context: Context) {
        view.setAccessibilityLabel(accessibilityLabel)
        view.image = NSImage(contentsOf: url) ?? NSImage(systemSymbolName: fallbackSystemImage, accessibilityDescription: accessibilityLabel)
        view.animates = true
    }
}
#endif

private func imageFrameDuration(source: CGImageSource, index: Int) -> TimeInterval {
    let fallback = 0.08
    guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] else {
        return fallback
    }
    let dictionaries: [(CFString, CFString, CFString)] = [
        (kCGImagePropertyWebPDictionary, kCGImagePropertyWebPUnclampedDelayTime, kCGImagePropertyWebPDelayTime),
        (kCGImagePropertyGIFDictionary, kCGImagePropertyGIFUnclampedDelayTime, kCGImagePropertyGIFDelayTime)
    ]
    for (dictionaryKey, unclampedKey, clampedKey) in dictionaries {
        guard let dictionary = properties[dictionaryKey] as? [CFString: Any] else { continue }
        if let duration = dictionary[unclampedKey] as? TimeInterval, duration > 0 {
            return max(duration, 0.02)
        }
        if let duration = dictionary[clampedKey] as? TimeInterval, duration > 0 {
            return max(duration, 0.02)
        }
    }
    return fallback
}
