import Foundation
import FlareCoreAppleSDK

/// Turns an untyped composer/SDK-Lab `payload` into a typed Core message via the
/// SDK's `messageBuilder` facade. Pulled out of `MessagingViewModel` so the view
/// model owns UI state only and the payload-shaping logic stays pure and testable.
///
/// State-free: anything build needs from the view model (e.g. the currently
/// selected messages for forward/quote defaults) is passed in explicitly.
enum MessageBuilder {
    static func build(
        client: any FlareImClientProtocol,
        conversationId: String,
        op: MessageBuildOp,
        payload: [String: Any],
        selectedMessages: [AppMessage]
    ) async throws -> Message {
        switch op {
        case .createText:
            return try await client.messageBuilder.buildText(BuildTextMessageRequest(
                conversationId: conversationId,
                text: payloadString(payload, "text", default: "Hello from Apple SDK")
            ))
        case .createEmoji:
            return try await client.messageBuilder.buildEmoji(BuildEmojiMessageRequest(
                conversationId: conversationId,
                emoji: payloadString(payload, "emoji", default: "wave")
            ))
        case .createSticker:
            let stickerId = payloadString(payload, "stickerId", default: "flare-default")
            let packageId = payloadString(payload, "packageId", default: "default")
            return try await client.messageBuilder.buildSticker(BuildStickerMessageRequest(
                conversationId: conversationId,
                stickerId: stickerId,
                packageId: packageId,
                payload: StickerContentPayload(
                    stickerId: stickerId,
                    packageId: packageId,
                    url: payloadOptionalString(payload, "url"),
                    format: payloadOptionalString(payload, "format") ?? "webp"
                )
            ))
        case .createLocation:
            return try await client.messageBuilder.buildLocation(BuildLocationMessageRequest(
                conversationId: conversationId,
                latitude: payloadDouble(payload, "latitude", default: 31.2304),
                longitude: payloadDouble(payload, "longitude", default: 121.4737),
                title: payloadString(payload, "title", default: "Location"),
                address: payloadString(payload, "address", default: "Shanghai")
            ))
        case .createCard:
            return try await client.messageBuilder.buildCard(BuildCardMessageRequest(
                conversationId: conversationId,
                id: payloadString(payload, "id", default: "demo-card"),
                cardType: payloadString(payload, "cardType", default: "user"),
                title: payloadString(payload, "title", default: "Card"),
                subtitle: payloadString(payload, "subtitle", default: ""),
                avatar: payloadString(payload, "avatar", default: "")
            ))
        case .createRichDoc:
            let markdown = payloadString(payload, "markdown", default: "## Hello from Apple SDK")
            let plainText = payloadString(payload, "plainText", default: markdown)
            return try await client.messageBuilder.buildRichDoc(BuildRichDocMessageRequest(
                conversationId: conversationId,
                docJson: payloadString(payload, "docJson", default: richDocJson(text: plainText)),
                contentSchema: payloadString(payload, "contentSchema", default: "rich_doc"),
                plainText: plainText,
                inputFormat: payloadString(payload, "inputFormat", default: "markdown"),
                inputFormatVersion: Int32(payloadInt(payload, "inputFormatVersion", default: 1)),
                sourcePayload: ["markdown": markdown],
                title: payloadString(payload, "title", default: "Rich Doc"),
                searchText: payloadString(payload, "searchText", default: plainText)
            ))
        case .createImage:
            return try await client.messageBuilder.buildWithContent(makeImageWithContentRequest(
                conversationId: conversationId,
                payload: payload
            ))
        case .createVideo:
            return try await client.messageBuilder.buildVideo(makeVideoBuildRequest(
                conversationId: conversationId,
                payload: payload
            ))
        case .createAudio:
            return try await client.messageBuilder.buildWithContent(makeAudioWithContentRequest(
                conversationId: conversationId,
                payload: payload
            ))
        case .createFile:
            let fileId = payloadString(payload, "fileId", default: "demo-file")
            var data: [String: Any] = [
                "fileId": fileId,
                "name": payloadString(payload, "fileName", default: "report.pdf")
            ]
            if let url = payloadOptionalString(payload, "url") { data["url"] = url }
            if let mimeType = payloadOptionalString(payload, "mimeType") { data["mimeType"] = mimeType }
            if let size = payloadUInt64(payload, "size") { data["size"] = size }
            return try await client.messageBuilder.buildWithContent(BuildWithContentMessageRequest(
                conversationId: conversationId,
                content: MessageContent(contentType: .file, data: sendableMap(data))
            ))
        case .createLinkCard:
            return try await client.messageBuilder.buildLinkCard(BuildLinkCardMessageRequest(
                conversationId: conversationId,
                url: payloadString(payload, "url", default: "https://flare.local"),
                title: payloadString(payload, "title", default: "Flare Link"),
                description: payloadString(payload, "description", default: "Link card from Apple SDK"),
                thumbnailUrl: payloadString(payload, "thumbnailUrl", default: ""),
                siteName: payloadString(payload, "siteName", default: "Flare")
            ))
        case .createMiniProgram:
            return try await client.messageBuilder.buildMiniProgram(BuildMiniProgramMessageRequest(
                conversationId: conversationId,
                appId: payloadString(payload, "appId", default: "flare-mini"),
                pagePath: payloadString(payload, "pagePath", default: "/"),
                title: payloadString(payload, "title", default: "Flare Mini Program"),
                thumbnailUrl: payloadString(payload, "thumbnailUrl", default: ""),
                extra: ["source": "ios-example"]
            ))
        case .createForward:
            // 必须传**完整消息**而不是 id 存根：转发载荷要把原文嵌进去，
            // 核心侧的 forward_item_from_source 会读 content / senderId / conversationId。
            // 早先按 ForwardSourceMessage 传，反序列化成 IMMessage 时缺必填字段直接
            // INVALID_PARAMETER，转发每次都失败；契约已改成 Message，这里没跟上，
            // 结果整个 app 编译不过。
            guard let source = selectedMessages.last else {
                throw FlareSdkException(
                    code: "invalid_parameter",
                    message: String(localized: "Select a message to forward first."),
                    operation: "message_builder.create_forward"
                )
            }
            return try await client.messageBuilder.buildForward(BuildForwardMessageRequest(
                conversationId: conversationId,
                merge: true,
                title: payloadString(payload, "title", default: "转发消息"),
                sourceMessages: [source.core]
            ))
        case .createQuote:
            let quotedTextPreview = payloadString(payload, "quotedTextPreview", default: selectedMessages.last?.previewText ?? "")
            let quotedContent = selectedMessages.last?.content
                ?? MessageContent(contentType: .text, data: ["text": AnySendable(quotedTextPreview)])
            return try await client.messageBuilder.buildQuote(BuildQuoteMessageRequest(
                conversationId: conversationId,
                quotedMessageId: payloadString(payload, "quotedMessageId", default: selectedMessages.last?.serverId ?? ""),
                text: payloadString(payload, "text", default: "Quoted from Apple SDK Lab"),
                quotedSenderId: payloadString(payload, "quotedSenderId", default: selectedMessages.last?.senderId ?? ""),
                quotedTextPreview: quotedTextPreview,
                quotedContent: quotedContent
            ))
        case .createTask:
            return try await client.messageBuilder.buildTask(BuildTaskMessageRequest(
                conversationId: conversationId,
                taskId: payloadString(payload, "taskId", default: "task-\(Date().timeIntervalSince1970)"),
                title: payloadString(payload, "title", default: "Task"),
                status: payloadString(payload, "status", default: "todo"),
                participantUserIds: payloadStringArray(payload, "participantUserIds")
            ))
        case .createVote:
            return try await client.messageBuilder.buildVote(BuildVoteMessageRequest(
                conversationId: conversationId,
                voteId: payloadString(payload, "voteId", default: "vote-\(Date().timeIntervalSince1970)"),
                title: payloadString(payload, "title", default: "Vote"),
                options: payloadStringArray(payload, "options", default: ["A", "B"]),
                participantUserIds: payloadStringArray(payload, "participantUserIds")
            ))
        case .createSchedule:
            let start = Int64(Date().addingTimeInterval(1800).timeIntervalSince1970 * 1000)
            return try await client.messageBuilder.buildSchedule(BuildScheduleMessageRequest(
                conversationId: conversationId,
                scheduleId: payloadString(payload, "scheduleId", default: "schedule-\(Date().timeIntervalSince1970)"),
                title: payloadString(payload, "title", default: "Schedule"),
                startTimeMs: Int64(payloadInt(payload, "startTimeMs", default: Int(start))),
                endTimeMs: Int64(payloadInt(payload, "endTimeMs", default: Int(start + 3_600_000))),
                participantUserIds: payloadStringArray(payload, "participantUserIds")
            ))
        case .createNotification:
            return try await client.messageBuilder.buildNotification(BuildNotificationMessageRequest(
                conversationId: conversationId,
                title: payloadString(payload, "title", default: "Notification"),
                body: payloadString(payload, "body", default: "Notification from Apple SDK")
            ))
        case .createAnnouncement:
            return try await client.messageBuilder.buildAnnouncement(BuildAnnouncementMessageRequest(
                conversationId: conversationId,
                title: payloadString(payload, "title", default: "Announcement"),
                body: payloadString(payload, "body", default: "Announcement from Apple SDK")
            ))
        case .createPlaceholder:
            return try await client.messageBuilder.buildPlaceholder(BuildPlaceholderMessageRequest(
                conversationId: conversationId,
                reason: payloadString(payload, "reason", default: "Capability unavailable")
            ))
        default:
            throw AppStoreError(message: "Builder op \(op.rawValue) is not wired in the Apple example yet")
        }
    }

