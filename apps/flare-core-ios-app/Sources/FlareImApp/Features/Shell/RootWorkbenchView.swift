import FlareIMUI
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
            } else if sessionResumeAttempted {
                LoginView()
            }
        }
        .preferredColorScheme(colorScheme)
        .disabled(environment.isBusy)
        .overlay {
            if environment.isBusy {
                ToastView(message: String(localized: "Loading"), variant: .loading)
            }
        }
        .task {
            guard !sessionResumeAttempted else { return }
            await store.resumeSavedSession()
            sessionResumeAttempted = true
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

private struct WorkbenchView: View {
    @EnvironmentObject private var search: SearchViewModel
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var environment: AppEnvironment
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
                    .init(id: "settings", label: String(localized: "Settings"), icon: "settings"),
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
