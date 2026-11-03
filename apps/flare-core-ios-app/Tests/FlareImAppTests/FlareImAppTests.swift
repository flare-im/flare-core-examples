import FlareCoreAppleSDK
import FlareIMUI
import Foundation
import XCTest
@testable import FlareImApp

final class FlareImAppTests: XCTestCase {
    func testConversationFilterTitlesAreStable() {
        // Titles now resolve through the String Catalog; under `swift test` the
        // catalog lives in the runner bundle (not Bundle.main), so localized
        // lookups fall back to the English source keys.
        XCTAssertEqual(ConversationFilter.all.title, "All")
        XCTAssertEqual(ConversationFilter.unread.title, "Unread")
        XCTAssertEqual(ConversationFilter.archived.title, "Archived")
    }

    func testRuntimeStatusHasProductPresentation() {
        XCTAssertEqual(RuntimeStatus.ready.productLabel, "Online")
        XCTAssertEqual(RuntimeStatus.loading("Syncing home").productLabel, "Syncing home")
        XCTAssertEqual(RuntimeStatus.offline("network unavailable").productLabel, "Offline")
        XCTAssertEqual(RuntimeStatus.error("token expired").productLabel, "Needs attention")
        XCTAssertEqual(RuntimeStatus.unavailable("native runtime missing").productLabel, "Unavailable")

        XCTAssertEqual(RuntimeStatus.ready.productTone, .success)
        XCTAssertEqual(RuntimeStatus.loading("Connecting").productTone, .info)
        XCTAssertEqual(RuntimeStatus.offline("network unavailable").productTone, .warning)
        XCTAssertEqual(RuntimeStatus.error("token expired").productTone, .danger)
        XCTAssertEqual(RuntimeStatus.unavailable("native runtime missing").productTone, .warning)

        XCTAssertFalse(RuntimeStatus.error("ack send timeout").isBlocking)
        XCTAssertTrue(RuntimeStatus.unavailable("native runtime missing").isBlocking)
    }

    @MainActor
    func testSilentEnvironmentOperationDoesNotBlockComposerState() async {
        let session = AppSession()
        let environment = AppEnvironment(session: session)
        environment.setRuntimeStatus(.ready)

        await environment.run("sync.foreground_poll", showBusy: false) {
            throw AppStoreError(message: "sync timeout")
        }

        XCTAssertEqual(environment.runtimeStatus, .ready)
        XCTAssertNil(environment.lastError)
        XCTAssertEqual(environment.labResults.first?.operation, "sync.foreground_poll")
        XCTAssertEqual(environment.labResults.first?.status, "warn")
    }

    func testLoginNativeErrorUsesProductMessage() {
        let error = FlareSdkException(
            code: "native_error_10",
            message: "Native call returned error code 10 before callback.",
            operation: "sdk.login"
        )

        XCTAssertEqual(
            FlareFormatters.errorText(error),
            "Login failed: cannot reach the Flare server. Make sure it is running and check the current protocol and server address."
        )
    }

    func testLoginDefaultsAreUsable() {
        let draft = LoginDraft()
        XCTAssertTrue(draft.userId.isEmpty)
        XCTAssertEqual(draft.wsUrl, "ws://127.0.0.1:60051/ws")
        XCTAssertEqual(draft.transportMode, .websocket)
        XCTAssertEqual(draft.quicUrl, "quic://127.0.0.1:60052")
        XCTAssertEqual(draft.tenantId, "0")
        XCTAssertEqual(draft.httpUrl, "http://127.0.0.1:50050")
    }

    func testLoginTransportConfigDefaultsToWebSocket() throws {
        let config = try LoginDraft().sdkTransportConfig()

        XCTAssertEqual(config["transportPolicy"]?.value as? String, "websocket_only")
        XCTAssertEqual(config["defaultTransport"]?.value as? String, "websocket")
        XCTAssertEqual(config["wsUrl"]?.value as? String, "ws://127.0.0.1:60051/ws")
    }

    func testLoginProtocolSelectionDrivesVisibleServerAddress() {
        var draft = LoginDraft()
        XCTAssertEqual(draft.transportMode, .websocket)
        XCTAssertEqual(draft.visibleServerAddressLabel, "WebSocket server URL")
        XCTAssertEqual(draft.visibleServerAddress, "ws://127.0.0.1:60051/ws")

        draft.transportMode = .quic
        draft.quicUrl = "quic://flare.test:60052"
        XCTAssertEqual(draft.visibleServerAddressLabel, "QUIC server URL")
        XCTAssertEqual(draft.visibleServerAddress, "quic://flare.test:60052")

        draft.transportMode = .race
        draft.wsUrl = "ws://flare.test/ws"
        XCTAssertEqual(draft.visibleServerAddressLabel, "Primary server URL")
        XCTAssertEqual(draft.visibleServerAddress, "quic://flare.test:60052")
        XCTAssertEqual(draft.secondaryServerAddressLabel, "Fallback WebSocket URL")
        XCTAssertEqual(draft.secondaryServerAddress, "ws://flare.test/ws")
    }

    func testLoginTransportConfigSupportsQuicAndRace() throws {
        var quicDraft = LoginDraft()
        quicDraft.transportMode = .quic
        quicDraft.wsUrl = ""
        quicDraft.tlsCaCertPath = " /tmp/flare-server.crt "
        let quicConfig = try quicDraft.sdkTransportConfig()

        XCTAssertEqual(quicConfig["transportPolicy"]?.value as? String, "auto")
        XCTAssertEqual(quicConfig["defaultTransport"]?.value as? String, "quic")
        XCTAssertNil(quicConfig["wsUrl"])
        XCTAssertEqual(quicConfig["quicUrl"]?.value as? String, "quic://127.0.0.1:60052")
        XCTAssertEqual(quicConfig["tlsCaCertPath"]?.value as? String, "/tmp/flare-server.crt")
        XCTAssertEqual(quicConfig["protocolRaceOrder"]?.value as? [String], ["quic"])

        var raceDraft = LoginDraft()
        raceDraft.transportMode = .race
        let raceConfig = try raceDraft.sdkTransportConfig()

        XCTAssertEqual(raceConfig["transportPolicy"]?.value as? String, "protocol_race")
        XCTAssertEqual(raceConfig["protocolRaceOrder"]?.value as? [String], ["quic", "websocket"])
    }

