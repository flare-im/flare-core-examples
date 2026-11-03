import FlareCoreAppleSDK
import FlareIMUI
import SwiftUI

struct ConversationListView: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var environment: AppEnvironment
    var onOpenConversation: ((AppConversation) -> Void)?
    @State private var searchText = ""
    @State private var searchActive = false
    @State private var startSheetOpen = false
    @State private var moreSheetOpen = false
    @State private var actionConversation: AppConversation?
    @State private var actionSheetHeight: CGFloat = 500

    private var filtered: [AppConversation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return messaging.visibleConversations }
        return messaging.visibleConversations.filter { conversation in
            [
                conversation.appTitle,
                conversation.conversationId,
                conversation.channelId,
                conversation.appPreview
            ].contains { $0.lowercased().contains(query) }
        }
    }

    private var displayedConversations: [AppConversation] {
        filtered.filter(\.isPinned) + filtered.filter { !$0.isPinned }
    }

    private var availableFilters: [ConversationFilter] {
        [.all, .unread, .mentions]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            filterTabs
            Divider()
            content
        }
        .background(FlareDesign.surface)
        .refreshable {
            await messaging.refreshConversations()
        }
        .onAppear {
            if !availableFilters.contains(environment.filter) {
                environment.filter = .all
            }
        }
        .sheet(isPresented: $startSheetOpen) {
            StartConversationSheet(onConversationOpened: { conversation in
                onOpenConversation?(conversation)
            })
                .presentationDetents([.height(330), .medium])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $moreSheetOpen) {
            MoreActionsSheet(
                onStartConversation: {
                    moreSheetOpen = false
                    startSheetOpen = true
                }
            )
            .presentationDetents([.height(380), .medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $actionConversation) { conversation in
            ConversationActionSheet(
                conversation: conversation,
                onOpen: {
                    actionConversation = nil
                    open(conversation)
                },
                onAction: { action in
                    runConversationAction(action, for: conversation)
                },
                onHeightChange: { height in
                    // Size the sheet to its content. A fixed 500pt detent cut the last row
                    // ("Clear local history") off at the sheet edge.
                    actionSheetHeight = min(max(height, 280), 760)
                }
            )
            .presentationDetents([.height(actionSheetHeight), .large])
            .presentationDragIndicator(.hidden)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: FlareDesign.Spacing.lg) {
            HStack(alignment: .center, spacing: FlareDesign.Spacing.md) {
                AvatarView(title: currentUserTitle, imageURL: "", size: 54)
                VStack(alignment: .leading, spacing: FlareDesign.Spacing.xs) {
                    Text(currentUserTitle)
                        .font(.system(size: FlareSizes.fontSize4xl, weight: .bold))
                        .foregroundStyle(FlareDesign.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: FlareDesign.Spacing.xs) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 7, height: 7)
                        Text("Flare IM · \(connectionLabel)")
                            .font(.subheadline)
                            .foregroundStyle(FlareDesign.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                CircleIconButton(icon: "search", tint: FlareDesign.textSecondary) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        searchActive.toggle()
                    }
                }
                .accessibilityLabel(String(localized: "Search conversations"))
                CircleIconButton(icon: "add", tint: .white, fill: FlareDesign.brand) {
                    startSheetOpen = true
                }
                .accessibilityLabel(String(localized: "New conversation"))
            }

            if searchActive {
                HStack(spacing: FlareDesign.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(FlareDesign.textTertiary)
                    TextField("Search conversations", text: $searchText)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(FlareDesign.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, FlareDesign.Spacing.md)
                .frame(height: 40)
                .background(FlareDesign.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: FlareDesign.radius, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, FlareDesign.Spacing.lg)
        .padding(.top, FlareDesign.Spacing.lg)
        .padding(.bottom, FlareDesign.Spacing.sm)
        .background(FlareDesign.surface)
    }

    private var filterTabs: some View {
        HStack(spacing: FlareDesign.Spacing.sm) {
            Button {
                moreSheetOpen = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: FlareSizes.fontSize2xl, weight: .bold))
                    .foregroundStyle(FlareDesign.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(FlareDesign.surfaceAlt)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More conversation filters")

            FilterTabsView(
                options: availableFilters.map { FlareFilterTabOption(value: $0.id, label: filterTitle(for: $0)) },
                selection: filterSelectionBinding
            )
        }
        .padding(.horizontal, FlareDesign.Spacing.lg)
        .padding(.bottom, FlareDesign.Spacing.md)
        .background(FlareDesign.surface)
    }

    @ViewBuilder
    private var content: some View {
        // kit 的 ConversationListContainerView 统一 loading / error / offline 外壳；
        // 空态与每一行仍由 app 构建（ConversationRowAdapter 保留 contextMenu/滑动/点击附能）。
        FlareIMUI.ConversationListContainerView(state: FlareApplicationViewState(status: .ready)) {
            if displayedConversations.isEmpty {
                FlareIMUI.EmptyStateView(
                    title: searchText.isEmpty ? String(localized: "No conversations") : String(localized: "No matching conversations"),
                    description: searchText.isEmpty ? String(localized: "Tap the plus button to open a conversation") : String(localized: "Try a different keyword"),
                    actionText: String(localized: "Start a conversation"),
                    icon: "chats",
                    onAction: { startSheetOpen = true }
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(displayedConversations) { conversation in
                            ConversationRowAdapter(
                                conversation: conversation,
                                active: messaging.selectedConversation?.conversationId == conversation.conversationId,
                                onOpen: { open(conversation) },
                                onActions: { actionConversation = conversation }
                            )
                            .contextMenu { conversationMenu(conversation) }
                        }
                    }
                    .padding(EdgeInsets(top: FlareDesign.Spacing.sm, leading: 0, bottom: 28, trailing: 0))
                }
            }
        }
        .background(FlareDesign.surface)
    }

    private var pinnedCount: Int {
        messaging.allConversations.filter(\.isPinned).count
    }

    private var connectionLabel: String {
        switch messaging.runtimeStatus {
        case .ready: return String(localized: "ready")
        case .loading: return String(localized: "connecting")
        case .offline: return String(localized: "offline")
        case .error, .unavailable: return String(localized: "attention")
        case .idle: return String(localized: "idle")
        }
    }

    private var currentUserTitle: String {
        let userId = messaging.currentUserId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return userId.isEmpty ? "Flare IM" : userId
    }

    private var statusColor: Color {
        switch messaging.runtimeStatus {
        case .ready: return FlareDesign.success
        case .loading: return FlareDesign.warning
        case .offline, .idle: return FlareDesign.textTertiary
        case .error, .unavailable: return FlareDesign.danger
        }
    }

    private var filterSelectionBinding: Binding<String> {
        Binding(
            get: { environment.filter.id },
            set: { value in
                guard let filter = availableFilters.first(where: { $0.id == value })
                    ?? ConversationFilter.allCases.first(where: { $0.id == value }) else { return }
                environment.filter = filter
                Task { await messaging.refreshConversations() }
            }
        )
    }

    private func filterTitle(for filter: ConversationFilter) -> String {
        switch filter {
        case .all:
            return String(localized: "Messages")
        case .unread:
            return String(localized: "Unread")
        case .mentions:
            return filter.title
        case .pinned, .archived, .muted, .drafts:
            return filter.title
        }
    }

    private func open(_ conversation: AppConversation) {
        if let onOpenConversation {
            onOpenConversation(conversation)
        } else {
            Task { await messaging.openConversation(conversation.conversationId) }
        }
    }

    @ViewBuilder
    private func conversationMenu(_ conversation: AppConversation) -> some View {
        Button("Open") {
            open(conversation)
        }
        Button(conversation.isPinned ? "Unpin" : "Pin") {
            runConversationAction("pin", for: conversation)
        }
        Button(conversation.isMuted ? "Unmute" : "Mute") {
            runConversationAction("mute", for: conversation)
        }
        Button(conversation.isArchived ? "Unarchive" : "Archive") {
            runConversationAction("archive", for: conversation)
        }
        Button("Mark as unread") {
            runConversationAction("unread", for: conversation)
        }
        Divider()
        Button("Clear local history", role: .destructive) {
            runConversationAction("clear", for: conversation)
        }
        Button("Delete conversation", role: .destructive) {
            runConversationAction("delete", for: conversation)
        }
    }

    private func runConversationAction(_ action: String, for conversation: AppConversation) {
        Task { await messaging.conversationAction(action, conversation: conversation) }
    }
}

private struct CircleIconButton: View {
    let icon: String
    var tint: Color
    var fill: Color = FlareDesign.surfaceAlt
    let action: () -> Void

    var body: some View {
        FlareIMUI.IconButtonView(
            icon: icon,
            accessibilityLabel: icon,
            tint: tint,
            background: fill,
            customSize: 46,
            action: action
        )
    }
}

private struct ConversationRowAdapter: View {
    let conversation: AppConversation
    let active: Bool
    var onOpen: () -> Void
    var onActions: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            FlareIMUI.ConversationRowView(item: rowData, active: active, onSelect: { _ in onOpen() }, onLongPress: { _ in onActions() })
            FlareIMUI.IconButtonView(icon: "more",
                                    accessibilityLabel: String(localized: "Conversation actions"),
                                    customSize: FlareSizes.touchTarget, action: onActions)
        }
    }

    // The host maps SDK fields and actions; the kit owns row presentation.
    private var rowData: FlareIMUI.ConversationRowData {
        FlareIMUI.ConversationRowData(
            id: conversation.id,
            title: conversation.appTitle,
            avatarURL: conversation.avatarUrl,
            preview: previewText,
            timestampLabel: displayDate,
            unreadCount: Int(conversation.unreadCount),
            pinned: conversation.isPinned,
            muted: conversation.isMuted,
            mentioned: conversation.mentionMe || conversation.mentionCount > 0,
            draftPreview: isDraft ? conversation.draft : nil,
            tags: rowTags
        )
    }

    private var rowTags: [FlareIMUI.ConversationRowTag] {
        var tags: [FlareIMUI.ConversationRowTag] = []
        if conversation.conversationType == .group {
            tags.append(FlareIMUI.ConversationRowTag(text: String(localized: "Group"), tone: .info))
        }
        if let roleTag {
            tags.append(FlareIMUI.ConversationRowTag(text: roleTag, tone: .warning))
        }
        return tags
    }

    private var previewText: String {
        conversation.appPreview.isEmpty ? String(localized: "No messages") : conversation.appPreview
    }

    private var isDraft: Bool {
        conversation.draft?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var roleTag: String? {
        guard let role = conversation.role?.trimmingCharacters(in: .whitespacesAndNewlines), !role.isEmpty else {
            return nil
        }
        let lower = role.lowercased()
        if lower.contains("bot") || lower.contains("robot") {
            return String(localized: "Bot")
        }
        if lower.contains("official") {
            return String(localized: "Official")
        }
        return role.prefix(10).description
    }

    private var displayDate: String {
        guard let date = FlareFormatters.dateFromMillis(conversation.appSortTimestamp) else { return "" }
        let calendar = Calendar.current
        let formatter = DateFormatter()
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
            formatter.dateFormat = "M/d"
        } else {
            formatter.dateFormat = "yyyy/M/d"
        }
        return formatter.string(from: date)
    }
}

