import FlareCoreAppleSDK
import FlareIMUI
import AVFoundation
import AVKit
import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var search: SearchViewModel
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.flareFeedback) private var feedback
    @Environment(\.openURL) private var openURL
    let conversation: AppConversation
    var showsBackButton = false
    var onBack: () -> Void = {}
    @State private var composerText = ""
    @State private var searchSheetOpen = false
    @State private var detailsSheetOpen = false
    @State private var actionMessage: AppMessage?
    @State private var mediaPreview: MediaPreview?
    @State private var loadOlderAnchorId: String?
    @State private var loadingOlderMessages = false
    @State private var timelineFollowsTail = true

    private static let timelineBottomAnchorId = "flare.timeline.bottom"
    private static let timelineTimeGapSeconds: TimeInterval = 5 * 60
    private static let foregroundSyncIntervalNs: UInt64 = 12_000_000_000

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    header
                    timeline
                        .frame(maxHeight: .infinity)
                    ComposerView(
                        text: $composerText,
                        conversation: conversation,
                        expandedInputHeight: expandedComposerInputHeight(for: geometry.size.height)
                    )
                }

            }
        }
        .background(FlareDesign.appBackground)
        .sheet(item: $actionMessage) { message in
            MessageActionSheetHost(message: message, onDismiss: { actionMessage = nil }, onSave: save)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $searchSheetOpen) {
            ChatSearchSheet(viewModel: search, conversation: conversation)
                .presentationDetents([.height(550), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $detailsSheetOpen) {
            ConversationDetailsPanel(conversation: conversation)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $mediaPreview) { preview in
            MediaPreviewSheet(preview: preview)
        }
        .sheet(item: $messaging.previewTarget) { message in
            MessagePreviewSheet(message: message)
                .presentationDetents([.height(420), .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            await messaging.openConversation(conversation.conversationId)
            await runForegroundSyncLoop(for: conversation.conversationId)
        }
        .onChange(of: conversation.conversationId) { _ in
            timelineFollowsTail = true
        }
    }

    /// Saves a message's picture, video or file to the download location through the core: the person sees it
    /// being saved, then where it went (the Files app one tap away), or why it was not.
    private func save(_ message: AppMessage) {
        MediaSaveFeedback.save(message, messaging: messaging, feedback: feedback, openURL: openURL)
    }

    private func expandedComposerInputHeight(for availableHeight: CGFloat) -> CGFloat {
        let reservedChromeHeight: CGFloat = 166
        return max(240, availableHeight - reservedChromeHeight)
    }

    private var timelineTailSignature: String {
        "\(messaging.selectedMessages.count):\(messaging.selectedMessages.last?.appStableId ?? "")"
    }

    private var latestMessageIsFromCurrentUser: Bool {
        guard let currentUserId = messaging.currentUserId,
              let latest = messaging.selectedMessages.last else { return false }
        return latest.senderId == currentUserId
    }

    private var header: some View {
        ConversationHeaderView(
            identity: ConversationIdentity(
                id: conversation.conversationId,
                title: conversation.appTitle,
                avatarURL: conversation.avatarUrl
            ),
            capabilities: ConversationHeaderCapabilities(availableActionIds: ["search", "details", "inspector"]),
            actions: [
                ConversationHeaderAction(id: "search", label: String(localized: "Search messages"), icon: "search"),
                ConversationHeaderAction(id: "inspector", label: String(localized: "Conversation details"), icon: "info"),
                ConversationHeaderAction(id: "details", label: String(localized: "More conversation actions"), icon: "more", placement: .overflow),
            ],
            showBack: showsBackButton,
            onBack: onBack,
            onAction: { action in
                switch action.id {
                case "search":
                    search.draft.conversationScoped = true
                    search.draft.keyword = ""
                    searchSheetOpen = true
                case "inspector": environment.detailsOpen.toggle()
                case "details": detailsSheetOpen = true
                default: break
                }
            }
        )
    }

    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: FlareDesign.Spacing.md) {
                    if messaging.selectedConversationHasMoreMessages {
                        Button {
                            Task { await loadOlderMessages(preserving: proxy) }
                        } label: {
                            Label(
                                loadingOlderMessages ? String(localized: "Loading...") : String(localized: "Load earlier messages"),
                                systemImage: "clock.arrow.circlepath"
                            )
                            .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(loadingOlderMessages)
                        .padding(.top, FlareDesign.Spacing.md)
                    } else if !messaging.selectedMessages.isEmpty {
                        Text("No earlier messages")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(FlareDesign.textTertiary)
                            .padding(.horizontal, FlareDesign.Spacing.md)
                            .padding(.vertical, FlareDesign.Spacing.xs)
                            .background(FlareDesign.surface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
                            .padding(.top, FlareDesign.Spacing.md)
                    }

                    if messaging.selectedMessages.isEmpty {
                        FlareIMUI.EmptyStateView(
                            title: String(localized: "No messages"),
                            description: String(localized: "Send the first message, or use the tools below to build media, tasks, polls, and more."),
                            icon: "chats"
                        ).frame(maxWidth: .infinity, maxHeight: .infinity)
                        .frame(minHeight: 420)
                    } else {
                        ForEach(Array(messaging.selectedMessages.enumerated()), id: \.element.appStableId) { index, message in
                            if shouldShowDate(at: index) {
                                TimelineDatePill(text: timelineDateText(for: message))
                            }
                            MessageRow(message: message, onOpenMedia: { preview in
                                mediaPreview = preview
                            }, onShowActions: { selected in
                                actionMessage = selected
                            }, onSave: save)
                                .id(message.appStableId)
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(Self.timelineBottomAnchorId)
                        .onAppear {
                            timelineFollowsTail = true
                        }
                }
                .padding(.horizontal, FlareDesign.Spacing.sm)
                .padding(.bottom, FlareDesign.Spacing.lg)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        if value.translation.height > 16 {
                            timelineFollowsTail = false
                        }
                    }
            )
            .onChange(of: timelineTailSignature) { _ in
                if let anchor = loadOlderAnchorId {
                    withAnimation(.easeOut(duration: 0.18)) {
                        proxy.scrollTo(anchor, anchor: .top)
                    }
                } else if timelineFollowsTail || latestMessageIsFromCurrentUser {
                    timelineFollowsTail = true
                    scrollToTimelineBottom(proxy)
                }
            }
            .onAppear {
                timelineFollowsTail = true
                scrollToTimelineBottomSoon(proxy)
            }
            .onChange(of: conversation.conversationId) { _ in
                timelineFollowsTail = true
                scrollToTimelineBottomSoon(proxy)
            }
        }
        .refreshable {
            await messaging.openConversation(conversation.conversationId)
        }
    }

    private func scrollToTimelineBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.22)) {
            proxy.scrollTo(Self.timelineBottomAnchorId, anchor: .bottom)
        }
    }

    private func scrollToTimelineBottomSoon(_ proxy: ScrollViewProxy) {
        let delays: [TimeInterval] = [0, 0.16, 0.42]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard timelineFollowsTail, loadOlderAnchorId == nil else { return }
                scrollToTimelineBottom(proxy)
            }
        }
    }

    private func runForegroundSyncLoop(for conversationId: String) async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: Self.foregroundSyncIntervalNs)
            } catch {
                return
            }
            guard !Task.isCancelled, conversation.conversationId == conversationId else { return }
            await messaging.syncSelectedConversation(showBusy: false)
        }
    }

    private func loadOlderMessages(preserving proxy: ScrollViewProxy) async {
        guard !loadingOlderMessages else { return }
        loadingOlderMessages = true
        timelineFollowsTail = false
        let anchor = messaging.selectedMessages.first?.appStableId
        loadOlderAnchorId = anchor
        await messaging.loadOlderMessages()
        if let anchor {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo(anchor, anchor: .top)
            }
        }
        loadOlderAnchorId = nil
        loadingOlderMessages = false
    }

    private func shouldShowDate(at index: Int) -> Bool {
        guard index >= 0, index < messaging.selectedMessages.count else { return false }
        if index == 0 { return true }
        let current = FlareFormatters.dateFromMillis(messaging.selectedMessages[index].appSortTimestamp)
        let previous = FlareFormatters.dateFromMillis(messaging.selectedMessages[index - 1].appSortTimestamp)
        guard let current, let previous else { return false }
        if !Calendar.current.isDate(current, inSameDayAs: previous) { return true }
        return current.timeIntervalSince(previous) >= Self.timelineTimeGapSeconds
    }

    private func timelineDateText(for message: AppMessage) -> String {
        guard let date = FlareFormatters.dateFromMillis(message.appSortTimestamp) else { return "" }
        if Calendar.current.isDateInToday(date) { return FlareFormatters.shortTime.string(from: date) }
        if Calendar.current.isDateInYesterday(date) {
            return String(localized: "Yesterday \(FlareFormatters.shortTime.string(from: date))")
        }
        return FlareFormatters.shortDateTime.string(from: date)
    }
}

/// Timeline day/time separator → delegates to `FlareIMUI.DatePillView` (kit is a
/// parity match: centered capsule pill with border + shadow). App keeps only the
/// vertical rhythm around it.
private struct TimelineDatePill: View {
    let text: String

    var body: some View {
        FlareIMUI.DatePillView(label: text)
            .padding(.vertical, FlareDesign.Spacing.xs)
    }
}
