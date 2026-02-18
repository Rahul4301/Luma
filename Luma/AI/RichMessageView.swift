// Luma — RichMessageView: combined MarkdownUI + LaTeXSwiftUI renderer
// Used by both the AI start page (SmartSearchView) and the side AI panel (CommandSurface).
import SwiftUI
import MarkdownUI
import LaTeXSwiftUI

// MARK: - Public view

struct RichMessageView: View {
    let rawText: String
    let fontSize: CGFloat
    let linkColor: Color
    var onLinkTapped: ((URL) -> Void)?

    var body: some View {
        let segments = Self.splitMathSegments(rawText)
        let hasMath = segments.contains { $0.isMath }

        if hasMath {
            mixedContent(segments)
        } else {
            markdownOnly
        }
    }

    // MARK: - Pure markdown path (no LaTeX detected)

    private var markdownOnly: some View {
        Markdown(rawText)
            .markdownTheme(lumaTheme)
            .markdownTextStyle { FontSize(fontSize) }
            .textSelection(.enabled)
            .environment(\.openURL, OpenURLAction { url in
                onLinkTapped?(url)
                return .handled
            })
    }

    // MARK: - Mixed content path (markdown + LaTeX)

    private func mixedContent(_ segments: [TextSegment]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                if segment.isMath {
                    LaTeX(segment.text)
                        .parsingMode(.onlyEquations)
                        .imageRenderingMode(.template)
                        .foregroundStyle(Color.white.opacity(0.95))
                        .blockMode(.blockViews)
                        .errorMode(.original)
                        .renderingStyle(.original)
                        .renderingAnimation(.easeIn)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(size: fontSize))
                } else if !segment.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Markdown(segment.text)
                        .markdownTheme(lumaTheme)
                        .markdownTextStyle { FontSize(fontSize) }
                        .textSelection(.enabled)
                        .environment(\.openURL, OpenURLAction { url in
                            onLinkTapped?(url)
                            return .handled
                        })
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Luma dark theme for MarkdownUI