private struct ConversationActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let conversation: AppConversation
    let onOpen: () -> Void
    let onAction: (String) -> Void
    var onHeightChange: (CGFloat) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(spacing: FlareSizes.spacingSm) {
                FlareIMUI.ConversationActionSheetView(
                    conversation: .init(id: conversation.id, title: conversation.appTitle,
                                        pinned: conversation.isPinned, muted: conversation.isMuted,
                                        unreadCount: Int(conversation.unreadCount), archived: conversation.isArchived),
                    capabilities: .init(pin: true, mute: true, archive: true, delete: true),
                    onAction: { _, action in
                        switch action {
                        case .pin, .unpin: run("pin")
                        case .mute, .unmute: run("mute")
                        case .archive, .unarchive: run("archive")
                        case .delete: run("delete")
                        default: break
                        }
                    },
                    onClose: { dismiss() }
                )
                // Host actions the kit sheet has no entry for. They sit in one card on the same
                // surface and radius as the kit's action groups; as bare rows they read as a
                // second, unstyled menu under the first.
                VStack(spacing: 0) {
                    FlareIMUI.FlareSettingsRow(item: .init(key: "open", label: String(localized: "Open"),
                        icon: "forward", kind: .value), onSelect: { _ in dismiss(); onOpen() })
                    FlareIMUI.FlareSettingsRow(item: .init(key: "unread", label: String(localized: "Mark as unread"),
                        icon: "mark-unread", kind: .value), onSelect: { _ in run("unread") })
                    FlareIMUI.FlareSettingsRow(item: .init(key: "clear", label: String(localized: "Clear local history"),
                        icon: "clear-history", kind: .value, danger: true), onSelect: { _ in run("clear") })
                }
                .padding(.horizontal, FlareSizes.spacingMd)
                .padding(.vertical, FlareSizes.spacingXs)
                .background(RoundedRectangle(cornerRadius: FlareSizes.radius2xl, style: .continuous).fill(FlareDesign.surface))
                .padding(.horizontal, FlareSizes.spacingSm)
            }
            .padding(FlareSizes.spacingMd)
            .background(GeometryReader { proxy in
                Color.clear.preference(key: ConversationActionSheetHeightKey.self, value: proxy.size.height)
            })
        }
        .onPreferenceChange(ConversationActionSheetHeightKey.self) { onHeightChange($0) }
    }

    private func run(_ action: String) {
        dismiss()
        onAction(action)
    }
}

