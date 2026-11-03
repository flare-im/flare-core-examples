import FlareIMUI
import FlareCoreAppleSDK
import SwiftUI

struct SdkLabView: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var sdkLab: SdkLabViewModel
    @State private var tab: LabTab = .diagnostics

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
                SectionHeader(
                    title: "SDK Lab",
                    subtitle: "Coverage-driven probes for Apple SDK public API families."
                )
                Picker("Lab", selection: $tab) {
                    ForEach(LabTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(FlareDesign.Spacing.xl)
            .background(FlareDesign.surface)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: FlareDesign.Spacing.xl) {
                    content
                    LabResultsView()
                }
                .padding(FlareDesign.Spacing.xl)
            }
        }
        .background(FlareDesign.appBackground)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .diagnostics:
            DiagnosticsLab()
        case .lifecycle:
            LifecycleLab()
        case .conversations:
            ConversationLab()
        case .messages:
            MessageLab()
        case .media:
            MediaLab()
        case .capabilities:
            CapabilityLab()
        case .events:
            EventConsole()
        case .coverage:
            CoverageMatrix()
        }
    }
}

private struct DiagnosticsLab: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var sdkLab: SdkLabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
            HStack {
                SectionHeader(title: "Diagnostics")
                Spacer()
                Button("Refresh") { Task { await sdkLab.refreshDiagnostics() } }
                    .buttonStyle(.borderedProminent)
            }
            KeyValueRows(values: sdkLab.diagnostics.sorted(by: { $0.key < $1.key }).map { ($0.key, $0.value) })
                .padding(FlareDesign.Spacing.md)
            HStack {
                Button("Current presence") { Task { await sdkLab.runLabOperation("presence.current") } }
                Button("Batch presence + subscribe") { Task { await sdkLab.runLabOperation("presence.batch_subscribe") } }
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct LifecycleLab: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var sdkLab: SdkLabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
            SectionHeader(title: "Lifecycle, Auth, Connection")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: FlareDesign.Spacing.md)], spacing: FlareDesign.Spacing.md) {
                LabButton(title: "Update token", operation: "session.update_access_token")
                LabButton(title: "Disconnect", operation: "connection.disconnect")
                LabButton(title: "Uninit", operation: "session.uninit")
                LabButton(title: "Hard reset", operation: "session.hard_reset")
                LabButton(title: "Runtime health", operation: "diagnostics.runtime_health")
                LabButton(title: "Heartbeat interval", operation: "session.heartbeat_interval")
                LabButton(title: "Heartbeat foreground", operation: "session.heartbeat_app_state")
                LabButton(title: "Heartbeat NAT 120s", operation: "session.heartbeat_nat_timeout")
                LabButton(title: "Prepare session", operation: "session.prepare")
                LabButton(title: "Notify network", operation: "connection.notify_network_change")
                Button("Logout") { Task { await sdkLab.logout() } }
                Button("Dispose") { Task { await sdkLab.dispose() } }
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct ConversationLab: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var sdkLab: SdkLabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
            SectionHeader(title: "Conversations And Sync")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: FlareDesign.Spacing.md)], spacing: FlareDesign.Spacing.md) {
                Button("Bootstrap home") { Task { await messaging.bootstrapHome() } }
                Button("Refresh list") { Task { await messaging.refreshConversations() } }
                LabButton(title: "Paginated list", operation: "conversation.list_paginated")
                LabButton(title: "Raw list", operation: "conversation.list_raw")
                LabButton(title: "Sync summaries", operation: "sync.summaries")
                LabButton(title: "Bootstrap timeline op", operation: "conversation.bootstrap_home_timeline")
                Button("Sync selected") { Task { await messaging.syncSelectedConversation() } }
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct MessageLab: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var sdkLab: SdkLabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: FlareDesign.Spacing.lg) {
            HStack {
                SectionHeader(title: "Messages And Builder")
                Spacer()
                Button("Refresh catalog") { Task { await sdkLab.refreshBuilderCatalog() } }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: FlareDesign.Spacing.md)], spacing: FlareDesign.Spacing.md) {
                LabButton(title: "Get raw message", operation: "message.get_raw")
                LabButton(title: "Send no OSS", operation: "message.send_no_oss")
                LabButton(title: "Read and burn", operation: "message.mark_read_burn")
                LabButton(title: "Mark with color", operation: "message.mark_color")
                LabButton(title: "Normalize markdown", operation: "message_builder.normalize_markdown")
                LabButton(title: "Normalize HTML", operation: "message_builder.normalize_html")
                LabButton(title: "Normalize docJSON", operation: "message_builder.normalize_docjson")
                Button("Build text") { Task { await messaging.buildAndSend(op: .createText, payload: ["text": "Hello from SDK Lab"]) } }
                Button("Build image") { Task { await messaging.buildAndSend(op: .createImage, payload: ["url": "https://example.test/image.png", "width": 640, "height": 360]) } }
                Button("Build file") { Task { await messaging.buildAndSend(op: .createFile, payload: ["fileId": "demo-file", "fileName": "report.pdf", "size": 4096]) } }
                Button("Build quote") { Task { await messaging.buildAndSend(op: .createQuote, payload: ["text": "Quoted from iOS Lab"]) } }
                Button("Build task") { Task { await messaging.buildAndSend(op: .createTask, payload: ["title": "Review SDK coverage", "done": false]) } }
                Button("Build vote") { Task { await messaging.buildAndSend(op: .createVote, payload: ["title": "Ship Apple example?", "options": ["Yes", "Also yes"]]) } }
                Button("Build placeholder") { Task { await messaging.buildAndSend(op: .createPlaceholder, payload: ["reason": "plugin unavailable"]) } }
            }
            .buttonStyle(.bordered)

            if sdkLab.builderCatalog.isEmpty {
                FlareIMUI.EmptyStateView(title: "No builder catalog loaded", description: "Refresh the catalog after login to inspect generated build operations.", icon: "file").frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minHeight: 220)
            } else {
                VStack(alignment: .leading, spacing: FlareDesign.Spacing.sm) {
                    Text("Builder Catalog")
                        .font(.headline)
                    ForEach(sdkLab.builderCatalog, id: \.op.rawValue) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: FlareDesign.Spacing.xxs) {
                                Text(entry.method)
                                    .font(.subheadline.weight(.semibold))
                                Text(entry.summary)
                                    .font(.caption)
                                    .foregroundStyle(FlareDesign.textSecondary)
                            }
                            Spacer()
                            Pill(text: entry.contentType.rawValue)
                            Pill(text: entry.stability, color: entry.stability == "stable" ? FlareDesign.success : FlareDesign.warning)
                        }
                        .padding(FlareDesign.Spacing.md)
                    }
                }
            }
        }
    }
}