    // MARK: - Typed media build requests (also exercised directly by tests)

    static func makeImageBuildRequest(conversationId: String, payload: [String: Any]) -> BuildImageMessageRequest {
        let imageId = payloadStringValue(payload, "imageId", default: "demo-image")
        let source = mediaSourceInfo(
            uuid: imageId,
            imageId: imageId,
            url: payloadMediaURL(payload),
            mimeType: payloadOptionalStringValue(payload, "mimeType"),
            size: payloadUInt64Value(payload, "size"),
            width: payloadOptionalInt32Value(payload, "width"),
            height: payloadOptionalInt32Value(payload, "height")
        )
        return BuildImageMessageRequest(
            conversationId: conversationId,
            imageId: imageId,
            payload: ImageContentPayload(
                imageId: imageId,
                source: source,
                description: payloadStringValue(payload, "description", default: "")
            )
        )
    }

    static func makeImageWithContentRequest(conversationId: String, payload: [String: Any]) -> BuildWithContentMessageRequest {
        let request = makeImageBuildRequest(conversationId: conversationId, payload: payload)
        let imageId = request.imageId
        var data: [String: Any] = [
            "imageId": imageId,
            "description": request.payload?.description ?? ""
        ]
        if let source = request.payload?.source {
            data["source"] = mediaSourcePayload(source)
        }
        if let thumbnail = request.payload?.thumbnail {
            data["thumbnail"] = mediaSourcePayload(thumbnail)
        }
        return BuildWithContentMessageRequest(
            conversationId: conversationId,
            content: MessageContent(contentType: .image, data: sendableMap(data))
        )
    }