private struct ConversationActionSheetHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// App avatar → delegates to `FlareIMUI.AvatarView` (kit richer: renders the
/// remote image via AsyncImage with an initials fallback + identity-seeded pastel
/// tint, which the bespoke solid-fill version never did). App keeps its own
/// call-site signature (`title` / `imageURL` / `size`) and maps into the kit.
struct AvatarView: View {
    let title: String
    let imageURL: String
    var size: CGFloat = 40

    var body: some View {
        FlareIMUI.AvatarView(
            userId: title,
            displayName: title,
            avatarURL: imageURL.isEmpty ? nil : imageURL,
            size: size
        )
        .accessibilityLabel(title)
    }
}


private struct StartConversationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var messaging: MessagingViewModel
    var onConversationOpened: ((AppConversation) -> Void)?
    @State private var kind: StartConversationKind = .single
    @State private var peerUserId = ""
    @State private var groupUserIds = ""
    @State private var isOpening = false
    @State private var localError: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Open conversation")
                    .font(.headline.weight(.bold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: FlareSizes.fontSize2xl, weight: .medium))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, FlareDesign.Spacing.xl)
            .padding(.top, FlareDesign.Spacing.xl)
            .padding(.bottom, FlareDesign.Spacing.xl)

            VStack(alignment: .leading, spacing: FlareDesign.Spacing.lg) {
                VStack(alignment: .leading, spacing: FlareDesign.Spacing.sm) {
                    FormFieldView(label: kind == .single ? String(localized: "Peer ID") : String(localized: "Member IDs")) {
                        if kind == .single {
                            InputView(text: $peerUserId, placeholder: String(localized: "Enter the peer's real userId"))
                                .identifierInput()
                        } else {
                            InputView(text: $groupUserIds, placeholder: String(localized: "Enter member userIds separated by commas"))
                                .identifierInput()
                        }
                    }
                    Text(kind == .single ? "The conversation ID is generated automatically by the SDK via getOneConversation" : "The group conversation is generated automatically by the SDK via getGroupConversationByUserIds")
                        .font(.caption)
                        .foregroundStyle(FlareDesign.textTertiary)
                }

                VStack(alignment: .leading, spacing: FlareDesign.Spacing.sm) {
                    FormFieldView(label: String(localized: "Conversation type")) {
                        SegmentedControlView(
                            options: StartConversationKind.allCases.map(\.title),
                            selectedIndex: StartConversationKind.allCases.firstIndex(of: kind) ?? 0,
                            onSelect: { i in kind = StartConversationKind.allCases[i] }
                        )
                    }
                }
            }
            .padding(.horizontal, FlareDesign.Spacing.xl)

            if let validationMessage {
                InlineSheetBanner(
                    symbol: "info.circle.fill",
                    title: String(localized: "Needs adjustment"),
                    message: validationMessage,
                    tone: .warning
                )
                .padding(.horizontal, FlareDesign.Spacing.xl)
                .padding(.top, FlareDesign.Spacing.md)
            } else if let localError {
                InlineSheetBanner(
                    symbol: "exclamationmark.triangle.fill",
                    title: String(localized: "Couldn't open conversation"),
                    message: localError,
                    tone: .danger
                )
                .padding(.horizontal, FlareDesign.Spacing.xl)
                .padding(.top, FlareDesign.Spacing.md)
            }

            Spacer(minLength: 16)

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(FlareDesign.textSecondary)
                Button("Open") {
                    openConversation()
                }
                .font(.subheadline.weight(.bold))
                .buttonStyle(.borderedProminent)
                .tint(FlareDesign.brand)
                .disabled(!canOpen)
                .overlay {
                    if isOpening {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                }
                .opacity(isOpening ? 0.72 : 1)
                Spacer()
            }
            .padding(FlareDesign.Spacing.xl)
            .background(FlareDesign.surfaceAlt.opacity(0.55))
        }
        .background(FlareDesign.surface)
        .onAppear {
            peerUserId = messaging.startConversationDraft.peerUserId
            groupUserIds = messaging.startConversationDraft.groupUserIds
        }
    }

    private var trimmedPeer: String {
        peerUserId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var groupIds: [String] {
        groupUserIds
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var validationMessage: String? {
        switch kind {
        case .single:
            guard !trimmedPeer.isEmpty else { return nil }
            if trimmedPeer == messaging.currentUserId {
                return String(localized: "You can't start a direct chat with your own account; enter the peer's real userId.")
            }
            return nil
        case .group:
            if groupIds.contains(where: { $0 == messaging.currentUserId }) {
                return String(localized: "Only enter the other members' IDs; your own account is resolved from the server context.")
            }
            return nil
        }
    }

    private var canOpen: Bool {
        guard !isOpening, validationMessage == nil else { return false }
        switch kind {
        case .single:
            return !trimmedPeer.isEmpty
        case .group:
            return !groupIds.isEmpty
        }
    }

    private func openConversation() {
        localError = nil
        isOpening = true
        messaging.startConversationDraft.peerUserId = trimmedPeer
        messaging.startConversationDraft.groupUserIds = groupIds.joined(separator: ",")
        Task {
            let conversation: AppConversation?
            switch kind {
            case .single:
                conversation = await messaging.openPeerConversation()
            case .group:
                conversation = await messaging.openGroupConversation()
            }
            isOpening = false
            if let conversation {
                onConversationOpened?(conversation)
                dismiss()
            } else {
                localError = environment.lastError ?? String(localized: "Make sure the peer account exists, the local service is running, and the current protocol address is reachable.")
            }
        }
    }
}

private struct InlineSheetBanner: View {
    let symbol: String
    let title: String
    let message: String
    let tone: RuntimeTone

    var body: some View {
        HStack(alignment: .top, spacing: FlareDesign.Spacing.md) {
            Image(systemName: symbol)
                .font(.system(size: FlareSizes.fontSize2xl, weight: .bold))
                .foregroundStyle(iconColor)
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: FlareDesign.Spacing.xs) {
                Text(title)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(FlareDesign.textPrimary)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(FlareDesign.textSecondary)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
        }
        .padding(FlareDesign.Spacing.md)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: FlareDesign.radius, style: .continuous))
    }

    private var iconColor: Color {
        switch tone {
        case .danger: return FlareDesign.danger
        case .warning: return FlareDesign.warning
        case .success: return FlareDesign.success
        default: return FlareDesign.brand
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .danger: return FlareDesign.danger.opacity(0.10)
        case .warning: return FlareDesign.warning.opacity(0.12)
        case .success: return FlareDesign.success.opacity(0.12)
        default: return FlareDesign.brandSoft
        }
    }
}

