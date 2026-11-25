import FlareCoreAppleSDK
import FlareIMUI
import SwiftUI
import UniformTypeIdentifiers

@main
struct FlareCoreDemo: App {
    var body: some Scene {
        WindowGroup { CoreWorkbench() }
    }
}

@MainActor
private struct CoreWorkbench: View {
    @State private var sdk: (any FlareImClientProtocol)?
    @State private var baseURL = ""
    @State private var websocketURL = ""
    @State private var quicURL = ""
    @State private var mediaURL = ""
    @State private var tenant = ""
    @State private var user = ""
    @State private var token = ""
    @State private var peer = ""
    @State private var draft = ""
    @State private var status = ""
    @State private var busy = false
    @State private var pickingFile = false
    @State private var conversations: [Conversation] = []
    @State private var conversation: Conversation?
    @State private var messages: [Message] = []
    @State private var subscriptions: [any EventSubscription] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Flare Core").font(.largeTitle)
                InputView(text: $baseURL, placeholder: "Core HTTP base URL")
                InputView(text: $websocketURL, placeholder: "WebSocket URL")
                InputView(text: $quicURL, placeholder: "QUIC URL (optional)")
                InputView(text: $mediaURL, placeholder: "Media base URL (optional)")
                if let sdk {
                    HStack {
                        ButtonView(label: "Apply endpoints", disabled: busy) { action {
                            let result = try await sdk.connection.replaceEndpoints(endpoints)
                            status = "Endpoint revision \(result.revision)"
                        } }
                        ButtonView(label: "Sign out", variant: .secondary, disabled: busy) { action { try await signOut(sdk) } }
                    }
                    InputView(text: $peer, placeholder: "Peer user ID")
                    ButtonView(label: "Open chat", disabled: busy || peer.isEmpty) { action {
                        conversation = try await sdk.conversations.getOneConversation([
                            "sourceId": AnySendable(peer), "conversationType": AnySendable("single")
                        ])
                        try await refresh(sdk)
                    } }
                    ForEach(conversations, id: \.conversationId) { row in
                        ButtonView(label: row.channelId, variant: .text, disabled: busy) { action {
                            conversation = row
                            try await refresh(sdk)
                        } }
                    }
                    ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                        Text("\(message.senderId): \(message.content?.data["text"]?.value as? String ?? "Message")")
                    }
                    if let conversation {
                        InputView(text: $draft, placeholder: "Message")
                        ButtonView(label: "Attach file", variant: .secondary, disabled: busy) { pickingFile = true }
                        ButtonView(label: "Send", disabled: busy || draft.isEmpty) { action {
                            let message = try await sdk.messageBuilder.buildText(.init(conversationId: conversation.conversationId, text: draft))
                            _ = try await sdk.messages.sendMessage(.init(message: message), callback: nil)
                            draft = ""
                            try await refresh(sdk)
                        } }
                    }
                } else {
                    InputView(text: $tenant, placeholder: "Tenant ID")
                    InputView(text: $user, placeholder: "User ID")
                    InputView(text: $token, placeholder: "Access token", secure: true)
                    ButtonView(label: "Sign in", loading: busy) { action { try await signIn() } }
                }
                if !status.isEmpty { Text(status).accessibilityAddTraits(.updatesFrequently) }
            }.padding()
        }
        .fileImporter(isPresented: $pickingFile, allowedContentTypes: [.data]) { result in
            guard let sdk, let conversation else { return }
            action {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let uploaded = try await sdk.media.uploadFile(["absolutePath": AnySendable(url.path)])
                guard let fileID = uploaded["fileId"]?.value as? String else { throw CocoaError(.fileReadUnknown) }
                let message = try await sdk.messageBuilder.buildFile(.init(conversationId: conversation.conversationId, fileId: fileID))
                _ = try await sdk.messages.sendMessage(.init(message: message), callback: nil)
                try await refresh(sdk)
            }
        }
    }

    private var endpoints: CoreEndpoints {
        func value(_ text: String) -> String? {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return CoreEndpoints(baseUrl: value(baseURL) ?? "", mediaBaseUrl: value(mediaURL),
                             quicUrl: value(quicURL), websocketUrl: value(websocketURL) ?? "")
    }

    private func action(_ operation: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do { status = ""; try await operation() }
            catch { status = error.localizedDescription }
        }
    }

    private func signIn() async throws {
        let client = try FlareCoreSdk.createClient()
        do {
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                      appropriateFor: nil, create: true)
            let path = support.appendingPathComponent("FlareCoreDemo", isDirectory: true)
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
            var endpointConfig = ["baseUrl": endpoints.baseUrl, "websocketUrl": endpoints.websocketUrl]
            endpointConfig["quicUrl"] = endpoints.quicUrl
            endpointConfig["mediaBaseUrl"] = endpoints.mediaBaseUrl
            try await client.`init`([
                "environment": AnySendable("production"),
                "sdkConfig": AnySendable(["dataUrl": path.absoluteString, "tenantId": tenant,
                    "endpoints": endpointConfig] as [String: Any]),
            ])
            try await client.login(["userId": AnySendable(user), "token": AnySendable(token)])
        } catch {
            try? await client.dispose()
            throw error
        }
        sdk = client
        token = ""
        subscriptions = [client.events.onMessageReceived { _ in
            Task { @MainActor in try? await refresh(client) }
        }, client.events.onMessageReceivedBatch { _ in
            Task { @MainActor in try? await refresh(client) }
        }]
        try await refresh(client)
    }

    private func signOut(_ client: any FlareImClientProtocol) async throws {
        try await client.logout()
        subscriptions.forEach { $0.unsubscribe() }
        subscriptions.removeAll()
        sdk = nil
        conversation = nil
        messages.removeAll()
        conversations.removeAll()
        try await client.dispose()
    }

    private func refresh(_ client: any FlareImClientProtocol) async throws {
        conversations = try await client.conversations.listConversations().conversations
        if let conversation {
            messages = try await client.messages.listMessages(.init(conversationId: conversation.conversationId, limit: 50))
                .messages.sorted { $0.conversationSeq < $1.conversationSeq }
        }
    }
}