private struct MediaLab: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var sdkLab: SdkLabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
            SectionHeader(title: "Media Center", subtitle: "URL, cache, downloads, and upload probes. Upload requires a local file path.")
            HStack {
                TextField("File id", text: $sdkLab.mediaLabDraft.fileId)
                    .textFieldStyle(.roundedBorder)
                TextField("File path", text: $sdkLab.mediaLabDraft.filePath)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                TextField("Cache max bytes", text: $sdkLab.mediaLabDraft.cacheMaxBytes)
                    .textFieldStyle(.roundedBorder)
                TextField("Download subfolder", text: $sdkLab.mediaLabDraft.downloadSubfolder)
                    .textFieldStyle(.roundedBorder)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: FlareDesign.Spacing.md)], spacing: FlareDesign.Spacing.md) {
                MediaButton(title: "Cache stats", operation: "media.cache_stats")
                MediaButton(title: "Configure cache", operation: "media.configure_cache")
                MediaButton(title: "Clear cache", operation: "media.clear_cache")
                MediaButton(title: "Get subfolder", operation: "media.get_subfolder")
                MediaButton(title: "Set subfolder", operation: "media.set_subfolder")
                MediaButton(title: "Resolve access", operation: "media.resolve")
                MediaButton(title: "Media URL", operation: "media.url")
                MediaButton(title: "Temp URL", operation: "media.temp_url")
                MediaButton(title: "Cache remote", operation: "media.cache_remote")
                MediaButton(title: "Saved path", operation: "media.saved_path")
                MediaButton(title: "Delete record", operation: "media.delete_record")
                MediaButton(title: "Cancel download", operation: "media.cancel_download")
                MediaButton(title: "Download", operation: "media.download")
                MediaButton(title: "Upload file", operation: "media.upload_file")
                MediaButton(title: "Upload image", operation: "media.upload_image")
                MediaButton(title: "Upload video", operation: "media.upload_video")
                MediaButton(title: "Delete file", operation: "media.delete_file")
            }
            .buttonStyle(.bordered)
        }
        // Every field here takes an id, a path or a number.
        .identifierInput()
    }
}

private struct CapabilityLab: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var sdkLab: SdkLabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
            SectionHeader(title: "Capabilities And Calls", subtitle: "Optional plugin operations stay explicit and diagnostic when unavailable.")
            HStack {
                TextField("User id", text: $sdkLab.capabilityLabDraft.userId)
                    .textFieldStyle(.roundedBorder)
                TextField("Capability", text: $sdkLab.capabilityLabDraft.capability)
                    .textFieldStyle(.roundedBorder)
                TextField("Operation", text: $sdkLab.capabilityLabDraft.operation)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                TextField("Call signal type", text: $sdkLab.capabilityLabDraft.callSignalType)
                    .textFieldStyle(.roundedBorder)
                TextField("Payload JSON", text: $sdkLab.capabilityLabDraft.payload)
                    .textFieldStyle(.roundedBorder)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: FlareDesign.Spacing.md)], spacing: FlareDesign.Spacing.md) {
                CapabilityButton(title: "List capabilities", operation: "capability.list")
                CapabilityButton(title: "List user", operation: "capability.list_user")
                CapabilityButton(title: "Dispatch", operation: "capability.dispatch")
                CapabilityButton(title: "Grant", operation: "capability.grant")
                CapabilityButton(title: "Revoke", operation: "capability.revoke")
                CapabilityButton(title: "Send call signal", operation: "capability.call_signal")
            }
            .buttonStyle(.bordered)
            KeyValueRows(values: [
                ("Capabilities", FlareFormatters.jsonPreview(sdkLab.capabilities)),
                ("User capabilities", FlareFormatters.jsonPreview(sdkLab.userCapabilities))
            ])
            .padding(FlareDesign.Spacing.md)
        }
        // Every field here takes an id, an operation name or JSON.
        .identifierInput()
    }
}