private struct MoreActionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var environment: AppEnvironment
    let onStartConversation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("More")
                .font(.headline.weight(.bold))
                .padding(.horizontal, FlareDesign.Spacing.xl)
                .padding(.top, FlareDesign.Spacing.xl)
                .padding(.bottom, FlareDesign.Spacing.lg)

            HStack(spacing: FlareDesign.Spacing.md) {
                AvatarView(title: messaging.currentUserId ?? "F", imageURL: "", size: 44)
                VStack(alignment: .leading, spacing: FlareDesign.Spacing.xxs) {
                    Text("Current account")
                        .font(.caption)
                        .foregroundStyle(FlareDesign.textTertiary)
                    Text(messaging.currentUserId ?? "-")
                        .font(.headline.weight(.bold))
                }
                Spacer()
                StatusPill(text: connectionLabel, tone: messaging.runtimeStatus.productTone)
            }
            .padding(FlareDesign.Spacing.lg)
            .background(FlareDesign.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: FlareDesign.radius, style: .continuous))
            .padding(.horizontal, FlareDesign.Spacing.lg)
            .padding(.bottom, FlareDesign.Spacing.md)

            ActionRow(symbol: "plus", title: String(localized: "New conversation"), tint: FlareDesign.brand, action: onStartConversation)
            ActionRow(symbol: "arrow.triangle.2.circlepath", title: String(localized: "Fetch from server"), tint: FlareDesign.brand) {
                dismiss()
                Task { await messaging.refreshConversations() }
            }
            Divider().padding(.horizontal, FlareDesign.Spacing.lg).padding(.vertical, FlareDesign.Spacing.sm)
            ActionRow(symbol: "info.circle", title: String(localized: "SDK Status"), tint: FlareDesign.brand) {
                environment.section = .sdkLab
                dismiss()
            }
            ActionRow(symbol: "gearshape", title: String(localized: "Settings"), tint: FlareDesign.brand) {
                environment.section = .settings
                dismiss()
            }
            ActionRow(symbol: "rectangle.portrait.and.arrow.right", title: String(localized: "Logout"), tint: FlareDesign.danger) {
                dismiss()
                Task { await messaging.logout() }
            }
            Spacer()
        }
        .background(FlareDesign.surface)
    }

    private var connectionLabel: String {
        messaging.runtimeStatus == .ready ? "Ready" : messaging.runtimeStatus.productLabel
    }
}

