import FlareIMUI
import FlareCoreAppleSDK
import AVFoundation
import AVKit
import SwiftUI

struct ChatSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SearchViewModel
    let conversation: AppConversation

    private let kinds: [(String, String, MessageSearchKind)] = [
        (String(localized: "All"), "bubble.left.and.bubble.right", .message),
        (String(localized: "Text"), "doc.text", .text),
        (String(localized: "Media"), "tray.full", .media),
        (String(localized: "Image"), "photo", .image),
        (String(localized: "Video"), "video", .video),
        (String(localized: "Audio"), "mic", .audio),
        (String(localized: "File"), "folder", .file)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Search messages")
                    .font(.headline.weight(.bold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, FlareDesign.Spacing.xl)
            .padding(.vertical, FlareDesign.Spacing.lg)
            Divider()

            VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
                VStack(alignment: .leading, spacing: FlareDesign.Spacing.sm) {
                    Text("Current conversation")
                        .font(.caption)
                        .foregroundStyle(FlareDesign.textTertiary)
                    Text(conversation.appTitle)
                        .font(.headline.weight(.bold))
                    HStack(spacing: FlareDesign.Spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(FlareDesign.brand)
                        Text("Enter a keyword to search")
                            .font(.caption)
                            .foregroundStyle(FlareDesign.textTertiary)
                    }
                    .padding(.horizontal, FlareDesign.Spacing.md)
                    .frame(height: 30)
                    .background(FlareDesign.surfaceAlt)
                    .clipShape(Capsule())
                }
                .padding(FlareDesign.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FlareDesign.surface)
                .clipShape(RoundedRectangle(cornerRadius: FlareDesign.radius, style: .continuous))

                HStack(spacing: FlareDesign.Spacing.sm) {
                    TextField("Search chat history", text: Binding(
                        get: { viewModel.draft.keyword },
                        set: { viewModel.draft.keyword = $0 }
                    ))
                    .padding(.horizontal, FlareDesign.Spacing.md)
                    .frame(height: 42)
                    .background(FlareDesign.surface)
                    .clipShape(RoundedRectangle(cornerRadius: FlareDesign.radius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: FlareDesign.radius, style: .continuous)
                            .stroke(FlareDesign.brand.opacity(0.75), lineWidth: 1)
                    )

                    Button("Search") {
                        viewModel.draft.conversationScoped = true
                        Task { await viewModel.search() }
                    }
                    .font(.footnote.weight(.bold))
                    .frame(width: 70, height: 42)
                    .foregroundStyle(.white)
                    .background(FlareDesign.brand.opacity(viewModel.draft.keyword.isEmpty ? 0.45 : 1))
                    .clipShape(RoundedRectangle(cornerRadius: FlareDesign.radius, style: .continuous))
                    .disabled(viewModel.draft.keyword.isEmpty)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: FlareDesign.Spacing.sm) {
                    ForEach(kinds, id: \.0) { item in
                        Button {
                            viewModel.draft.kind = item.2
                        } label: {
                            Label(item.0, systemImage: item.1)
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .foregroundStyle(viewModel.draft.kind == item.2 ? FlareDesign.brand : FlareDesign.textSecondary)
                                .background(viewModel.draft.kind == item.2 ? FlareDesign.brandSoft : FlareDesign.surface)
                                .clipShape(RoundedRectangle(cornerRadius: FlareDesign.radius, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(FlareDesign.Spacing.xl)

            if viewModel.results.isEmpty {
                FlareIMUI.EmptyStateView(
                    title: String(localized: "Search the current conversation"),
                    description: String(localized: "Enter a keyword to search"),
                    icon: "search"
                ).frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: FlareDesign.Spacing.sm) {
                        ForEach(viewModel.results, id: \.appStableId) { message in
                            SearchResultCell(message: message)
                        }
                    }
                    .padding(.horizontal, FlareDesign.Spacing.xl)
                    .padding(.bottom, FlareDesign.Spacing.xl)
                }
            }
        }
        .background(FlareDesign.appBackground)
        .onAppear {
            viewModel.draft.conversationScoped = true
        }
    }
}

private struct SearchResultCell: View {
    let message: AppMessage

    var body: some View {
        VStack(alignment: .leading, spacing: FlareDesign.Spacing.xs) {
            HStack {
                Text(message.senderTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FlareDesign.textSecondary)
                Spacer()
                Text(FlareFormatters.relativeMillis(message.appSortTimestamp))
                    .font(.caption2)
                    .foregroundStyle(FlareDesign.textTertiary)
            }
            Text(message.previewText)
                .font(.subheadline)
                .foregroundStyle(FlareDesign.textPrimary)
                .lineLimit(2)
        }
        .padding(FlareDesign.Spacing.md)
        .background(FlareDesign.surface)
        .clipShape(RoundedRectangle(cornerRadius: FlareDesign.radius, style: .continuous))
    }
}
