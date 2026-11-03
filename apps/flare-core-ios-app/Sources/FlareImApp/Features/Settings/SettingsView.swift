import FlareIMUI
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsViewModel
    @Environment(\.flareFeedback) private var feedback

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FlareDesign.Spacing.xl) {
                SectionHeader(title: "Settings", subtitle: "Runtime controls, theme, diagnostics, and session cleanup.")

                VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
                    Text("Appearance")
                        .font(.headline)
                    Picker("Theme", selection: settings.themeChoice) {
                        ForEach(ThemeChoice.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(FlareDesign.Spacing.lg)

                VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
                    Text("Login Defaults")
                        .font(.headline)
                    TextField("User id", text: settings.draftBinding(\.userId))
                        .textFieldStyle(.roundedBorder)
                        .identifierInput()
                    TextField("WebSocket URL", text: settings.draftBinding(\.wsUrl))
                        .textFieldStyle(.roundedBorder)
                        .identifierInput()
                    TextField("Tenant", text: settings.draftBinding(\.tenantId))
                        .textFieldStyle(.roundedBorder)
                        .identifierInput()
                    // 网关 HTTP 基址：SDK 向它签发接入 token 并自动刷新；客户端从不持有签名密钥。
                    TextField("Gateway HTTP URL", text: settings.draftBinding(\.httpUrl))
                        .textFieldStyle(.roundedBorder)
                        .identifierInput()
                    // 应用托管：直接填业务后端签好的 token，SDK 原样使用；留空则 SDK 托管，向网关签发并自动刷新。
                    TextField("Access token (optional)", text: settings.draftBinding(\.tokenOverride))
                        .textFieldStyle(.roundedBorder)
                        .identifierInput()
                    Text("Leave empty to let the SDK request and refresh credentials from the gateway.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(FlareDesign.Spacing.lg)

                VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
                    Text("Session")
                        .font(.headline)
                    KeyValueRows(values: [
                        ("User", settings.currentUserId ?? ""),
                        ("Connection", settings.connectionState.rawValue),
                        ("Runtime", settings.runtimeStatus.title)
                    ])
                    HStack {
                        ButtonView(label: "Refresh diagnostics", variant: .secondary) { Task { await settings.refreshDiagnostics() } }
                        ButtonView(label: "Logout", variant: .secondary) { Task { await settings.logout() } }
                        ButtonView(label: "Dispose", variant: .danger) { Task { await settings.dispose() } }
                    }

                }
                .padding(FlareDesign.Spacing.lg)

                // Where "save" puts pictures, videos and files. An iOS app can only write its own folders (another
                // one needs a security-scoped bookmark per pick), so the location is shown, not chosen; the default
                // comes back only if a custom folder is somehow set.
                VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
                    Text("Download location")
                        .font(.headline)
                    Text(settings.downloadLocation?.label ?? "—")
                        .font(.body.weight(.semibold))
                    Text("Saved pictures, videos and files go here. Open the Files app to find them.")
                        .font(.caption)
                        .foregroundStyle(FlareDesign.textSecondary)
                    if let folder = settings.downloadLocation?.directory {
                        Text(folder)
                            .font(.caption2)
                            .foregroundStyle(FlareDesign.textTertiary)
                            .textSelection(.enabled)
                    }
                    if settings.downloadLocation?.isCustom == true {
                        ButtonView(label: String(localized: "Use the default location"), variant: .secondary) {
                            Task {
                                if await !settings.resetDownloadLocation() {
                                    feedback?.toast(MediaSaveCopy.unwritable, tone: .danger)
                                }
                            }
                        }
                    }
                }
                .padding(FlareDesign.Spacing.lg)
                .task { await settings.refreshDownloadLocation() }

                VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
                    Text("Image and file cache")
                        .font(.headline)
                    Text("Usage: \(settings.cacheStats ?? "—")")
                        .foregroundStyle(FlareDesign.textSecondary)
                    HStack {
                        ForEach([Int64(128), 256, 512], id: \.self) { mb in
                            ButtonView(label: "\(mb)MB", variant: .secondary) {
                                Task {
                                    if await !settings.setCacheMaxBytes(mb * 1024 * 1024) {
                                        feedback?.toast(String(localized: "The operation failed."), tone: .danger)
                                    }
                                }
                            }
                        }
                    }
                    HStack {
                        ButtonView(label: String(localized: "Refresh"), variant: .secondary) { Task { await settings.refreshCacheStats() } }
                        ButtonView(label: String(localized: "Clear cache"), variant: .danger) { confirmClearCache() }
                    }
                }
                .padding(FlareDesign.Spacing.lg)
                .task { await settings.refreshCacheStats() }
            }
            .padding(FlareDesign.Spacing.xl)
        }
        .background(FlareDesign.appBackground)
    }

    /// Clearing cannot be undone, so it is asked first (kit confirmation; the clear runs inside it and a failure
    /// keeps it open to retry). Pictures that were seen are downloaded again afterwards.
    private func confirmClearCache() {
        Task {
            let cleared = await feedback?.confirm(FlareConfirmOptions(
                title: String(localized: "Clear cache"),
                description: String(localized: "Pictures you have seen will be downloaded again."),
                target: settings.cacheStats,
                confirmText: String(localized: "Clear cache"),
                action: {
                    if await !settings.clearCache() {
                        throw MediaCacheClearError()
                    }
                }))
            if cleared == true { feedback?.toast(String(localized: "Cache cleared"), tone: .success) }
        }
    }
}

/// The confirmation's failure line when the core could not clear its cache.
private struct MediaCacheClearError: LocalizedError {
    var errorDescription: String? { String(localized: "Could not clear the cache. Try again.") }
}