private struct ActionRow: View {
    let symbol: String
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FlareDesign.Spacing.lg) {
                Image(systemName: symbol)
                    .font(.system(size: FlareSizes.fontSize2xl, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint == FlareDesign.danger ? FlareDesign.danger : FlareDesign.textPrimary)
                Spacer()
            }
            .padding(.horizontal, FlareDesign.Spacing.xl)
            .padding(.vertical, FlareDesign.Spacing.md)
        }
        .buttonStyle(.plain)
    }
}

struct ConversationDetailsPanel: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var environment: AppEnvironment
    let conversation: AppConversation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FlareDesign.Spacing.xl) {
                HStack(alignment: .top, spacing: FlareDesign.Spacing.md) {
                    AvatarView(title: conversation.appTitle, imageURL: conversation.avatarUrl, size: 44)
                    VStack(alignment: .leading, spacing: FlareDesign.Spacing.xs) {
                        Text(conversation.appTitle)
                            .font(.title3.weight(.bold))
                        Text(conversation.conversationId)
                            .font(.caption.monospaced())
                            .foregroundStyle(FlareDesign.textSecondary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    Button {
                        environment.detailsOpen = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                }

                StatusBanner(status: messaging.runtimeStatus, error: messaging.lastError)
                actionGrid

                KeyValueRows(values: [
                    (String(localized: "Type"), conversation.conversationType.rawValue),
                    (String(localized: "Channel"), conversation.channelId),
                    (String(localized: "Members"), "\(conversation.membersCount)"),
                    (String(localized: "Unread"), "\(conversation.unreadCount)"),
                    (String(localized: "Mention count"), "\(conversation.mentionCount)"),
                    (String(localized: "Pinned"), String(conversation.isPinned)),
                    (String(localized: "Muted"), String(conversation.isMuted)),
                    (String(localized: "Archived"), String(conversation.isArchived)),
                    (String(localized: "Draft"), conversation.draft ?? ""),
                    (String(localized: "Role"), conversation.role ?? ""),
                    (String(localized: "Version"), "\(conversation.version)"),
                    (String(localized: "Last read seq"), "\(conversation.lastReadSeq)"),
                    (String(localized: "Max seq"), "\(conversation.maxSeq)")
                ])
                .padding(FlareDesign.Spacing.md)
            }
            .padding(FlareDesign.Spacing.lg)
        }
        .background(FlareDesign.appBackground)
    }

    private var actionGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: FlareDesign.Spacing.sm)], spacing: FlareDesign.Spacing.sm) {
            Button(conversation.isPinned ? "Unpin" : "Pin") {
                Task { await messaging.conversationAction("pin", conversation: conversation) }
            }
            Button(conversation.isMuted ? "Unmute" : "Mute") {
                Task { await messaging.conversationAction("mute", conversation: conversation) }
            }
            Button(conversation.isArchived ? "Unarchive" : "Archive") {
                Task { await messaging.conversationAction("archive", conversation: conversation) }
            }
            Button("Sync") {
                Task { await messaging.syncSelectedConversation() }
            }
            Button("Mark unread") {
                Task { await messaging.conversationAction("unread", conversation: conversation) }
            }
            Button("Clear local", role: .destructive) {
                Task { await messaging.conversationAction("clear", conversation: conversation) }
            }
        }
        .buttonStyle(.bordered)
    }
}