    func testConversationFromCoreUsesAppDisplaySemantics() {
        let core = Conversation(
            conversationId: "c1",
            conversationType: .single,
            displayName: "",
            isPinned: true,
            lastMessagePreview: "hello",
            remark: "  Alice  ",
            unreadCount: 3,
            updatedAt: 100,
            updatedAtTs: 200
        )

        let conversation = SdkModelMapper.conversationFromCore(core)

        XCTAssertEqual(conversation.conversationId, "c1")
        XCTAssertEqual(conversation.appTitle, "Alice")
        XCTAssertEqual(conversation.appPreview, "hello")
        XCTAssertEqual(conversation.appSortTimestamp, 200)
        XCTAssertEqual(conversation.unreadCount, 3)
        XCTAssertTrue(conversation.isPinned)
    }

    func testAppleWireConversationDecoderAllowsEmptyAvatarUrls() throws {
        let conversation = try conversationFromJson([
            "avatarUrl": "",
            "businessType": "",
            "channelId": "12",
            "conversationId": "single:11:12",
            "conversationType": "single",
            "createdAt": UInt64(1),
            "displayName": "12",
            "ext": [String: String](),
            "isArchived": false,
            "isMuted": false,
            "isPinned": false,
            "lastSenderAvatarUrl": "",
            "lastSenderNickname": "",
            "lastReadSeq": UInt64(0),
            "maxSeq": UInt64(0),
            "memberPreview": [[String: Any]](),
            "membersCount": UInt64(2),
            "mentionCount": UInt64(0),
            "mentionMe": false,
            "participantVersion": UInt64(0),
            "participants": [[String: Any]](),
            "peerReadSeq": UInt64(0),
            "unreadCount": UInt64(0),
            "updatedAt": UInt64(1),
            "version": UInt64(1),
            "visibleAfterSeq": UInt64(0)
        ])

        XCTAssertEqual(conversation.avatarUrl, "")
        XCTAssertEqual(conversation.lastSenderAvatarUrl, "")
        XCTAssertEqual(conversation.conversationId, "single:11:12")
    }

    @MainActor
    func testMessagingViewModelDoesNotReportSuccessWithoutConversationContext() async {
        let session = AppSession()
        let repository = ViewDataRepository()
        let environment = AppEnvironment(session: session)
        let messaging = MessagingViewModel(session: session, repository: repository, environment: environment)

        let opened = await messaging.openPeerConversation()
        let sentText = await messaging.sendText("hello")
        let sentBuilderMessage = await messaging.buildAndSend(op: .createText, payload: ["text": "hello"])

        XCTAssertNil(opened)
        XCTAssertFalse(sentText)
        XCTAssertFalse(sentBuilderMessage)
        XCTAssertNil(environment.selectedConversationId)
    }