private struct EventConsole: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var sdkLab: SdkLabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
            HStack {
                SectionHeader(title: "Event Console")
                Spacer()
                LabButton(title: "Native subscribe", operation: "events.subscribe")
                LabButton(title: "Unsubscribe all", operation: "events.unsubscribe_all")
            }
            if sdkLab.eventLog.isEmpty {
                FlareIMUI.EmptyStateView(title: "No events yet", description: "Login, sync, send, or run capability probes to populate typed event logs.", icon: "diagnostics").frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minHeight: 220)
            } else {
                ForEach(sdkLab.eventLog) { event in
                    HStack(alignment: .top, spacing: FlareDesign.Spacing.md) {
                        Text(FlareFormatters.shortTime.string(from: event.time))
                            .font(.caption.monospaced())
                            .foregroundStyle(FlareDesign.textTertiary)
                        VStack(alignment: .leading, spacing: FlareDesign.Spacing.xxs) {
                            Text("\(event.domain).\(event.name)")
                                .font(.subheadline.weight(.semibold))
                            Text(event.detail)
                                .font(.caption)
                                .foregroundStyle(FlareDesign.textSecondary)
                                .textSelection(.enabled)
                        }
                        Spacer()
                    }
                    .padding(FlareDesign.Spacing.md)
                }
            }
        }
    }
}

private struct CoverageMatrix: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var sdkLab: SdkLabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
            SectionHeader(title: "API Coverage Matrix", subtitle: "Mirrors docs/sdk-api-coverage.md for the Apple example.")
            ForEach(sdkLab.coverageRows) { row in
                HStack(alignment: .top, spacing: FlareDesign.Spacing.md) {
                    VStack(alignment: .leading, spacing: FlareDesign.Spacing.xs) {
                        Text(row.family)
                            .font(.subheadline.weight(.bold))
                        Text(row.api)
                            .font(.caption)
                            .foregroundStyle(FlareDesign.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: FlareDesign.Spacing.xs) {
                        Pill(text: row.status, color: row.status.contains("Unavailable") ? FlareDesign.warning : FlareDesign.brand)
                        Text(row.entryPoint)
                            .font(.caption2)
                            .foregroundStyle(FlareDesign.textTertiary)
                    }
                }
                .padding(FlareDesign.Spacing.md)
            }
        }
    }
}

private struct LabResultsView: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var sdkLab: SdkLabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
            SectionHeader(title: "Operation Results")
            if sdkLab.labResults.isEmpty {
                Text("No lab operations yet.")
                    .font(.caption)
                    .foregroundStyle(FlareDesign.textSecondary)
            } else {
                ForEach(sdkLab.labResults) { result in
                    VStack(alignment: .leading, spacing: FlareDesign.Spacing.xs) {
                        HStack {
                            Text(result.operation)
                                .font(.caption.weight(.bold).monospaced())
                            Pill(text: result.status, color: result.status == "ok" ? FlareDesign.success : FlareDesign.danger)
                            Spacer()
                            Text(FlareFormatters.shortTime.string(from: result.time))
                                .font(.caption2)
                                .foregroundStyle(FlareDesign.textTertiary)
                        }
                        Text(result.detail)
                            .font(.caption.monospaced())
                            .foregroundStyle(FlareDesign.textSecondary)
                            .textSelection(.enabled)
                            .lineLimit(8)
                    }
                    .padding(FlareDesign.Spacing.md)
                }
            }
        }
    }
}

private struct LabButton: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var sdkLab: SdkLabViewModel
    let title: String
    let operation: String

    var body: some View {
        Button(title) { Task { await sdkLab.runLabOperation(operation) } }
    }
}

private struct MediaButton: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var sdkLab: SdkLabViewModel
    let title: String
    let operation: String

    var body: some View {
        Button(title) { Task { await sdkLab.runMediaLab(operation) } }
    }
}

private struct CapabilityButton: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var sdkLab: SdkLabViewModel
    let title: String
    let operation: String

    var body: some View {
        Button(title) { Task { await sdkLab.runCapabilityLab(operation) } }
    }
}
