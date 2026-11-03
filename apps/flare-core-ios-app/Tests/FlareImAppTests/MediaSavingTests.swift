import FlareCoreAppleSDK
import FlareIMUI
import Foundation
import XCTest
@testable import FlareImApp

/// Save to device, the download location and the picture cache (MediaSaving.swift), plus the settings view
/// model and session wiring around them. Under `swift test` the String Catalog lives in the runner bundle, so
/// localized lookups read the English source keys.
final class MediaSavingTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!
    /// 2026-09-27 08:05:09 UTC.
    private let moment = Date(timeIntervalSince1970: 1_790_496_309)

    // MARK: Save target

    func testPictureIsSavedByItsStoredIdAsIMG() {
        let image = MessageContent(contentType: .image, data: [
            "source": AnySendable(["imageId": AnySendable("img-1"), "url": AnySendable("https://cdn.example.com/a")])
        ])
        let target = MediaSaveTarget.of(image, now: moment, timeZone: utc)
        XCTAssertEqual(target, MediaSaveTarget(fileId: "img-1", sourceUrl: nil, fileName: "IMG_20260927_080509"))
        XCTAssertEqual(target?.request["fileId"]?.value as? String, "img-1")
        XCTAssertEqual(target?.request["fileName"]?.value as? String, "IMG_20260927_080509")
        XCTAssertNil(target?.request["sourceUrl"])
    }

    func testVideoIsSavedAsVIDAndVoiceAsAUD() {
        let video = MessageContent(contentType: .video, data: ["videoId": AnySendable("v-1")])
        XCTAssertEqual(MediaSaveTarget.of(video, now: moment, timeZone: utc)?.fileName, "VID_20260927_080509")
        let voice = MessageContent(contentType: .audio, data: ["audioId": AnySendable("a-1")])
        XCTAssertEqual(MediaSaveTarget.of(voice, now: moment, timeZone: utc),
                       MediaSaveTarget(fileId: "a-1", sourceUrl: nil, fileName: "AUD_20260927_080509"))
    }

    func testFileKeepsTheSendersNameWithoutFolders() {
        let file = MessageContent(contentType: .file, data: [
            "fileId": AnySendable("f-1"), "name": AnySendable("docs/产品方案.pdf")
        ])
        XCTAssertEqual(MediaSaveTarget.of(file, now: moment, timeZone: utc),
                       MediaSaveTarget(fileId: "f-1", sourceUrl: nil, fileName: "产品方案.pdf"))
    }

    func testWithoutAStoredFileOnlyAWebAddressIsSaved() {
        let web = MessageContent(contentType: .image, data: ["url": AnySendable("https://example.com/p.png")])
        XCTAssertEqual(MediaSaveTarget.of(web, now: moment, timeZone: utc),
                       MediaSaveTarget(fileId: nil, sourceUrl: "https://example.com/p.png", fileName: "IMG_20260927_080509"))
        let local = MessageContent(contentType: .file, data: ["url": AnySendable("file:///etc/hosts"), "name": AnySendable("hosts")])
        XCTAssertNil(MediaSaveTarget.of(local))
        XCTAssertNil(MediaSaveTarget.of(MessageContent(contentType: .text, data: ["text": AnySendable("hi")])))
        XCTAssertNil(MediaSaveTarget.of(nil))
    }

    // MARK: Outcome and copy

    func testOutcomeReadsTheCoreAnswer() {
        let saved = MediaSaveOutcome.from([
            "path": AnySendable("/d/Documents/flare/IMG_1.jpg"), "directory": AnySendable("/d/Documents/flare"),
            "fileName": AnySendable("IMG_1.jpg"), "fromCache": AnySendable(true),
        ])
        XCTAssertEqual(saved, .saved(directory: "/d/Documents/flare", path: "/d/Documents/flare/IMG_1.jpg"))
        XCTAssertEqual(MediaSaveOutcome.from([:]), .failed(MediaSaveCopy.failed))
        XCTAssertEqual(MediaSaveOutcome.failure(AppStoreError(message: "directory is not writable")), .failed(MediaSaveCopy.unwritable))
        XCTAssertEqual(MediaSaveOutcome.failure(AppStoreError(message: "timeout")), .failed(MediaSaveCopy.failed))
    }

    func testDownloadLocationIsNamedAsTheFilesAppPath() {
        let documents = "/var/mobile/Containers/Data/Application/ABC/Documents"
        XCTAssertEqual(DownloadLocationLabel.label(directory: "/private" + documents + "/flare/", documents: documents),
                       "Files app › this app › flare")
        XCTAssertEqual(DownloadLocationLabel.label(directory: "/Users/me/Downloads/flare", documents: documents), "…/Downloads/flare")
    }

    // MARK: Settings

    func testDownloadLocationStateReadsTheCoreAnswer() {
        let state = DownloadLocationState([
            "directory": AnySendable("/d/Documents/flare"), "defaultDirectory": AnySendable("/d/Documents/flare"),
            "isCustom": AnySendable(false), "subfolder": AnySendable("flare"),
        ])
        XCTAssertEqual(state, DownloadLocationState(directory: "/d/Documents/flare", isCustom: false))
        XCTAssertNil(DownloadLocationState(["directory": AnySendable("  ")]))
    }

    func testCacheUsageReadsTheSnakeCaseWire() {
        let usage = MediaCacheUsage([
            "effective_root": AnySendable("/d/media-cache"), "max_bytes": AnySendable(Int64(268_435_456)),
            "max_bytes_is_default": AnySendable(false), "total_bytes": AnySendable(Int64(5_242_880)),
            "entry_count": AnySendable(Int64(3)),
        ])
        XCTAssertEqual(usage, MediaCacheUsage(totalBytes: 5_242_880, entryCount: 3, maxBytes: 268_435_456))
        XCTAssertEqual(usage?.summary, "5.0 MB / 256.0 MB · 3 files")
        // The keys this page used to read never came back from the core, so the usage always said "—".
        XCTAssertNil(MediaCacheUsage(["usedBytes": AnySendable(Int64(1))]))
    }

    @MainActor
    func testSettingsWithoutAClientReportNothingDoneAndStayQuiet() async {
        let session = AppSession()
        let repository = ViewDataRepository()
        let environment = AppEnvironment(session: session)
        let messaging = MessagingViewModel(session: session, repository: repository, environment: environment)
        let lab = SdkLabViewModel(session: session, repository: repository, environment: environment, messaging: messaging)
        let settings = SettingsViewModel(session: session, environment: environment, sdkLab: lab)
        settings.bind(messaging: messaging)

        await settings.refreshCacheStats()
        await settings.refreshDownloadLocation()
        XCTAssertNil(settings.cacheStats)
        XCTAssertNil(settings.downloadLocation)
        let cleared = await settings.clearCache()
        let reset = await settings.resetDownloadLocation()
        XCTAssertFalse(cleared)
        XCTAssertFalse(reset)
    }

    @MainActor
    func testSaveWithoutAStoredFileSaysSo() async {
        let session = AppSession()
        let environment = AppEnvironment(session: session)
        let messaging = MessagingViewModel(session: session, repository: ViewDataRepository(), environment: environment)
        let text = SdkModelMapper.messageFromCore(Message(
            clientMsgId: "c1", content: MessageContent(contentType: .text, data: ["text": AnySendable("hi")]),
            conversationId: "c", senderId: "a"))
        let outcome = await messaging.saveToDevice(text)
        XCTAssertEqual(outcome, .failed(MediaSaveCopy.nothingToSave))
        XCTAssertEqual(environment.labResults.first?.operation, "media.download_to_user_directory")
    }

    func testCacheRootIsSentUnderTheContractKey() {
        let request = AppSession.mediaCacheRootRequest(dataURL: URL(fileURLWithPath: "/d/data"))
        XCTAssertEqual(request["absolutePath"]?.value as? String, "/d/data/media-cache")
        XCTAssertNil(request["root"])
    }

    // MARK: Picture cache

    func testLocalCopiesAreAskedForUntilTheCacheHasThem() {
        var copies = LocalPictureCopies()
        let t0 = Date(timeIntervalSince1970: 0)
        let onDisk: (String) -> Bool = { _ in true }
        XCTAssertTrue(copies.shouldAsk("a", now: t0, exists: onDisk))
        copies.record("a", localPath: "/cache/a", now: t0)
        copies.record("b", localPath: nil, now: t0)
        XCTAssertEqual(copies.path("a", exists: onDisk), "/cache/a")
        XCTAssertFalse(copies.shouldAsk("a", now: t0, exists: onDisk))
        XCTAssertFalse(copies.shouldAsk("b", now: t0.addingTimeInterval(1), exists: onDisk))
        XCTAssertTrue(copies.shouldAsk("b", now: t0.addingTimeInterval(LocalPictureCopies.retryAfter), exists: onDisk))
        XCTAssertTrue(copies.shouldAsk("a", now: t0, exists: { _ in false }))
        copies.reset()
        XCTAssertNil(copies.path("a", exists: onDisk))
    }

    func testPictureAccessReadsLocalPathOrRemoteURL() {
        XCTAssertEqual(PictureAccess(["source": AnySendable("local"), "localPath": AnySendable("/cache/image/ab/cd")]),
                       PictureAccess(localPath: "/cache/image/ab/cd", url: nil))
        XCTAssertEqual(PictureAccess(["source": AnySendable("remote"),
                                      "remote": AnySendable(["url": AnySendable("https://x/signed"), "cdnUrl": AnySendable("")])]),
                       PictureAccess(localPath: nil, url: "https://x/signed"))
    }
}