    /// FFI 烟雾测试:用同步进 FFI/ 的 dylib 显式路径 createClient → 触发 NativeLibraryLoader.load,
    /// 再 round-trip 一个无网络诊断,证明 C-ABI 桥可用(无头验证 iOS 运行管线的 FFI 部分已修)。
    /// 运行:`scripts/sync_ffi.sh` 后 `FLARE_FFI_DYLIB="$PWD/FFI/libflare_im_core_sdk_ffi.dylib" swift test`。
    func testNativeFfiLoadsViaSyncedDylib() async throws {
        guard let dylib = ProcessInfo.processInfo.environment["FLARE_FFI_DYLIB"],
              !dylib.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw XCTSkip("Set FLARE_FFI_DYLIB to the synced libflare_im_core_sdk_ffi.dylib (run scripts/sync_ffi.sh first)")
        }
        let client = try FlareCoreSdk.createClient(libraryPath: dylib)
        let version = try await client.diagnostics.getSdkVersion()
        XCTAssertFalse("\(version)".isEmpty, "SDK version via the FFI bridge should be non-empty")
    }

    @MainActor
    func testLiveLocalLoginWhenEnabled() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["FLARE_IOS_LIVE_LOGIN"] == "1" else {
            throw XCTSkip("Set FLARE_IOS_LIVE_LOGIN=1 to run against the local Flare service")
        }
        guard let dylib = environment["FLARE_FFI_DYLIB"],
              !dylib.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw XCTSkip("Set FLARE_FFI_DYLIB to run live local login")
        }

        var draft = LoginDraft()
        draft.userId = environment["FLARE_IOS_LIVE_USER_ID"] ?? "1"
        draft.wsUrl = environment["FLARE_IOS_LIVE_WS_URL"] ?? LoginDefaults.webSocketURL
        draft.libraryPath = dylib
        draft.httpUrl = environment["FLARE_IOS_LIVE_HTTP_URL"] ?? LoginDefaults.httpURL
        let session = AppSession()
        let dataURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("flare-ios-live-login-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dataURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dataURL) }

        _ = try await session.start(draft: draft, dataURL: dataURL) { _ in }

        XCTAssertTrue(session.isLoggedIn)
        XCTAssertEqual(session.currentUserId, draft.userId)
        try? await session.logout()
        try? await session.dispose()
    }

    @MainActor
    func testLiveLocalConversationListWhenEnabled() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["FLARE_IOS_LIVE_CONVERSATION_LIST"] == "1" else {
            throw XCTSkip("Set FLARE_IOS_LIVE_CONVERSATION_LIST=1 to run against the local Flare service")
        }
        guard let dylib = environment["FLARE_FFI_DYLIB"],
              !dylib.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw XCTSkip("Set FLARE_FFI_DYLIB to run live local conversation list")
        }

        var draft = LoginDraft()
        draft.userId = environment["FLARE_IOS_LIVE_USER_ID"] ?? "11"
        draft.wsUrl = environment["FLARE_IOS_LIVE_WS_URL"] ?? LoginDefaults.webSocketURL
        draft.libraryPath = dylib
        draft.httpUrl = environment["FLARE_IOS_LIVE_HTTP_URL"] ?? LoginDefaults.httpURL

        let session = AppSession()
        let repository = ViewDataRepository()
        let dataURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("flare-ios-live-conversations-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dataURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dataURL) }

        let client = try await session.start(draft: draft, dataURL: dataURL) { _ in }
        try await repository.openConversationList(client: client, reason: "live_test")

        let expected = Int(environment["FLARE_IOS_EXPECTED_CONVERSATION_COUNT"] ?? "")
        if let expected {
            XCTAssertEqual(repository.conversations.count, expected)
        } else {
            XCTAssertFalse(repository.conversations.isEmpty, "user \(draft.userId) should have at least one local conversation")
        }

        try? await session.logout()
        try? await session.dispose()
    }

    @MainActor
    func testLiveLocalAudioBuildAndSendWhenEnabled() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["FLARE_IOS_LIVE_AUDIO"] == "1" else {
            throw XCTSkip("Set FLARE_IOS_LIVE_AUDIO=1 to run against the local Flare service")
        }
        guard let dylib = environment["FLARE_FFI_DYLIB"],
              !dylib.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw XCTSkip("Set FLARE_FFI_DYLIB to run live local audio message checks")
        }

        var draft = LoginDraft()
        draft.userId = environment["FLARE_IOS_LIVE_USER_ID"] ?? "11"
        draft.wsUrl = environment["FLARE_IOS_LIVE_WS_URL"] ?? LoginDefaults.webSocketURL
        draft.libraryPath = dylib
        draft.httpUrl = environment["FLARE_IOS_LIVE_HTTP_URL"] ?? LoginDefaults.httpURL

        let session = AppSession()
        let repository = ViewDataRepository()
        let dataURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("flare-ios-live-audio-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dataURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dataURL) }
        defer {
            Task {
                try? await session.logout()
                try? await session.dispose()
            }
        }

        let client = try await session.start(draft: draft, dataURL: dataURL) { _ in }
        try await repository.openConversationList(client: client, reason: "live_audio")
        let conversationId = try XCTUnwrap(repository.conversations.first?.conversationId)
        let audioId = "ios-live-audio-\(UUID().uuidString)"
        let source = MediaSourceInfo(
            uuid: audioId,
            url: "file:///tmp/\(audioId).m4a",
            mimeType: "audio/mp4",
            size: 1024,
            durationMs: 1200
        )
        let message = try await client.messageBuilder.buildAudio(BuildAudioMessageRequest(
            conversationId: conversationId,
            audioId: audioId,
            payload: AudioContentPayload(audioId: audioId, source: source, durationMs: 1200)
        ))

        XCTAssertEqual(message.conversationId, conversationId)
        XCTAssertEqual(message.content?.contentType, .audio)

        if environment["FLARE_IOS_LIVE_AUDIO_SEND"] == "1" {
            let ack = try await client.messages.sendMessage(SendMessageRequest(message: message), callback: nil)
            XCTAssertEqual(ack.conversationId, conversationId)
        }
    }

    func testMessageFromCoreKeepsTypedContentAndStableIdentity() {
        let core = Message(
            clientCreatedAt: 900,
            clientMsgId: "client-1",
            content: MessageContent(contentType: .text, data: ["text": AnySendable("hi")]),
            conversationId: "c1",
            conversationSeq: 7,
            createdAt: 1000,
            senderDisplayName: "Alice",
            senderId: "alice",
            serverId: "server-1"
        )

        let message = SdkModelMapper.messageFromCore(core)

        XCTAssertEqual(message.appStableId, "server-1")
        XCTAssertEqual(message.appSortTimestamp, 1000)
        XCTAssertEqual(message.senderTitle, "Alice")
        XCTAssertEqual(message.previewText, "hi")
        XCTAssertEqual(message.seq, 7)
        XCTAssertEqual(message.core.content?.contentType, .text)
    }

    func testMessageRowReactionGroupsMarkTheViewersOwnAndHideOnRecall() {
        let reactions = [
            ReactionEntry(count: 2, emoji: "👍", userIds: ["alice", "bob"]),
            ReactionEntry(count: 1, emoji: "❤️", userIds: ["carol"]),
        ]
        let live = SdkModelMapper.messageFromCore(Message(clientMsgId: "client-1", reactions: reactions, senderId: "carol", serverId: "server-1"))

        let groups = MessageRow.reactionGroups(for: live, currentUserId: "alice")
        XCTAssertEqual(groups.map(\.emoji), ["👍", "❤️"])
        XCTAssertEqual(groups.map(\.count), [2, 1])
        XCTAssertEqual(groups.map(\.reactedBySelf), [true, false])
        XCTAssertEqual(MessageRow.reactionGroups(for: live, currentUserId: nil).map(\.reactedBySelf), [false, false])

        let recalled = SdkModelMapper.messageFromCore(Message(clientMsgId: "client-2", isRecalled: true, reactions: reactions, serverId: "server-2"))
        XCTAssertTrue(MessageRow.reactionGroups(for: recalled, currentUserId: "alice").isEmpty)
    }

    func testMessageContentPresentationReadsSelectedMediaPayloads() {
        let image = MessageContent(contentType: .image, data: [
            "description": AnySendable("IMG_001"),
            "source": AnySendable([
                "uuid": AnySendable("media-image-001"),
                "url": AnySendable("file:///tmp/flare/IMG_001.jpg"),
                "mimeType": AnySendable("image/jpeg"),
                "size": AnySendable(UInt64(42_000)),
                "width": AnySendable(1280),
                "height": AnySendable(720)
            ])
        ])

        XCTAssertEqual(image.mediaSourceURL?.absoluteString, "file:///tmp/flare/IMG_001.jpg")
        XCTAssertEqual(image.mediaFileId, "media-image-001")
        XCTAssertTrue(image.mediaResolveKey.contains("media-image-001"))
        XCTAssertEqual(image.mediaMimeType, "image/jpeg")
        XCTAssertEqual(image.mediaByteSize, 42_000)
        XCTAssertEqual(image.imagePixelSize?.width, 1280)
        XCTAssertEqual(image.imagePixelSize?.height, 720)

        let file = MessageContent(contentType: .file, data: [
            "fileId": AnySendable("media-file-1"),
            "name": AnySendable("产品方案.pdf"),
            "url": AnySendable("file:///tmp/产品方案.pdf"),
            "mimeType": AnySendable("application/pdf"),
            "size": AnySendable("2048")
        ])

        XCTAssertEqual(file.fileDisplayName, "产品方案.pdf")
        XCTAssertEqual(file.mediaFileId, "media-file-1")
        XCTAssertEqual(file.mediaMimeType, "application/pdf")
        XCTAssertEqual(file.mediaByteSize, 2048)

        let video = MessageContent(contentType: .video, data: [
            "description": AnySendable("demo.mp4"),
            "source": AnySendable([
                "url": AnySendable("file:///tmp/flare/demo.mp4"),
                "mimeType": AnySendable("video/mp4"),
                "size": AnySendable(UInt64(1_024_000)),
                "durationMs": AnySendable(65_000)
            ])
        ])

        XCTAssertEqual(video.mediaSourceURL?.absoluteString, "file:///tmp/flare/demo.mp4")
        XCTAssertEqual(video.mediaMimeType, "video/mp4")
        XCTAssertEqual(video.mediaByteSize, 1_024_000)
        XCTAssertEqual(video.mediaDurationMs, 65_000)
        XCTAssertEqual(video.mediaDurationText, "1:05")

        let audio = MessageContent(contentType: .audio, data: [
            "audioId": AnySendable("media-audio-1"),
            "source": AnySendable([
                "url": AnySendable("file:///tmp/flare/voice.m4a"),
                "mimeType": AnySendable("audio/mp4"),
                "size": AnySendable(UInt64(18_000)),
                "durationMs": AnySendable(4_200)
            ])
        ])

        XCTAssertEqual(audio.mediaSourceURL?.absoluteString, "file:///tmp/flare/voice.m4a")
        XCTAssertEqual(audio.mediaFileId, "media-audio-1")
        XCTAssertEqual(audio.mediaMimeType, "audio/mp4")
        XCTAssertEqual(audio.mediaByteSize, 18_000)
        XCTAssertEqual(audio.mediaDurationText, "0:04")
    }

    func testMessageContentPresentationReadsNestedMediaPayloadsFromCore() {
        let image = MessageContent(contentType: .image, data: [
            "image": AnySendable([
                "description": AnySendable("nested.jpg"),
                "source": AnySendable([
                    "imageId": AnySendable("nested-image-id"),
                    "url": AnySendable("file:///tmp/flare/nested.jpg"),
                    "mimeType": AnySendable("image/jpeg"),
                    "size": AnySendable(UInt64(2048)),
                    "width": AnySendable(640),
                    "height": AnySendable(480)
                ])
            ])
        ])

        XCTAssertEqual(image.mediaSourceURL?.absoluteString, "file:///tmp/flare/nested.jpg")
        XCTAssertEqual(image.mediaFileId, "nested-image-id")
        XCTAssertEqual(image.mediaMimeType, "image/jpeg")
        XCTAssertEqual(image.mediaByteSize, 2048)
        XCTAssertEqual(image.imagePixelSize?.width, 640)
        XCTAssertEqual(image.imagePixelSize?.height, 480)
        XCTAssertEqual(image.stringValue("description"), "nested.jpg")
    }

    func testComposerMediaUploadPayloadUsesUploadedRemoteMedia() throws {
        let image = ComposerMediaUploadPayload.imagePayload(
            localPayload: [
                "imageId": "local-image-1",
                "description": "local.jpg",
                "sourceUrl": "file:///tmp/local.jpg",
                "localPath": "/tmp/local.jpg",
                "mimeType": "image/jpeg",
                "size": 12,
                "width": 320,
                "height": 180
            ],
            uploaded: [
                "fileId": AnySendable("media-image-1"),
                "cdnUrl": AnySendable("https://cdn.example/image.jpg"),
                "mimeType": AnySendable("image/jpeg"),
                "size": AnySendable(Int64(42_000))
            ]
        )

        XCTAssertEqual(image["imageId"] as? String, "media-image-1")
        XCTAssertEqual(image["sourceUrl"] as? String, "https://cdn.example/image.jpg")
        XCTAssertEqual(image["mimeType"] as? String, "image/jpeg")
        XCTAssertEqual(image["size"] as? Int64, 42_000)
        XCTAssertEqual(image["width"] as? Int, 320)
        XCTAssertEqual(image["height"] as? Int, 180)
        XCTAssertNil(image["localPath"])

        let uncaptainedImage = ComposerMediaUploadPayload.imagePayload(
            localPayload: [
                "imageId": "local-image-2",
                "sourceUrl": "file:///tmp/local-2.jpg",
                "localPath": "/tmp/local-2.jpg",
                "mimeType": "image/jpeg"
            ],
            uploaded: [
                "fileId": AnySendable("media-image-2"),
                "url": AnySendable("https://cdn.example/image-2.jpg")
            ]
        )
        XCTAssertNil(uncaptainedImage["description"])
        XCTAssertEqual(
            MessageBuilder.makeImageBuildRequest(conversationId: "c1", payload: uncaptainedImage).payload?.description,
            ""
        )

        let imageRequest = MessageBuilder.makeImageBuildRequest(conversationId: "c1", payload: image)
        XCTAssertEqual(imageRequest.imageId, "media-image-1")
        XCTAssertEqual(imageRequest.payload?.source?.uuid, "media-image-1")
        XCTAssertEqual(imageRequest.payload?.source?.url, "https://cdn.example/image.jpg")
        XCTAssertEqual(imageRequest.payload?.source?.size, 42_000)

        let imageContent = MessageBuilder.makeImageWithContentRequest(conversationId: "c1", payload: image)
        XCTAssertEqual(imageContent.conversationId, "c1")
        XCTAssertEqual(imageContent.content.contentType, .image)
        XCTAssertEqual(imageContent.content.data["imageId"]?.value as? String, "media-image-1")
        let imageSource = try XCTUnwrap(imageContent.content.data["source"]?.value as? [String: Any])
        XCTAssertEqual(imageSource["uuid"] as? String, "media-image-1")
        XCTAssertEqual(imageSource["imageId"] as? String, "media-image-1")
        XCTAssertEqual(imageSource["url"] as? String, "https://cdn.example/image.jpg")
        XCTAssertEqual(imageSource["mimeType"] as? String, "image/jpeg")
        XCTAssertEqual(imageSource["size"] as? UInt64, 42_000)
        XCTAssertEqual(imageSource["width"] as? Int32, 320)
        XCTAssertEqual(imageSource["height"] as? Int32, 180)

        let audio = ComposerMediaUploadPayload.audioPayload(
            localPayload: [
                "audioId": "local-audio-1",
                "description": "语音消息",
                "sourceUrl": "file:///tmp/local.m4a",
                "localPath": "/tmp/local.m4a",
                "mimeType": "audio/mp4",
                "durationMs": 3600,
                "size": 10
            ],
            uploaded: [
                "file_id": AnySendable("media-audio-1"),
                "url": AnySendable("https://media.example/audio.m4a"),
                "mime_type": AnySendable("audio/mp4"),
                "size": AnySendable(2048)
            ]
        )

        XCTAssertEqual(audio["audioId"] as? String, "media-audio-1")
        XCTAssertEqual(audio["sourceUrl"] as? String, "https://media.example/audio.m4a")
        XCTAssertEqual(audio["mimeType"] as? String, "audio/mp4")
        XCTAssertEqual(audio["durationMs"] as? Int, 3600)
        XCTAssertEqual(audio["size"] as? Int64, 2048)
        XCTAssertNil(audio["localPath"])

        let audioRequest = MessageBuilder.makeAudioBuildRequest(conversationId: "c1", payload: audio)
        XCTAssertEqual(audioRequest.audioId, "media-audio-1")
        XCTAssertEqual(audioRequest.payload?.source?.uuid, "media-audio-1")
        XCTAssertEqual(audioRequest.payload?.source?.url, "https://media.example/audio.m4a")
        XCTAssertEqual(audioRequest.payload?.source?.durationMs, 3600)
        XCTAssertEqual(audioRequest.payload?.source?.size, 2048)

        let alternateAudio = ComposerMediaUploadPayload.audioPayload(
            localPayload: [
                "audioId": "local-audio-2",
                "description": "语音消息",
                "mimeType": "audio/webm",
                "durationMs": 1200
            ],
            uploaded: [
                "data": AnySendable([
                    "mediaId": AnySendable("media-audio-2"),
                    "mediaUrl": AnySendable("https://media.example/audio-2.webm"),
                    "contentType": AnySendable("audio/webm"),
                    "fileSize": AnySendable(4096)
                ])
            ]
        )
        XCTAssertEqual(alternateAudio["audioId"] as? String, "media-audio-2")
        XCTAssertEqual(alternateAudio["sourceUrl"] as? String, "https://media.example/audio-2.webm")
        XCTAssertEqual(alternateAudio["mimeType"] as? String, "audio/webm")
        XCTAssertEqual(alternateAudio["size"] as? Int64, 4096)

        let audioContent = MessageBuilder.makeAudioWithContentRequest(conversationId: "c1", payload: audio)
        XCTAssertEqual(audioContent.conversationId, "c1")
        XCTAssertEqual(audioContent.content.contentType, .audio)
        XCTAssertEqual(audioContent.content.data["audioId"]?.value as? String, "media-audio-1")
        XCTAssertEqual(audioContent.content.data["durationMs"]?.value as? Int32, 3600)
        let audioSource = try XCTUnwrap(audioContent.content.data["source"]?.value as? [String: Any])
        XCTAssertEqual(audioSource["uuid"] as? String, "media-audio-1")
        XCTAssertEqual(audioSource["url"] as? String, "https://media.example/audio.m4a")
        XCTAssertEqual(audioSource["mimeType"] as? String, "audio/mp4")
        XCTAssertEqual(audioSource["durationMs"] as? Int32, 3600)
        XCTAssertEqual(audioSource["size"] as? UInt64, 2048)
    }

    func testPreviewTextFormatsWebEmojiPackTokens() {
        let content = MessageContent(contentType: .text, data: [
            "text": AnySendable("[face_with_open_mouth][face_with_open_eyes_and_hand_over_mouth]")
        ])

        XCTAssertEqual(content.previewText, "[吃惊][睁眼捂嘴]")
    }

    func testEmojiPresentationDetectsOnlyOneVisibleEmoji() {
        XCTAssertEqual(EmojiPresentation.singleEmoji(in: " 😂\n"), "😂")
        XCTAssertEqual(EmojiPresentation.singleEmoji(in: "❤️"), "❤️")
        XCTAssertEqual(EmojiPresentation.singleEmoji(in: "👨‍👩‍👧‍👦"), "👨‍👩‍👧‍👦")

        XCTAssertNil(EmojiPresentation.singleEmoji(in: "😂😂"))
        XCTAssertNil(EmojiPresentation.singleEmoji(in: "1"))
        XCTAssertNil(EmojiPresentation.singleEmoji(in: "[吃惊]"))
        XCTAssertNil(EmojiPresentation.singleEmoji(in: "hello"))
    }

    func testEmojiContentPreviewKeepsPackKeyForAssetRendering() {
        let packEmoji = MessageContent(contentType: .emoji, data: [
            "emoji": AnySendable("smirking_face")
        ])
        let localizedPackEmoji = MessageContent(contentType: .emoji, data: [
            "emoji": AnySendable("face_with_open_mouth")
        ])

        XCTAssertEqual(packEmoji.previewText, "[smirking_face]")
        XCTAssertEqual(EmojiPresentation.lonePackKey(in: packEmoji.previewText), "smirking_face")
        XCTAssertEqual(localizedPackEmoji.previewText, "[吃惊]")
        XCTAssertNil(EmojiPresentation.lonePackKey(in: localizedPackEmoji.previewText))
    }

    func testEmojiPresentationSplitsComposerInputPackTokens() {
        let segments = EmojiPresentation.displaySegments(in: "Hi [smirking_face] [missing_pack_key]")

        XCTAssertEqual(segments.count, 3)
        XCTAssertTrue(EmojiPresentation.hasDisplayEmoji(in: "Hi [smirking_face]"))
        XCTAssertFalse(EmojiPresentation.hasDisplayEmoji(in: "[missing_pack_key]"))

        if case .text(let text) = segments[0].kind {
            XCTAssertEqual(text, "Hi ")
        } else {
            XCTFail("Expected leading text segment")
        }

        if case .emoji(let key) = segments[1].kind {
            XCTAssertEqual(key, "smirking_face")
        } else {
            XCTFail("Expected emoji segment")
        }

        if case .text(let text) = segments[2].kind {
            XCTAssertEqual(text, " [missing_pack_key]")
        } else {
            XCTFail("Expected unknown pack key to stay text")
        }
    }

    func testEmojiPresentationResolvesKitBundledAssets() {
        // Assets now resolve from the flare-im-design kit's bundled central source.
        XCTAssertNotNil(EmojiPresentation.emojiURL(for: "smirking_face"))
        XCTAssertNotNil(EmojiPresentation.stickerURL(packageId: "classic", stickerId: "001"))
        XCTAssertNotNil(EmojiPresentation.stickerURL(packageId: "gifs", stickerId: "001"))

        XCTAssertEqual(FlareEmojiStickerCatalog.stickerSubdir(forPackageId: "gifs"), "default")
        XCTAssertNil(EmojiPresentation.emojiURL(for: "missing_pack_key"))
        XCTAssertNil(EmojiPresentation.stickerURL(packageId: "classic", stickerId: "../001"))
    }

    func testMessageContentPresentationReadsSchedulePayload() {
        let content = MessageContent(contentType: .schedule, data: [
            "title": AnySendable("产品评审 · 会议室 A"),
            "startTimeMs": AnySendable(Int64(1_800_000)),
            "endTimeMs": AnySendable("3600000")
        ])

        XCTAssertEqual(content.stringValue("title"), "产品评审 · 会议室 A")
        XCTAssertEqual(content.int64Value("startTimeMs"), 1_800_000)
        XCTAssertEqual(content.int64Value("endTimeMs"), 3_600_000)
    }

    func testRichTextPreviewPrefersPlainText() {
        let content = MessageContent(contentType: .richText, data: [
            "docJson": AnySendable("{\"blocks\":[]}"),
            "markdown": AnySendable("## 标题\n\n**正文**"),
            "plainText": AnySendable("标题\n\n正文"),
            "searchText": AnySendable("标题 正文")
        ])

        XCTAssertEqual(content.previewText, "标题\n\n正文")
    }

    func testRichTextShortcutTogglesApplyToFutureInputState() {
        for shortcut in RichTextShortcut.allCases {
            var selection = RichTextComposerSelection()
            selection.toggle(shortcut)

            XCTAssertTrue(selection.isActive(shortcut), "\(shortcut.rawValue) should become active")

            selection.toggle(shortcut)
            XCTAssertFalse(selection.isActive(shortcut), "\(shortcut.rawValue) should toggle off")
        }

        var blockSelection = RichTextComposerSelection()
        blockSelection.toggle(.heading)
        blockSelection.toggle(.quote)

        XCTAssertFalse(blockSelection.isActive(.heading))
        XCTAssertTrue(blockSelection.isActive(.quote))
    }

    func testRichTextMarkdownSerializerCoversComposerButtonOutput() {
        let document = NSMutableAttributedString()
        appendRichRun("标题", to: document, block: .heading)
        appendPlainBreak(to: document)
        appendRichRun("重点", to: document, inline: [.bold])
        appendPlainBreak(to: document)
        appendRichRun("删除", to: document, inline: [.strike])
        appendPlainBreak(to: document)
        appendRichRun("强调", to: document, inline: [.italic])
        appendPlainBreak(to: document)
        appendRichRun("列表", to: document, block: .bulletList)
        appendPlainBreak(to: document)
        appendRichRun("编号", to: document, block: .orderedList)
        appendPlainBreak(to: document)
        appendRichRun("引用", to: document, block: .quote)
        appendPlainBreak(to: document)
        appendRichRun("代码", to: document, block: .codeBlock)
        appendPlainBreak(to: document)
        appendRichRun("链接", to: document, inline: [.link])
        appendPlainBreak(to: document)
        appendRichRun("图片", to: document, inline: [.image])
        appendPlainBreak(to: document)
        appendRichRun("小明", to: document, inline: [.mention])

        let export = RichTextMarkdownSerializer.export(document)

        XCTAssertEqual(export.plainText, "标题\n重点\n删除\n强调\n列表\n编号\n引用\n代码\n链接\n图片\n小明")
        XCTAssertEqual(export.searchText, "标题 重点 删除 强调 列表 编号 引用 代码 链接 图片 小明")
        XCTAssertEqual(export.title, "标题")
        XCTAssertEqual(export.markdown, """
## 标题
**重点**
~~删除~~
*强调*
- 列表
1. 编号
> 引用
```
代码
```
[链接](https://)
![图片](https://)
@小明
""")
    }

    func testMessagesApiSendsNativeMessageBodyWithoutRequestWrapper() async throws {
        let bridge = RecordingNativeBridge()
        let api = DefaultMessagesApi(bridge: bridge)
        let message = Message(
            clientMsgId: "client-1",
            content: MessageContent(contentType: .text, data: ["text": AnySendable("hello")]),
            conversationId: "c1",
            senderId: "11"
        )

        _ = try await api.sendMessage(SendMessageRequest(message: message), callback: nil)
        _ = try await api.sendMessageNoOss(SendMessageRequest(message: message))

        XCTAssertEqual(bridge.calls.map(\.descriptor.operation), ["message.send", "message.send_no_oss"])
        for call in bridge.calls {
            let request = try XCTUnwrap(call.request?.value as? [String: Any])
            XCTAssertNil(request["message"], "\(call.descriptor.operation) must pass Message JSON, not SendMessageRequest JSON")
            XCTAssertEqual(request["clientMsgId"] as? String, "client-1")
            XCTAssertEqual(request["conversationId"] as? String, "c1")
            XCTAssertEqual(request["senderId"] as? String, "11")
        }
    }

    func testMessageBuilderApiUsesTypedAudioDescriptor() async throws {
        let bridge = RecordingNativeBridge()
        let api = DefaultMessageBuilderApi(bridge: bridge)

        _ = try await api.buildAudio(BuildAudioMessageRequest(conversationId: "c1", audioId: "audio-1"))

        let call = try XCTUnwrap(bridge.calls.last)
        XCTAssertEqual(call.descriptor.operation, "message_builder.create_audio")
        XCTAssertEqual(call.descriptor.dispatchOp, "create_audio")

        let request = try XCTUnwrap(call.request?.value as? [String: Any])
        XCTAssertEqual(request["op"] as? String, "create_audio")
        XCTAssertEqual(request["conversationId"] as? String, "c1")
        XCTAssertEqual(request["audioId"] as? String, "audio-1")
    }

    func testMessageBuilderApiUsesTypedEmojiDescriptor() async throws {
        let bridge = RecordingNativeBridge()
        let api = DefaultMessageBuilderApi(bridge: bridge)

        _ = try await api.buildEmoji(BuildEmojiMessageRequest(conversationId: "c1", emoji: "smirking_face"))

        let call = try XCTUnwrap(bridge.calls.last)
        XCTAssertEqual(call.descriptor.operation, "message_builder.create_emoji")
        XCTAssertEqual(call.descriptor.dispatchOp, "create_emoji")

        let request = try XCTUnwrap(call.request?.value as? [String: Any])
        XCTAssertEqual(request["op"] as? String, "create_emoji")
        XCTAssertEqual(request["conversationId"] as? String, "c1")
        XCTAssertEqual(request["emoji"] as? String, "smirking_face")
    }

    func testMessageBuilderApiUsesTypedRichDocDescriptor() async throws {
        let bridge = RecordingNativeBridge()
        let api = DefaultMessageBuilderApi(bridge: bridge)

        _ = try await api.buildRichDoc(BuildRichDocMessageRequest(
            conversationId: "c1",
            docJson: "{\"blocks\":[]}",
            contentSchema: "rich_doc",
            plainText: "Title\nBold",
            inputFormat: "markdown",
            inputFormatVersion: 1,
            sourcePayload: ["markdown": "## Title\n**Bold**"],
            title: "Title",
            searchText: "Title Bold"
        ))

        let call = try XCTUnwrap(bridge.calls.last)
        XCTAssertEqual(call.descriptor.operation, "message_builder.create_rich_doc")
        XCTAssertEqual(call.descriptor.dispatchOp, "create_rich_doc")

        let request = try XCTUnwrap(call.request?.value as? [String: Any])
        XCTAssertEqual(request["op"] as? String, "create_rich_doc")
        XCTAssertEqual(request["conversationId"] as? String, "c1")
        XCTAssertEqual(request["plainText"] as? String, "Title\nBold")
        XCTAssertEqual(request["title"] as? String, "Title")
        XCTAssertEqual(request["searchText"] as? String, "Title Bold")
        let sourcePayload = try XCTUnwrap(request["sourcePayload"] as? [String: String])
        XCTAssertEqual(sourcePayload["markdown"], "## Title\n**Bold**")
    }

    func testMessageBuilderQuoteUsesExplicitReplyTargetPayload() async throws {
        let bridge = RecordingNativeBridge()
        let client = DefaultFlareImClient(bridge: bridge)
        let fallbackMessage = Message(
            clientMsgId: "fallback-client",
            content: MessageContent(contentType: .text, data: ["text": AnySendable("fallback")]),
            conversationId: "c1",
            senderId: "fallback-sender",
            serverId: "fallback-server"
        )

        _ = try await MessageBuilder.build(
            client: client,
            conversationId: "c1",
            op: .createQuote,
            payload: [
                "quotedMessageId": "target-server",
                "quotedSenderId": "12",
                "quotedTextPreview": "target preview",
                "text": "reply body"
            ],
            selectedMessages: [SdkModelMapper.messageFromCore(fallbackMessage)]
        )

        let call = try XCTUnwrap(bridge.calls.last)
        XCTAssertEqual(call.descriptor.operation, "message_builder.create_quote")
        XCTAssertEqual(call.descriptor.dispatchOp, "create_quote")

        let request = try XCTUnwrap(call.request?.value as? [String: Any])
        XCTAssertEqual(request["conversationId"] as? String, "c1")
        XCTAssertEqual(request["quotedMessageId"] as? String, "target-server")
        XCTAssertEqual(request["quotedSenderId"] as? String, "12")
        XCTAssertEqual(request["quotedTextPreview"] as? String, "target preview")
        XCTAssertEqual(request["text"] as? String, "reply body")
    }

    func testMessageBuilderApiEncodesNestedMediaSourceAsJsonObject() async throws {
        let bridge = RecordingNativeBridge()
        let api = DefaultMessageBuilderApi(bridge: bridge)
        let source = MediaSourceInfo(
            uuid: "audio-1",
            url: "file:///tmp/audio-1.m4a",
            mimeType: "audio/mp4",
            size: 1024,
            durationMs: 1200
        )

        _ = try await api.buildAudio(BuildAudioMessageRequest(
            conversationId: "c1",
            audioId: "audio-1",
            payload: AudioContentPayload(audioId: "audio-1", source: source, durationMs: 1200)
        ))

        let call = try XCTUnwrap(bridge.calls.last)
        let request = try XCTUnwrap(call.request?.value as? [String: Any])
        XCTAssertTrue(JSONSerialization.isValidJSONObject(request))
        let payload = try XCTUnwrap(request["payload"] as? [String: Any])
        let sourcePayload = try XCTUnwrap(payload["source"] as? [String: Any])
        XCTAssertEqual(sourcePayload["uuid"] as? String, "audio-1")
        XCTAssertEqual(sourcePayload["url"] as? String, "file:///tmp/audio-1.m4a")
        XCTAssertEqual(sourcePayload["mimeType"] as? String, "audio/mp4")
        XCTAssertEqual(sourcePayload["size"] as? UInt64, 1024)
        XCTAssertEqual(sourcePayload["durationMs"] as? Int32, 1200)
    }

    @MainActor
    func testMessagingViewModelCreatesTypedMediaBuildRequestsFromComposerPayloads() {
        let image = MessageBuilder.makeImageBuildRequest(conversationId: "c1", payload: [
            "imageId": "image-1",
            "sourceUrl": "file:///tmp/image-1.jpg",
            "mimeType": "image/jpeg",
            "size": 42_000,
            "width": 1280,
            "height": 720,
            "description": "image caption"
        ])

        XCTAssertEqual(image.conversationId, "c1")
        XCTAssertEqual(image.imageId, "image-1")
        XCTAssertEqual(image.payload?.imageId, "image-1")
        XCTAssertEqual(image.payload?.description, "image caption")
        XCTAssertEqual(image.payload?.source?.uuid, "image-1")
        XCTAssertEqual(image.payload?.source?.imageId, "image-1")
        XCTAssertEqual(image.payload?.source?.url, "file:///tmp/image-1.jpg")
        XCTAssertEqual(image.payload?.source?.mimeType, "image/jpeg")
        XCTAssertEqual(image.payload?.source?.size, 42_000)
        XCTAssertEqual(image.payload?.source?.width, 1280)
        XCTAssertEqual(image.payload?.source?.height, 720)

        let video = MessageBuilder.makeVideoBuildRequest(conversationId: "c1", payload: [
            "videoId": "video-1",
            "sourceUrl": "file:///tmp/video-1.mp4",
            "mimeType": "video/mp4",
            "size": 2_048_000,
            "durationMs": 65_000,
            "description": "video caption"
        ])

        XCTAssertEqual(video.conversationId, "c1")
        XCTAssertEqual(video.videoId, "video-1")
        XCTAssertEqual(video.payload?.videoId, "video-1")
        XCTAssertEqual(video.payload?.description, "video caption")
        XCTAssertEqual(video.payload?.source?.uuid, "video-1")
        XCTAssertEqual(video.payload?.source?.url, "file:///tmp/video-1.mp4")
        XCTAssertEqual(video.payload?.source?.mimeType, "video/mp4")
        XCTAssertEqual(video.payload?.source?.size, 2_048_000)
        XCTAssertEqual(video.payload?.source?.durationMs, 65_000)

        let audio = MessageBuilder.makeAudioBuildRequest(conversationId: "c1", payload: [
            "audioId": "audio-1",
            "sourceUrl": "file:///tmp/audio-1.m4a",
            "mimeType": "audio/mp4",
            "size": 18_000
        ])

        XCTAssertEqual(audio.conversationId, "c1")
        XCTAssertEqual(audio.audioId, "audio-1")
        XCTAssertEqual(audio.payload?.audioId, "audio-1")
        XCTAssertEqual(audio.payload?.durationMs, 18_000)
        XCTAssertEqual(audio.payload?.source?.uuid, "audio-1")
        XCTAssertEqual(audio.payload?.source?.url, "file:///tmp/audio-1.m4a")
        XCTAssertEqual(audio.payload?.source?.mimeType, "audio/mp4")
        XCTAssertEqual(audio.payload?.source?.size, 18_000)
        XCTAssertEqual(audio.payload?.source?.durationMs, 18_000)
    }
}

