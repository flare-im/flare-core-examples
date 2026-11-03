import FlareIMUI
import Foundation
import UniformTypeIdentifiers
#if canImport(UIKit)
import PhotosUI
import UIKit
#endif

// Layer 5 — this host's half of the platform contract (spec/platform-contract.json).
// The kit's composer reads `capabilities` and calls the adapter; nothing in the
// kit knows it is running on iOS. The pickers are presented from UIKit rather
// than through `.photosPicker` / `.fileImporter` view state so that "picked" and
// "dismissed" arrive as one delegate callback each — a SwiftUI presentation
// binding cannot tell the two apart without racing the selection change.

/// True where the native pickers can actually be presented. False in the macOS
/// test build of this package, which is why `capabilities` is computed and not a
/// constant: this host never declares an operation it cannot perform.
let iosPickersAvailable: Bool = {
    #if canImport(UIKit)
    return true
    #else
    return false
    #endif
}()

/// What an iPhone / iPad determines on its own, plus the two pickers this host
/// performs. Without them the image entry still works — the composer falls back
/// to its own input form — while the file entry has no substitute and goes away.
func iosHostCapabilities(
    width: CGFloat,
    hasPointer: Bool = false,
    pickersAvailable: Bool = iosPickersAvailable
) -> FlarePlatformCapabilities {
    var capabilities = FlarePlatformCapabilities.ios(width: width, hasPointer: hasPointer)
    capabilities.filePicker = pickersAvailable ? .supported : .unsupported
    capabilities.imagePicker = pickersAvailable ? .supported : .fallback
    return capabilities
}

/// The contract's `accept` list as iOS content types: wildcards map to the type
/// tree, `.ext` and concrete MIME types to that single type, an empty list to
/// "any item the Files app can hand over".
func iosContentTypes(for accept: [String]) -> [UTType] {
    var types: [UTType] = []
    for entry in accept.map({ $0.trimmingCharacters(in: .whitespaces).lowercased() }) where !entry.isEmpty {
        let resolved: UTType?
        switch entry {
        case "image/*": resolved = .image
        case "video/*": resolved = .movie
        case "audio/*": resolved = .audio
        case "text/*": resolved = .text
        default:
            if entry.hasPrefix(".") {
                resolved = UTType(filenameExtension: String(entry.dropFirst()))
            } else if entry.contains("/") {
                resolved = UTType(mimeType: entry)
            } else {
                resolved = UTType(filenameExtension: entry)
            }
        }
        if let resolved, !types.contains(resolved) { types.append(resolved) }
    }
    return types.isEmpty ? [.item] : types
}

/// The iOS host adapter. `width` comes from the root view, so the sheet-first
/// form factor follows a split-view resize on iPad.
struct IosPlatformAdapter: FlarePlatformAdapter {
    var width: CGFloat = .infinity
    var hasPointer: Bool = false

    var capabilities: FlarePlatformCapabilities {
        iosHostCapabilities(width: width, hasPointer: hasPointer)
    }

    func pickImages(_ options: FlarePickImagesOptions) async -> FlarePlatformResult<[FlarePickedFile]> {
        await callFlarePlatform { await IosNativePickers.pickImages(options) }
    }

    func pickFiles(_ options: FlarePickFilesOptions) async -> FlarePlatformResult<[FlarePickedFile]> {
        await callFlarePlatform { await IosNativePickers.pickFiles(options) }
    }

    func safeAreaInsets() -> FlareSafeAreaInsets {
        #if canImport(UIKit)
        guard let insets = MainActor.assumeIsolated({ IosNativePickers.keyWindow()?.safeAreaInsets }) else {
            return FlareSafeAreaInsets()
        }
        return FlareSafeAreaInsets(top: insets.top, right: insets.right, bottom: insets.bottom, left: insets.left)
        #else
        return FlareSafeAreaInsets()
        #endif
    }
}

enum IosNativePickers {
    /// Contract rule: a dismissed picker and an empty selection are both CANCELLED.
    static let dismissed = FlarePlatformResult<[FlarePickedFile]>.failure(
        FlarePlatformError(.cancelled, message: "picker dismissed")
    )

