import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum RichTextShortcut: String, CaseIterable {
    case heading, bold, italic, strike, quote, bulletList, orderedList, codeBlock, inlineCode, link, image, mention
}

enum RichTextInlineStyle: String, CaseIterable, Hashable {
    case bold
    case italic
    case strike
    case inlineCode
    case link
    case image
    case mention
}

enum RichTextBlockStyle: String, CaseIterable, Hashable {
    case body
    case heading
    case quote
    case bulletList
    case orderedList
    case codeBlock
}

struct RichTextComposerSelection: Equatable {
    var inlineStyles: Set<RichTextInlineStyle> = []
    var blockStyle: RichTextBlockStyle = .body

    func isActive(_ shortcut: RichTextShortcut) -> Bool {
        switch shortcut {
        case .heading:
            return blockStyle == .heading
        case .quote:
            return blockStyle == .quote
        case .bulletList:
            return blockStyle == .bulletList
        case .orderedList:
            return blockStyle == .orderedList
        case .codeBlock:
            return blockStyle == .codeBlock
        case .bold:
            return inlineStyles.contains(.bold)
        case .italic:
            return inlineStyles.contains(.italic)
        case .strike:
            return inlineStyles.contains(.strike)
        case .inlineCode:
            return inlineStyles.contains(.inlineCode)
        case .link:
            return inlineStyles.contains(.link)
        case .image:
            return inlineStyles.contains(.image)
        case .mention:
            return inlineStyles.contains(.mention)
        }
    }

    mutating func toggle(_ shortcut: RichTextShortcut) {
        switch shortcut {
        case .heading:
            toggleBlock(.heading)
        case .quote:
            toggleBlock(.quote)
        case .bulletList:
            toggleBlock(.bulletList)
        case .orderedList:
            toggleBlock(.orderedList)
        case .codeBlock:
            toggleBlock(.codeBlock)
        case .bold:
            toggleInline(.bold)
        case .italic:
            toggleInline(.italic)
        case .strike:
            toggleInline(.strike)
        case .inlineCode:
            toggleInline(.inlineCode)
        case .link:
            toggleInline(.link)
        case .image:
            toggleInline(.image)
        case .mention:
            toggleInline(.mention)
        }
    }

    private mutating func toggleBlock(_ style: RichTextBlockStyle) {
        blockStyle = blockStyle == style ? .body : style
    }

    private mutating func toggleInline(_ style: RichTextInlineStyle) {
        if inlineStyles.contains(style) {
            inlineStyles.remove(style)
        } else {
            inlineStyles.insert(style)
        }
    }
}

struct RichTextExport: Equatable {
    let markdown: String
    let plainText: String
    let searchText: String
    let title: String
}

extension NSAttributedString.Key {
    static let flareRichInlineStyles = NSAttributedString.Key("com.flare.im.rich.inlineStyles")
    static let flareRichBlockStyle = NSAttributedString.Key("com.flare.im.rich.blockStyle")
}

enum RichTextMarkdownSerializer {
    static func emptyDocument() -> NSAttributedString {
        NSAttributedString(string: "")
    }