private func appendRichRun(
    _ value: String,
    to document: NSMutableAttributedString,
    block: RichTextBlockStyle = .body,
    inline: Set<RichTextInlineStyle> = []
) {
    document.append(NSAttributedString(
        string: value,
        attributes: RichTextMarkdownSerializer.attributes(for: RichTextComposerSelection(
            inlineStyles: inline,
            blockStyle: block
        ))
    ))
}

private func appendPlainBreak(to document: NSMutableAttributedString) {
    document.append(NSAttributedString(string: "\n", attributes: RichTextMarkdownSerializer.attributes(for: RichTextComposerSelection())))
}

private final class RecordingNativeBridge: NativeBridgeProtocol {
    private(set) var calls: [(descriptor: NativeCallDescriptor, request: AnySendable?)] = []

    func invoke(_ descriptor: NativeCallDescriptor, request: AnySendable?) async throws -> AnySendable {
        calls.append((descriptor, request))
        if descriptor.module == "message_builder" {
            return AnySendable(recordedMessage())
        }
        return AnySendable([
            "ackId": AnySendable("ack-1"),
            "serverId": AnySendable("server-1"),
            "clientMsgId": AnySendable("client-1"),
            "conversationId": AnySendable("c1"),
            "seq": AnySendable(1),
            "timestamp": AnySendable(1),
            "success": AnySendable(true),
            "errorCode": AnySendable(0),
            "errorMessage": AnySendable("")
        ])
    }