    static func makeVideoBuildRequest(conversationId: String, payload: [String: Any]) -> BuildVideoMessageRequest {
        let videoId = payloadStringValue(payload, "videoId", default: "demo-video")
        let source = mediaSourceInfo(
            uuid: videoId,
            url: payloadMediaURL(payload),
            mimeType: payloadOptionalStringValue(payload, "mimeType"),
            size: payloadUInt64Value(payload, "size"),
            width: payloadOptionalInt32Value(payload, "width"),
            height: payloadOptionalInt32Value(payload, "height"),
            durationMs: payloadOptionalInt32Value(payload, "durationMs")
        )
        return BuildVideoMessageRequest(
            conversationId: conversationId,
            videoId: videoId,
            payload: VideoContentPayload(
                videoId: videoId,
                source: source,
                description: payloadStringValue(payload, "description", default: "Video from Apple SDK")
            )
        )
    }

    static func makeAudioBuildRequest(conversationId: String, payload: [String: Any]) -> BuildAudioMessageRequest {
        let audioId = payloadStringValue(payload, "audioId", default: "demo-audio")
        let durationMs = payloadOptionalInt32Value(payload, "durationMs") ?? 18000
        let source = mediaSourceInfo(
            uuid: audioId,
            url: payloadMediaURL(payload),
            mimeType: payloadOptionalStringValue(payload, "mimeType"),
            size: payloadUInt64Value(payload, "size"),
            durationMs: durationMs
        )
        return BuildAudioMessageRequest(
            conversationId: conversationId,
            audioId: audioId,
            payload: AudioContentPayload(audioId: audioId, source: source, durationMs: durationMs)
        )
    }

