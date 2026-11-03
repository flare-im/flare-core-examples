import FlareIMUI
import FlareCoreAppleSDK
import AVFoundation
import AVKit
import SwiftUI

struct ComposerFormDraft: Identifiable {
    let id = UUID()
    let kind: ComposerFormKind
}

enum ComposerFormKind: String, Identifiable {
    case imageFallback
    case video
    case location
    case card
    case task
    case schedule
    case poll
    case link
    case miniProgram
    case notification
    case announcement

    var id: String { rawValue }

    var op: MessageBuildOp {
        switch self {
        case .imageFallback: return .createImage
        case .video: return .createVideo
        case .location: return .createLocation
        case .card: return .createCard
        case .task: return .createTask
        case .schedule: return .createSchedule
        case .poll: return .createVote
        case .link: return .createLinkCard
        case .miniProgram: return .createMiniProgram
        case .notification: return .createNotification
        case .announcement: return .createAnnouncement
        }
    }

    var sheetTitle: String {
        switch self {
        case .imageFallback: return String(localized: "Send image")
        case .video: return String(localized: "Send video")
        case .location: return String(localized: "Send location")
        case .card: return String(localized: "Send contact")
        case .task: return String(localized: "Send task")
        case .schedule: return String(localized: "Send schedule")
        case .poll: return String(localized: "Send poll")
        case .link: return String(localized: "Send link")
        case .miniProgram: return String(localized: "Send mini program")
        case .notification: return String(localized: "Send notification")
        case .announcement: return String(localized: "Send announcement")
        }
    }

    var badge: String {
        switch self {
        case .imageFallback: return "image"
        case .video: return "video"
        case .location: return "location"
        case .card: return "card"
        case .task: return "task"
        case .schedule: return "schedule"
        case .poll: return "poll"
        case .link: return "link"
        case .miniProgram: return "mini"
        case .notification: return "notice"
        case .announcement: return "announce"
        }
    }

    var summary: String {
        switch self {
        case .imageFallback: return String(localized: "Add an image caption as a fallback when album selection is unavailable")
        case .video: return String(localized: "Provide the video ID and caption")
        case .location: return String(localized: "Send a place name, address, and coordinates")
        case .card: return String(localized: "Send a contact or business card")
        case .task: return String(localized: "Send a task title and participants")
        case .schedule: return String(localized: "Send a title, time, location, and participants")
        case .poll: return String(localized: "Send a question and options")
        case .link: return String(localized: "Send a link URL and card description")
        case .miniProgram: return String(localized: "Send a mini program entry")
        case .notification: return String(localized: "Send a notification title and body")
        case .announcement: return String(localized: "Send an announcement title and body")
        }
    }

    var preferredSheetHeight: CGFloat {
        switch self {
        case .schedule, .poll, .location:
            return 560
        default:
            return 500
        }
    }
}

