import FlareIMUI
import FlarePlatformUpdate
import FlareUpdateUI
import SwiftUI

struct RootWorkbenchView: View {
    @EnvironmentObject private var store: FlareAppStore
    @EnvironmentObject private var environment: AppEnvironment
    @State private var sessionResumeAttempted = false

    var body: some View {
        ZStack {
            FlareDesign.appBackground.ignoresSafeArea()
            if store.isLoggedIn {
                WorkbenchView()
                    .overlay(alignment: .top) { ConnectionBanner() }
            } else if sessionResumeAttempted {
                LoginView()
            }
        }
        .flareDesignFollowsTheme()
        .preferredColorScheme(colorScheme)
        .disabled(environment.isBusy)
        .overlay {
            if environment.isBusy {
                ToastView(message: String(localized: "Loading"), variant: .loading)
            }
        }
        // The update prompt over everything, in either sign-in state.
        .flareUpdatePrompt(controller: store.updateCenter)
        // Resource packs over the built-in strings and colours, once they are read; nothing here waits for them.
        .flareUpdateResources(controller: store.updateCenter, locale: KitStrings.localeTag)
        .task {
            guard !sessionResumeAttempted else { return }
            await store.resumeSavedSession()
            sessionResumeAttempted = true
            // The update center reads through the client, which the resume brings up: it starts right after, signed in or not.
            store.updateCenter.install()
            // The app has no language of its own to switch: iOS restarts it for a new one.
            await store.updateCenter.setLocale(KitStrings.localeTag)
        }
    }

    private var colorScheme: ColorScheme? {
        switch environment.themeChoice {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// The connection notice over the signed-in workbench: the kit's ``ConnectionNoticeView`` reads the core SDK's
/// `connection://status` and decides what shows, when, and which action. 立即重试 asks the SDK for its next round now;
/// 重新登录 (kicked, expired) signs out locally and returns to sign-in.
private struct ConnectionBanner: View {
    @EnvironmentObject private var store: FlareAppStore

    var body: some View {
        ConnectionNoticeView(status: store.session.kitConnectionStatus, floating: true,
                             onRetry: { Task { try? await store.session.reconnectNow() } },
                             onSignIn: { Task { await store.logout() } },
                             onUpdate: { Task { await store.updateCenter.update() } })
            .padding(.horizontal, FlareSizes.spacingMd)
            .padding(.top, FlareSizes.spacingXs)
    }
}

private struct WorkbenchView: View {
    @EnvironmentObject private var search: SearchViewModel
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var updateCenter: FlareUpdateController
    @EnvironmentObject private var notifications: PushNotifications
    @Environment(\.flareStrings) private var strings
    @State private var mobileChatOpen = false

    var body: some View {
        GeometryReader { proxy in
            let mode = resolveApplicationResponsiveMode(width: proxy.size.width)
            let compact = mode == .mobile
            IMAppKitView(
                configuration: configuration,
                groups: navigationGroups,
                activeID: activeNavigationID,
                onNavigate: navigate,
                destination: { _ in
                    AnyView(
                        AppLayoutView(
                            activePane: compact && environment.section == .conversations && !mobileChatOpen
                                ? .primary
                                : environment.detailsOpen && detail != nil ? .detail : .content,
                            primary: environment.section == .conversations
                                ? AnyView(conversationList)
                                : nil,
                            content: AnyView(content(compact: compact)),
                            detail: detail
                        )
                    )
                }
            )
        }
        .onChange(of: environment.section) { section in
            if section != .conversations { mobileChatOpen = false }
        }
        .task {
            if messaging.allConversations.isEmpty {
                await messaging.refreshConversations()
            }
        }
        // 点通知打开的会话。冷启动时它在会话恢复之后才解析出来，工作台可能早已显示，也可能刚出现。
        .onAppear { openNotificationTap() }
        .onChange(of: notifications.openRequest) { _ in openNotificationTap() }
    }

    /// 切到消息、打开那个会话；手机上进聊天页。这个应用的时间线不支持定位到某条消息，只打开会话。
    private func openNotificationTap() {
        guard let request = notifications.takeOpenRequest() else { return }
        environment.section = .conversations
        Task { @MainActor in
            await messaging.openConversation(request.conversationId)
            // 会话打开了才进聊天页：打不开就留在列表上，不停在一个空的聊天页
            if messaging.selectedConversation?.conversationId == request.conversationId {
                mobileChatOpen = true
            }
        }
    }

    private var configuration: FlareIMAppConfiguration {
        var features = FlareApplicationFeatures()
        features.contacts = false
        features.groups = false
        features.calls = false
        features.media = false
        return FlareIMAppConfiguration(
            features: features,
            capabilities: FlareCapabilitySet(["reply", "media", "retry", "messageActions"])
        )
    }

    private var navigationGroups: [FlareApplicationNavigationGroup] {
        let unread = Int(messaging.allConversations.reduce(0) { $0 + $1.unreadCount })
        return [
            FlareApplicationNavigationGroup(
                id: "reference",
                items: [
                    .init(
                        id: "chats",
                        label: String(localized: "Messages"),
                        icon: "chats",
                        badge: unread > 0 ? .init(count: unread, label: "Unread conversations") : nil
                    ),
                    .init(id: "search", label: String(localized: "Search messages"), icon: "search"),
                    .init(id: "media", label: "Media", icon: "image", enabled: false),
                    .init(
                        id: "settings",
                        label: String(localized: "Settings"),
                        icon: "settings",
                        badge: updateCenter.status?.prompt == .badge ? .init(kind: .dot, label: strings.settingsRowBadge) : nil
                    ),
                    .init(id: "sdk-lab", label: String(localized: "SDK Status"), icon: "diagnostics")
                ]
            )
        ]
    }

    private var activeNavigationID: String {
        switch environment.section {
        case .conversations: return "chats"
        case .search: return "search"
        case .sdkLab: return "sdk-lab"
        case .settings: return "settings"
        }
    }

    private func navigate(_ id: String) {
        switch id {
        case "chats": environment.section = .conversations
        case "search": environment.section = .search
        case "settings": environment.section = .settings
        case "sdk-lab": environment.section = .sdkLab
        default: break
        }
    }

    private var conversationList: some View {
        ConversationListView { conversation in
            mobileChatOpen = true
            Task { await messaging.openConversation(conversation.conversationId) }
        }
    }

    @ViewBuilder
    private func content(compact: Bool) -> some View {
        switch environment.section {
        case .conversations:
            if let conversation = messaging.selectedConversation, !compact || mobileChatOpen {
                ChatView(
                    conversation: conversation,
                    showsBackButton: compact,
                    onBack: compact ? { mobileChatOpen = false } : {}
                )
            } else {
                EmptyStateView(
                    title: "Choose a conversation",
                    description: "Select a conversation to open its SDK-backed timeline.",
                    actionText: "Refresh",
                    icon: "chats",
                    onAction: { Task { await messaging.refreshConversations() } }
                )
            }
        case .search:
            SearchView(viewModel: search)
        case .sdkLab:
            SdkLabView()
        case .settings:
            SettingsView()
        }
    }

    private var detail: AnyView? {
        guard environment.detailsOpen,
              environment.section == .conversations,
              let conversation = messaging.selectedConversation else { return nil }
        return AnyView(ConversationDetailsPanel(conversation: conversation))
    }
}