    #if canImport(UIKit)
    @MainActor
    static func keyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
    }

    @MainActor
    private static func presenter() -> UIViewController? {
        var top = keyWindow()?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    @MainActor
    static func pickImages(_ options: FlarePickImagesOptions) async -> FlarePlatformResult<[FlarePickedFile]> {
        guard let host = presenter() else {
            return .failure(FlarePlatformError(.failed, message: "no window to present the photo picker"))
        }
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = options.video ? .any(of: [.images, .videos]) : .images
        configuration.selectionLimit = options.multiple ? 0 : 1
        configuration.preferredAssetRepresentationMode = .current
        let controller = PHPickerViewController(configuration: configuration)

        let results: [PHPickerResult] = await withCheckedContinuation { continuation in
            let delegate = PhotoPickerDelegate { picked in continuation.resume(returning: picked) }
            controller.delegate = delegate
            retain(delegate, until: controller)
            host.present(controller, animated: true)
        }
        guard !results.isEmpty else { return dismissed }
        var files: [FlarePickedFile] = []
        for result in results {
            if let file = await materialize(result.itemProvider, idPrefix: "local-media") { files.append(file) }
        }
        return files.isEmpty ? dismissed : .success(files)
    }

    @MainActor
    static func pickFiles(_ options: FlarePickFilesOptions) async -> FlarePlatformResult<[FlarePickedFile]> {
        guard let host = presenter() else {
            return .failure(FlarePlatformError(.failed, message: "no window to present the document picker"))
        }
        // `asCopy` hands over an app-owned copy, so no security-scoped access is
        // needed and the file outlives the picker.
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: iosContentTypes(for: options.accept), asCopy: true)
        controller.allowsMultipleSelection = options.multiple

        let urls: [URL] = await withCheckedContinuation { continuation in
            let delegate = DocumentPickerDelegate { picked in continuation.resume(returning: picked) }
            controller.delegate = delegate
            retain(delegate, until: controller)
            host.present(controller, animated: true)
        }
        guard !urls.isEmpty else { return dismissed }
        let files = urls.compactMap { url -> FlarePickedFile? in
            let id = "local-file-\(UUID().uuidString)"
            guard let cached = try? copyFileToComposerCache(sourceURL: url, id: id, preferredExtension: url.pathExtension) else { return nil }
            return describe(cached, name: url.lastPathComponent)
        }
        return files.isEmpty ? dismissed : .success(files)
    }

    /// Copies the provider's file into the composer cache — the returned URL of a
    /// `loadFileRepresentation` callback is only valid inside that callback.
    private static func materialize(_ provider: NSItemProvider, idPrefix: String) async -> FlarePickedFile? {
        let identifiers = provider.registeredTypeIdentifiers
        let typeIdentifier = identifiers.first { UTType($0)?.conforms(to: .movie) == true }
            ?? identifiers.first { UTType($0)?.conforms(to: .image) == true }
            ?? identifiers.first
        guard let typeIdentifier else { return nil }
        let suggestedName = provider.suggestedName
        return await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, _ in
                guard let url else { continuation.resume(returning: nil); return }
                let id = "\(idPrefix)-\(UUID().uuidString)"
                let cached = try? copyFileToComposerCache(sourceURL: url, id: id, preferredExtension: url.pathExtension)
                guard let cached else { continuation.resume(returning: nil); return }
                continuation.resume(returning: describe(cached, name: suggestedName ?? url.lastPathComponent))
            }
        }
    }

    private static func describe(_ url: URL, name: String) -> FlarePickedFile {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
        return FlarePickedFile(
            name: name.isEmpty ? url.lastPathComponent : name,
            size: values?.fileSize,
            mimeType: values?.contentType?.preferredMIMEType,
            path: url.path,
            uri: url.absoluteString
        )
    }

    /// Keeps the delegate alive for the lifetime of its controller (UIKit holds
    /// delegates weakly) and lets it go as soon as the picker is deallocated.
    private static func retain(_ delegate: AnyObject, until controller: UIViewController) {
        objc_setAssociatedObject(controller, &delegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    #else
    @MainActor
    static func pickImages(_ options: FlarePickImagesOptions) async -> FlarePlatformResult<[FlarePickedFile]> {
        .unsupported("pickImages")
    }

    @MainActor
    static func pickFiles(_ options: FlarePickFilesOptions) async -> FlarePlatformResult<[FlarePickedFile]> {
        .unsupported("pickFiles")
    }
    #endif
}

#if canImport(UIKit)
private nonisolated(unsafe) var delegateKey: UInt8 = 0

/// One callback, whether the user picked or dismissed — `results` is empty on dismiss.
private final class PhotoPickerDelegate: NSObject, PHPickerViewControllerDelegate {
    private var finish: (([PHPickerResult]) -> Void)?

    init(finish: @escaping ([PHPickerResult]) -> Void) { self.finish = finish }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        let callback = finish
        finish = nil
        callback?(results)
    }
}

/// UIKit calls exactly one of these two; both settle the awaiting adapter call.
private final class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    private var finish: (([URL]) -> Void)?

    init(finish: @escaping ([URL]) -> Void) { self.finish = finish }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        settle(urls)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        settle([])
    }

    private func settle(_ urls: [URL]) {
        let callback = finish
        finish = nil
        callback?(urls)
    }
}
#endif
