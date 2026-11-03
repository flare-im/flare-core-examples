import FlareCoreAppleSDK
import FlareIMUI
import SwiftUI

struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel
    @EnvironmentObject private var messaging: MessagingViewModel
    @Environment(\.flareFeedback) private var feedback
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: FlareDesign.Spacing.lg) {
                SectionHeader(
                    title: String(localized: "Message Search"),
                    subtitle: String(localized: "Covers global and in-conversation search APIs with typed filters.")
                )
                HStack(spacing: FlareDesign.Spacing.md) {
                    InputView(
                        text: $viewModel.draft.keyword,
                        placeholder: String(localized: "Keyword"),
                        onSubmit: { Task { await viewModel.search() } }
                    )
                    InputView(text: $viewModel.draft.senderId, placeholder: String(localized: "Sender"))
                        .identifierInput()
                        .frame(maxWidth: 180)
                    Picker("Kind", selection: $viewModel.draft.kind) {
                        ForEach(MessageSearchKind.allCasesForExample, id: \.rawValue) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .frame(maxWidth: 160)
                }
                HStack {
                    Toggle("Scope to selected conversation", isOn: $viewModel.draft.conversationScoped)
                    Toggle("Include recalled", isOn: $viewModel.draft.includeRecalled)
                    Spacer()
                    Button {
                        Task { await viewModel.search() }
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(FlareDesign.Spacing.xl)
            .background(FlareDesign.surface)

            Divider()

            if viewModel.results.isEmpty {
                FlareIMUI.EmptyStateView(
                    title: String(localized: "No search results"),
                    description: String(localized: "Enter a keyword or use empty typed filters to probe the SDK search path."),
                    icon: "search"
                ).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: FlareDesign.Spacing.md) {
                        ForEach(viewModel.results, id: \.appStableId) { message in
                            VStack(alignment: .leading, spacing: FlareDesign.Spacing.xs) {
                                Text(message.conversationId)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(FlareDesign.textSecondary)
                                // A found file saves to the download location, as it does in the chat.
                                MessageRow(message: message, onSave: save)
                            }
                            .padding(.horizontal, FlareDesign.Spacing.xl)
                        }
                    }
                    .padding(.vertical, FlareDesign.Spacing.xl)
                }
            }
        }
        .background(FlareDesign.appBackground)
    }

    private func save(_ message: AppMessage) {
        MediaSaveFeedback.save(message, messaging: messaging, feedback: feedback, openURL: openURL)
    }
}

private extension MessageSearchKind {
    static var allCasesForExample: [MessageSearchKind] {
        [.message, .text, .media, .image, .video, .audio, .file]
    }
}