struct ComposerInputFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    let draft: ComposerFormDraft
    let currentUserId: String?
    let onSubmit: ([String: Any]) -> Void

    @State private var title = ""
    @State private var detail = ""
    @State private var extra = ""
    @State private var participants = ""
    @State private var startDate = Date().addingTimeInterval(30 * 60)
    @State private var endDate = Date().addingTimeInterval(90 * 60)

    init(draft: ComposerFormDraft, currentUserId: String?, onSubmit: @escaping ([String: Any]) -> Void) {
        self.draft = draft
        self.currentUserId = currentUserId
        self.onSubmit = onSubmit
        _participants = State(initialValue: currentUserId ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(draft.kind.sheetTitle)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(FlareDesign.textPrimary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: FlareSizes.fontSize2xl, weight: .medium))
                        .foregroundStyle(FlareDesign.textSecondary)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, FlareDesign.Spacing.xl)
            .padding(.top, FlareDesign.Spacing.xl)
            .padding(.bottom, FlareDesign.Spacing.sm)

            HStack(spacing: FlareDesign.Spacing.sm) {
                Text(draft.kind.badge)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FlareDesign.textSecondary)
                    .padding(.horizontal, FlareDesign.Spacing.sm)
                    .padding(.vertical, FlareDesign.Spacing.xs)
                    .background(FlareDesign.surfaceAlt)
                    .clipShape(Capsule())
                Text(draft.kind.summary)
                    .font(.caption)
                    .foregroundStyle(FlareDesign.textSecondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, FlareDesign.Spacing.xl)
            .padding(.bottom, FlareDesign.Spacing.lg)

            ScrollView {
                VStack(alignment: .leading, spacing: FlareDesign.Spacing.lg) {
                    fields
                }
                .padding(.horizontal, FlareDesign.Spacing.xl)
                .padding(.bottom, FlareDesign.Spacing.xl)
            }

            Divider()
            HStack(spacing: FlareDesign.Spacing.md) {
                Spacer()
                ButtonView(label: String(localized: "Cancel"), variant: .secondary) {
                    dismiss()
                }
                ButtonView(label: String(localized: "Send"), disabled: !isValid) {
                    onSubmit(payload)
                    dismiss()
                }
            }
            .padding(.horizontal, FlareDesign.Spacing.xl)
            .padding(.vertical, FlareDesign.Spacing.lg)
        }
        .background(FlareDesign.surface)
    }

    @ViewBuilder
    private var fields: some View {
        switch draft.kind {
        case .imageFallback:
            inputField(String(localized: "Image caption"), placeholder: String(localized: "e.g. On-site photo"), text: $title)
        case .video:
            identifierField(String(localized: "Video ID"), placeholder: "video-id", text: $title)
            inputField(String(localized: "Description"), placeholder: String(localized: "Video caption"), text: $detail)
        case .location:
            inputField(String(localized: "Place name"), placeholder: String(localized: "e.g. Shanghai office"), text: $title)
            inputField(String(localized: "Address"), placeholder: String(localized: "e.g. 100 Century Ave"), text: $detail)
            identifierField(String(localized: "Coordinates (optional)"), placeholder: "31.2304,121.4737", text: $extra)
        case .card:
            inputField(String(localized: "Name"), placeholder: String(localized: "Contact card title"), text: $title)
            inputField(String(localized: "Description"), placeholder: String(localized: "Role, team, or note"), text: $detail)
            identifierField(String(localized: "Business ID"), placeholder: "card-id", text: $extra)
        case .task:
            inputField(String(localized: "Task title"), placeholder: String(localized: "e.g. Review the iOS composer"), text: $title)
            identifierField(String(localized: "Participants"), placeholder: String(localized: "Separate IDs with spaces or commas"), text: $participants)
        case .schedule:
            inputField(String(localized: "Title / name"), placeholder: String(localized: "e.g. Product review"), text: $title)
            DatePicker("Start time", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                .font(.subheadline)
            DatePicker("End time", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                .font(.subheadline)
            inputField(String(localized: "Venue"), placeholder: String(localized: "Room or online link"), text: $detail)
            identifierField(String(localized: "Participants"), placeholder: String(localized: "Separate IDs with spaces or commas"), text: $participants)
        case .poll:
            inputField(String(localized: "Poll title"), placeholder: String(localized: "e.g. Pick a release time"), text: $title)
            multilineField(String(localized: "Options"), placeholder: String(localized: "One option per line"), text: $detail)
            identifierField(String(localized: "Participants"), placeholder: String(localized: "Optional — separate IDs with spaces or commas"), text: $participants)
        case .link:
            identifierField(String(localized: "Link"), placeholder: "https://", text: $title)
            inputField(String(localized: "Title"), placeholder: String(localized: "Card title"), text: $detail)
            inputField(String(localized: "Description"), placeholder: String(localized: "Card summary"), text: $extra)
        case .miniProgram:
            identifierField(String(localized: "Mini program ID"), placeholder: "app-id", text: $title)
            inputField(String(localized: "Title"), placeholder: String(localized: "Entry title"), text: $detail)
            identifierField(String(localized: "Page path"), placeholder: "/pages/home", text: $extra)
        case .notification, .announcement:
            inputField(String(localized: "Title"), placeholder: String(localized: "Enter a title"), text: $title)
            multilineField(String(localized: "Body"), placeholder: String(localized: "Enter the body"), text: $detail)
        }
    }

    private var payload: [String: Any] {
        switch draft.kind {
        case .imageFallback:
            return [
                "imageId": "manual-image-\(UUID().uuidString)",
                "description": trimmed(title, fallback: String(localized: "Image"))
            ]
        case .video:
            return [
                "videoId": trimmed(title, fallback: "ios-video-\(UUID().uuidString)"),
                "description": trimmed(detail, fallback: String(localized: "Video"))
            ]
        case .location:
            let coordinate = parseCoordinate(extra)
            return [
                "title": trimmed(title, fallback: String(localized: "Location")),
                "address": trimmed(detail, fallback: title),
                "latitude": coordinate?.latitude ?? 31.2304,
                "longitude": coordinate?.longitude ?? 121.4737
            ]
        case .card:
            return [
                "id": trimmed(extra, fallback: "card-\(UUID().uuidString)"),
                "title": trimmed(title, fallback: String(localized: "Contact")),
                "subtitle": trimmed(detail, fallback: currentUserId ?? "")
            ]
        case .task:
            return [
                "title": trimmed(title, fallback: String(localized: "Task")),
                "participantUserIds": participants
            ]
        case .schedule:
            let location = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayTitle = location.isEmpty ? trimmed(title, fallback: String(localized: "Schedule")) : "\(trimmed(title, fallback: String(localized: "Schedule"))) · \(location)"
            return [
                "title": displayTitle,
                "startTimeMs": Int(startDate.timeIntervalSince1970 * 1000),
                "endTimeMs": Int(max(endDate.timeIntervalSince1970, startDate.addingTimeInterval(30 * 60).timeIntervalSince1970) * 1000),
                "participantUserIds": participants
            ]
        case .poll:
            return [
                "title": trimmed(title, fallback: String(localized: "Vote")),
                "options": optionList,
                "participantUserIds": participants
            ]
        case .link:
            return [
                "url": trimmed(title, fallback: "https://flare.local"),
                "title": trimmed(detail, fallback: title),
                "description": trimmed(extra, fallback: "")
            ]
        case .miniProgram:
            return [
                "appId": trimmed(title, fallback: "flare-mini"),
                "title": trimmed(detail, fallback: String(localized: "Mini program")),
                "pagePath": trimmed(extra, fallback: "/")
            ]
        case .notification:
            return [
                "title": trimmed(title, fallback: String(localized: "Notice")),
                "body": trimmed(detail, fallback: "")
            ]
        case .announcement:
            return [
                "title": trimmed(title, fallback: String(localized: "Announcement")),
                "body": trimmed(detail, fallback: "")
            ]
        }
    }

    private var isValid: Bool {
        switch draft.kind {
        case .poll:
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && optionList.count >= 2
        case .link:
            return URL(string: title.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
        case .notification, .announcement:
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var optionList: [String] {
        detail
            .split { $0 == "\n" || $0 == "," || $0 == "，" }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func inputField(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        FormFieldView(label: title) { InputView(text: text, placeholder: placeholder) }
    }

    /// IDs, links, paths and coordinates are exact strings: no automatic capitalization or
    /// correction, or a participant typed as `ui2-release-ios` is sent as `Ui2-release-ios`.
    private func identifierField(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        FormFieldView(label: title) { InputView(text: text, placeholder: placeholder).identifierInput() }
    }

    private func multilineField(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        FormFieldView(label: title) { InputView(text: text, placeholder: placeholder, multiline: true) }
    }

    private func trimmed(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func parseCoordinate(_ value: String) -> (latitude: Double, longitude: Double)? {
        let parts = value
            .split { $0 == "," || $0 == "，" || $0 == " " }
            .map { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        guard parts.count >= 2, let latitude = parts[0], let longitude = parts[1] else { return nil }
        return (latitude, longitude)
    }
}