    private var lumaTheme: MarkdownUI.Theme {
        .init()
            .text { ForegroundColor(Color.white.opacity(0.95)) }
            .link { ForegroundColor(linkColor); UnderlineStyle(.single) }
            .strong { FontWeight(.semibold) }
            .emphasis { FontStyle(.italic) }
            .strikethrough { StrikethroughStyle(.single) }
            .heading1 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontSize(fontSize + 10)
                        FontWeight(.bold)
                        ForegroundColor(Color.white)
                    }
                    .markdownMargin(top: 16, bottom: 8)
            }
            .heading2 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontSize(fontSize + 6)
                        FontWeight(.bold)
                        ForegroundColor(Color.white)
                    }
                    .markdownMargin(top: 14, bottom: 6)
            }
            .heading3 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontSize(fontSize + 3)
                        FontWeight(.semibold)
                        ForegroundColor(Color.white)
                    }
                    .markdownMargin(top: 12, bottom: 4)
            }
            .heading4 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontSize(fontSize + 1)
                        FontWeight(.semibold)
                        ForegroundColor(Color.white.opacity(0.9))
                    }
                    .markdownMargin(top: 10, bottom: 4)
            }
            .heading5 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontSize(fontSize)
                        FontWeight(.semibold)
                        ForegroundColor(Color.white.opacity(0.85))
                    }
                    .markdownMargin(top: 8, bottom: 2)
            }
            .heading6 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontSize(fontSize)
                        FontWeight(.medium)
                        ForegroundColor(Color.white.opacity(0.8))
                    }
                    .markdownMargin(top: 6, bottom: 2)
            }
            .paragraph { configuration in
                configuration.label
                    .markdownMargin(top: 0, bottom: 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .codeBlock { configuration in
                ScrollView(.horizontal, showsIndicators: false) {
                    configuration.label
                        .markdownTextStyle {
                            FontFamilyVariant(.monospaced)
                            FontSize(fontSize - 1)
                            ForegroundColor(Color.white.opacity(0.9))
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .markdownMargin(top: 4, bottom: 4)
            }
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(fontSize - 1)
                BackgroundColor(Color.white.opacity(0.1))
            }
            .blockquote { configuration in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 3)
                    configuration.label
                        .markdownTextStyle { ForegroundColor(Color.white.opacity(0.7)) }
                        .padding(.leading, 10)
                }
                .markdownMargin(top: 4, bottom: 4)
            }
            .listItem { configuration in
                configuration.label
                    .markdownMargin(top: 2, bottom: 2)
            }
            .table { configuration in
                configuration.label
                    .markdownTextStyle { FontSize(fontSize - 1) }
                    .markdownMargin(top: 4, bottom: 4)
            }
            .thematicBreak {
                Divider()
                    .overlay(Color.white.opacity(0.15))
                    .markdownMargin(top: 8, bottom: 8)
            }
            .image { configuration in
                configuration.label
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
    }

    // MARK: - LaTeX segment splitting

    struct TextSegment {
        let text: String
        let isMath: Bool
    }

    /// Splits input into alternating markdown and math segments.
    /// Detects $$...$$ (block) and $...$ (inline) delimiters.
    /// Returns pure markdown segments interleaved with math segments.
    static func splitMathSegments(_ input: String) -> [TextSegment] {
        var segments: [TextSegment] = []
        var remaining = input[input.startIndex...]

        while !remaining.isEmpty {
            // Try block math $$...$$
            if let blockStart = remaining.range(of: "$$") {
                let before = String(remaining[remaining.startIndex..<blockStart.lowerBound])
                if !before.isEmpty { segments.append(TextSegment(text: before, isMath: false)) }

                let afterOpen = remaining[blockStart.upperBound...]
                if let blockEnd = afterOpen.range(of: "$$") {
                    let math = "$$" + String(afterOpen[afterOpen.startIndex..<blockEnd.lowerBound]) + "$$"
                    segments.append(TextSegment(text: math, isMath: true))
                    remaining = afterOpen[blockEnd.upperBound...]
                } else {
                    segments.append(TextSegment(text: String(remaining), isMath: false))
                    break
                }
            } else if let inlineStart = findInlineMathStart(in: remaining) {
                let before = String(remaining[remaining.startIndex..<inlineStart.lowerBound])
                if !before.isEmpty { segments.append(TextSegment(text: before, isMath: false)) }

                let afterOpen = remaining[inlineStart.upperBound...]
                if let inlineEnd = findInlineMathEnd(in: afterOpen) {
                    let math = "$" + String(afterOpen[afterOpen.startIndex..<inlineEnd.lowerBound]) + "$"
                    segments.append(TextSegment(text: math, isMath: true))
                    remaining = afterOpen[inlineEnd.upperBound...]
                } else {
                    segments.append(TextSegment(text: String(remaining), isMath: false))
                    break
                }
            } else {
                segments.append(TextSegment(text: String(remaining), isMath: false))
                break
            }
        }

        return segments
    }

    /// Finds a single `$` that starts inline math (not `$$`, not preceded by `\`).
    private static func findInlineMathStart(in s: Substring) -> Range<String.Index>? {
        var i = s.startIndex
        while i < s.endIndex {
            if s[i] == "$" {
                let next = s.index(after: i)
                if next < s.endIndex && s[next] == "$" {
                    return nil
                }
                if i > s.startIndex {
                    let prev = s.index(before: i)
                    if s[prev] == "\\" { i = next; continue }
                }
                return i..<next
            }
            i = s.index(after: i)
        }
        return nil
    }

    /// Finds a single `$` that ends inline math.
    private static func findInlineMathEnd(in s: Substring) -> Range<String.Index>? {
        var i = s.startIndex
        while i < s.endIndex {
            if s[i] == "$" {
                if i > s.startIndex {
                    let prev = s.index(before: i)
                    if s[prev] == "\\" { i = s.index(after: i); continue }
                }
                let next = s.index(after: i)
                return i..<next
            }
            i = s.index(after: i)
        }
        return nil
    }
}