    private func recordedMessage() -> [String: AnySendable] {
        [
            "attributes": AnySendable([String: String]()),
            "channelId": AnySendable("12"),
            "clientCreatedAt": AnySendable(UInt64(1)),
            "clientMsgId": AnySendable("client-1"),
            "conversationId": AnySendable("c1"),
            "conversationSeq": AnySendable(UInt64(0)),
            "conversationType": AnySendable(UInt64(1)),
            "createdAt": AnySendable(UInt64(1)),
            "extensions": AnySendable([String: [UInt8]]()),
            "isEdited": AnySendable(false),
            "isRead": AnySendable(false),
            "isRecalled": AnySendable(false),
            "mentionAll": AnySendable(false),
            "mentionUsers": AnySendable([String]()),
            "messageType": AnySendable(UInt64(3)),
            "reactions": AnySendable([[String: Any]]()),
            "senderAvatar": AnySendable(""),
            "senderDisplayName": AnySendable(""),
            "senderId": AnySendable("11"),
            "senderName": AnySendable("11"),
            "serverId": AnySendable(""),
            "source": AnySendable(UInt64(0)),
            "status": AnySendable(UInt64(0)),
            "textPreview": AnySendable(""),
            "timelineKey": AnySendable("client-1"),
            "timelineSortTs": AnySendable(UInt64(1)),
            "updatedAt": AnySendable(UInt64(1)),
            "version": AnySendable(UInt64(1))
        ]
    }
}