    static func makeAudioWithContentRequest(conversationId: String, payload: [String: Any]) -> BuildWithContentMessageRequest {
        let request = makeAudioBuildRequest(conversationId: conversationId, payload: payload)
        let audioId = request.audioId
        var data: [String: Any] = [
            "audioId": audioId,
            "durationMs": request.payload?.durationMs ?? 0
        ]
        if let source = request.payload?.source {
            data["source"] = mediaSourcePayload(source)
        }
        return BuildWithContentMessageRequest(
            conversationId: conversationId,
            content: MessageContent(contentType: .audio, data: sendableMap(data))
        )
    }

    private static func mediaSourceInfo(
        uuid: String,
        imageId: String? = nil,
        url: String? = nil,
        mimeType: String? = nil,
        size: UInt64? = nil,
        width: Int32? = nil,
        height: Int32? = nil,
        durationMs: Int32? = nil
    ) -> MediaSourceInfo {
        MediaSourceInfo(
            uuid: uuid,
            imageId: imageId,
            url: url,
            mimeType: mimeType,
            size: size,
            width: width,
            height: height,
            durationMs: durationMs
        )
    }

    private static func mediaSourcePayload(_ source: MediaSourceInfo) -> [String: Any] {
        var data: [String: Any] = [:]
        if let uuid = source.uuid, !uuid.isEmpty { data["uuid"] = uuid }
        if let imageId = source.imageId, !imageId.isEmpty { data["imageId"] = imageId }
        if let url = source.url, !url.isEmpty { data["url"] = url }
        if let mimeType = source.mimeType, !mimeType.isEmpty { data["mimeType"] = mimeType }
        if let size = source.size { data["size"] = size }
        if let width = source.width { data["width"] = width }
        if let height = source.height { data["height"] = height }
        if let durationMs = source.durationMs { data["durationMs"] = durationMs }
        return data
    }

    // MARK: - Untyped payload accessors

    private static func sendableMap(_ data: [String: Any]) -> [String: AnySendable] {
        data.mapValues { AnySendable($0) }
    }

    static func payloadString(_ payload: [String: Any], _ key: String, default defaultValue: String) -> String {
        guard let value = payload[key] else { return defaultValue }
        if let text = value as? String { return text }
        return String(describing: value)
    }

    static func payloadOptionalString(_ payload: [String: Any], _ key: String) -> String? {
        payloadOptionalStringValue(payload, key)
    }

