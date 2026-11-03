import FlareCoreAppleSDK
import SwiftUI
import FlareIMUI

struct StatusBanner: View {
    let status: RuntimeStatus
    let error: String?

    var body: some View {
        StatusBannerView(
            text: [status.productLabel, detail].compactMap { $0 }.joined(separator: "\n"),
            tone: kitTone
        )
    }

    private var detail: String? {
        if let error, !error.isEmpty {
            return error
        }
        return status.productDetail
    }

    private var kitTone: FlareStatusTone {
        switch status.productTone {
        case .neutral: return .neutral
        case .info: return .info
        case .success: return .success
        case .warning: return .warning
        case .danger: return .danger
        }
    }
}

struct KeyValueRows: View {
    let values: [(String, String)]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(values, id: \.0) { key, value in
                HStack(alignment: .top, spacing: FlareDesign.Spacing.md) {
                    Text(key)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FlareDesign.textSecondary)
                        .frame(width: 128, alignment: .leading)
                    Text(value.isEmpty ? "-" : value)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, FlareDesign.Spacing.sm)
                if key != values.last?.0 {
                    Divider()
                }
            }
        }
    }
}

struct Pill: View {
    let text: String
    var color: Color = FlareDesign.brand

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, FlareDesign.Spacing.sm)
            .padding(.vertical, FlareDesign.Spacing.xs)
            .foregroundStyle(color)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct StatusPill: View {
    let text: String
    var symbol: String?
    var tone: RuntimeTone = .neutral
    var filled = false

    var body: some View {
        HStack(spacing: FlareDesign.Spacing.xs) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.caption2.weight(.bold))
            }
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, FlareDesign.Spacing.sm)
        .padding(.vertical, FlareDesign.Spacing.xs)
        .foregroundStyle(filled ? .white : color)
        .background(filled ? color : color.opacity(0.11))
        .clipShape(Capsule())
    }

    private var color: Color {
        FlareDesign.color(for: tone)
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: FlareDesign.Spacing.xs) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(FlareDesign.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(FlareDesign.textSecondary)
            }
        }
    }
}