    static func plainDocument(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: attributes(for: RichTextComposerSelection()))
    }

    static func attributes(for selection: RichTextComposerSelection) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .flareRichInlineStyles: inlineStyleValue(selection.inlineStyles),
            .flareRichBlockStyle: selection.blockStyle.rawValue
        ]

        #if canImport(UIKit)
        attributes.merge(uiAttributes(for: selection)) { _, new in new }
        #endif

        return attributes
    }

    static func export(_ attributedText: NSAttributedString) -> RichTextExport {
        let plainText = attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let markdown = markdown(from: attributedText)
        let normalizedSearchText = plainText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return RichTextExport(
            markdown: markdown,
            plainText: plainText,
            searchText: normalizedSearchText.isEmpty ? plainText : normalizedSearchText,
            title: plainText.components(separatedBy: .newlines).first(where: { !$0.isEmpty }) ?? "Rich Doc"
        )
    }

    static func markdown(from attributedText: NSAttributedString) -> String {
        let text = attributedText.string as NSString
        guard text.length > 0 else { return "" }

        var output: [String] = []
        var orderedIndex = 1
        var location = 0

        while location < text.length {
            let paragraphRange = text.paragraphRange(for: NSRange(location: location, length: 0))
            let newlineTrimmedRange = paragraphRangeWithoutTrailingNewlines(paragraphRange, in: text)
            let blockStyle = blockStyle(at: newlineTrimmedRange.location, in: attributedText) ?? .body
            let plainParagraph = text.substring(with: newlineTrimmedRange)

            if plainParagraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                output.append("")
            } else if blockStyle == .codeBlock {
                output.append("```")
                output.append(plainParagraph)
                output.append("```")
            } else {
                let inlineMarkdown = inlineMarkdown(from: attributedText, range: newlineTrimmedRange)
                switch blockStyle {
                case .body:
                    output.append(inlineMarkdown)
                case .heading:
                    output.append("## \(inlineMarkdown)")
                case .quote:
                    output.append("> \(inlineMarkdown)")
                case .bulletList:
                    output.append("- \(inlineMarkdown)")
                case .orderedList:
                    output.append("\(orderedIndex). \(inlineMarkdown)")
                    orderedIndex += 1
                case .codeBlock:
                    break
                }
            }

            location = paragraphRange.location + paragraphRange.length
        }

        return output.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func inlineMarkdown(from attributedText: NSAttributedString, range: NSRange) -> String {
        guard range.length > 0 else { return "" }
        var output = ""
        attributedText.enumerateAttributes(in: range, options: []) { attributes, subrange, _ in
            let raw = (attributedText.string as NSString).substring(with: subrange)
            output += applyInlineStyles(to: raw, styles: inlineStyles(from: attributes))
        }
        return output
    }

    private static func applyInlineStyles(to value: String, styles: Set<RichTextInlineStyle>) -> String {
        guard !value.isEmpty else { return "" }
        var output = value

        if styles.contains(.mention), !output.hasPrefix("@") {
            output = "@\(output)"
        }
        if styles.contains(.image) {
            output = "![\(output)](https://)"
        } else if styles.contains(.link) {
            output = "[\(output)](https://)"
        }
        if styles.contains(.inlineCode) {
            output = "`\(output)`"
        }
        if styles.contains(.bold) {
            output = "**\(output)**"
        }
        if styles.contains(.italic) {
            output = "*\(output)*"
        }
        if styles.contains(.strike) {
            output = "~~\(output)~~"
        }

        return output
    }

    private static func paragraphRangeWithoutTrailingNewlines(_ range: NSRange, in text: NSString) -> NSRange {
        var length = range.length
        while length > 0 {
            let character = text.character(at: range.location + length - 1)
            if character == 10 || character == 13 {
                length -= 1
            } else {
                break
            }
        }
        return NSRange(location: range.location, length: length)
    }

    private static func blockStyle(at location: Int, in attributedText: NSAttributedString) -> RichTextBlockStyle? {
        guard attributedText.length > 0 else { return nil }
        let safeLocation = min(max(0, location), attributedText.length - 1)
        let raw = attributedText.attribute(.flareRichBlockStyle, at: safeLocation, effectiveRange: nil) as? String
        return raw.flatMap(RichTextBlockStyle.init(rawValue:))
    }

    static func inlineStyles(from attributes: [NSAttributedString.Key: Any]) -> Set<RichTextInlineStyle> {
        guard let raw = attributes[.flareRichInlineStyles] as? String, !raw.isEmpty else {
            return []
        }
        return Set(raw.split(separator: ",").compactMap { RichTextInlineStyle(rawValue: String($0)) })
    }

    private static func inlineStyleValue(_ styles: Set<RichTextInlineStyle>) -> String {
        styles
            .map(\.rawValue)
            .sorted()
            .joined(separator: ",")
    }
}

#if canImport(UIKit)
extension RichTextMarkdownSerializer {
    static func uiAttributes(for selection: RichTextComposerSelection) -> [NSAttributedString.Key: Any] {
        var traits: UIFontDescriptor.SymbolicTraits = []
        if selection.inlineStyles.contains(.bold) || selection.blockStyle == .heading {
            traits.insert(.traitBold)
        }
        if selection.inlineStyles.contains(.italic) {
            traits.insert(.traitItalic)
        }

        let textStyle: UIFont.TextStyle = selection.blockStyle == .heading ? .headline : .body
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: textStyle)
        let resolvedDescriptor = descriptor.withSymbolicTraits(traits) ?? descriptor
        let fontSize: CGFloat = selection.blockStyle == .heading ? 20 : 16
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacing = selection.blockStyle == .heading ? 8 : 4
        if selection.blockStyle == .quote {
            paragraph.headIndent = 12
            paragraph.firstLineHeadIndent = 12
        } else if selection.blockStyle == .bulletList || selection.blockStyle == .orderedList {
            paragraph.headIndent = 16
            paragraph.firstLineHeadIndent = 16
        }

        var foreground = UIColor.label
        if selection.inlineStyles.contains(.link) {
            foreground = UIColor.systemBlue
        } else if selection.inlineStyles.contains(.image) {
            foreground = UIColor.systemTeal
        } else if selection.inlineStyles.contains(.mention) {
            foreground = UIColor.systemPurple
        } else if selection.blockStyle == .quote {
            foreground = UIColor.secondaryLabel
        }

        var attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(descriptor: resolvedDescriptor, size: fontSize),
            .foregroundColor: foreground,
            .paragraphStyle: paragraph
        ]
        if selection.inlineStyles.contains(.strike) {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        if selection.inlineStyles.contains(.link) {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if selection.inlineStyles.contains(.inlineCode) || selection.blockStyle == .codeBlock {
            attributes[.font] = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
            attributes[.backgroundColor] = UIColor.secondarySystemBackground
        }
        return attributes
    }
}
#endif