    private static func payloadStringValue(_ payload: [String: Any], _ key: String, default defaultValue: String) -> String {
        payloadString(payload, key, default: defaultValue)
    }

    private static func payloadOptionalStringValue(_ payload: [String: Any], _ key: String) -> String? {
        guard let value = payload[key] else { return nil }
        if let text = value as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return String(describing: value)
    }

    private static func payloadMediaURL(_ payload: [String: Any]) -> String? {
        for key in [
            "sourceUrl", "source_url",
            "mediaUrl", "media_url",
            "downloadUrl", "download_url",
            "accessUrl", "access_url",
            "tempUrl", "temp_url",
            "cdnUrl", "cdn_url",
            "url"
        ] {
            if let value = payloadOptionalStringValue(payload, key) {
                return value
            }
        }
        return nil
    }

    static func payloadDouble(_ payload: [String: Any], _ key: String, default defaultValue: Double) -> Double {
        guard let value = payload[key] else { return defaultValue }
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? String { return Double(value) ?? defaultValue }
        return defaultValue
    }

    static func payloadInt(_ payload: [String: Any], _ key: String, default defaultValue: Int) -> Int {
        guard let value = payload[key] else { return defaultValue }
        if let value = value as? Int { return value }
        if let value = value as? Double { return Int(value) }
        if let value = value as? String { return Int(value) ?? defaultValue }
        return defaultValue
    }

    private static func payloadOptionalInt32Value(_ payload: [String: Any], _ key: String) -> Int32? {
        guard let value = payload[key] else { return nil }
        if let value = value as? Int32 { return value }
        if let value = value as? Int { return Int32(exactly: value) }
        if let value = value as? Int64 { return Int32(exactly: value) }
        if let value = value as? UInt64 { return Int32(exactly: value) }
        if let value = value as? Double { return Int32(exactly: value) }
        if let value = value as? String { return Int32(value) }
        return nil
    }

    static func payloadUInt64(_ payload: [String: Any], _ key: String) -> UInt64? {
        payloadUInt64Value(payload, key)
    }

    private static func payloadUInt64Value(_ payload: [String: Any], _ key: String) -> UInt64? {
        guard let value = payload[key] else { return nil }
        if let value = value as? UInt64 { return value }
        if let value = value as? Int { return UInt64(exactly: value) }
        if let value = value as? Int32 { return UInt64(exactly: value) }
        if let value = value as? Int64 { return UInt64(exactly: value) }
        if let value = value as? UInt { return UInt64(value) }
        if let value = value as? Double { return UInt64(exactly: value) }
        if let value = value as? String { return UInt64(value) }
        return nil
    }

    static func payloadStringArray(_ payload: [String: Any], _ key: String, default defaultValue: [String] = []) -> [String] {
        guard let value = payload[key] else { return defaultValue }
        if let value = value as? [String] { return value }
        if let value = value as? String {
            let parts = value
                .split { $0 == "," || $0 == " " || $0 == "\n" }
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return parts.isEmpty ? defaultValue : parts
        }
        return defaultValue
    }

    private static func richDocJson(text: String) -> String {
        let children = text.components(separatedBy: .newlines).map { paragraph -> [String: Any] in
            var block: [String: Any] = [
                "type": "paragraph",
                "children": []
            ]
            if !paragraph.isEmpty {
                block["children"] = [[
                    "type": "text",
                    "text": paragraph
                ]]
            }
            return block
        }
        let document: [String: Any] = [
            "type": "doc",
            "version": 2,
            "children": children
        ]
        guard
            JSONSerialization.isValidJSONObject(document),
            let data = try? JSONSerialization.data(withJSONObject: document, options: []),
            let json = String(data: data, encoding: .utf8)
        else {
            return "{\"type\":\"doc\",\"version\":2,\"children\":[]}"
        }
        return json
    }
}
