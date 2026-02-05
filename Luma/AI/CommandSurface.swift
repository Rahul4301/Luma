// Luma MVP - AI Side Panel (redesigned for clarity, calmness, accessibility)
import Foundation
import SwiftUI
import AppKit
import PDFKit
import UniformTypeIdentifiers
import Combine

// MARK: - Panel tokens (WCAG AA: body ≥4.5:1, secondary ≥3:1 on panel bg)

private enum PanelTokens {
    static let panelBg = Color(red: 0.09, green: 0.09, blue: 0.11)
    static let panelBgSecondary = Color(red: 0.07, green: 0.07, blue: 0.09)
    static let surfaceElevated = Color(white: 0.14)
    /// Body text: ≥4.5:1 on panelBg
    static let textPrimary = Color(white: 0.94)
    /// Secondary text: ≥3:1 on panelBg
    static let textSecondary = Color(white: 0.62)
    static let textTertiary = Color(white: 0.50)
    static let accent = Color(red: 0.45, green: 0.58, blue: 0.72)
    static let accentDim = Color(red: 0.4, green: 0.5, blue: 0.62).opacity(0.15)
    static let errorText = Color(red: 0.95, green: 0.55, blue: 0.55)
    static let cornerRadius: CGFloat = 14
    static let cornerRadiusLarge: CGFloat = 18
}

/// Cross-tab affordance microcopy (≤50 characters).
private let otherTabsMicrocopy = "Add context from other tabs (coming soon)"

/// Glassmorphism: darker grey blur + tint; shinier via subtle highlight.
private let panelGlassTint = Color(red: 0.03, green: 0.03, blue: 0.04)
private let panelGlassTintOpacity: Double = 0.90

/// Right-side AI command panel (Cmd+E toggle). Per-tab chat with history.
///
/// Redesign: clear hierarchy (header → context → conversation → input),
/// calm visuals, WCAG contrast, keyboard + screen reader support.
struct CommandSurfaceView: View {
    @Binding var isPresented: Bool
    @Binding var messages: [ChatMessage]
    let webViewWrapper: WebViewWrapper
    let commandRouter: CommandRouter
    let gemini: GeminiClient
    let onActionProposed: (LLMResponse) -> Void
    
    var tabId: UUID? = nil

    @AppStorage("luma_ai_panel_font_size") private var aiPanelFontSizeRaw: Int = 13
    @State private var inputText: String = ""
    @State private var errorMessage: String? = nil
    @State private var isSending: Bool = false
    @State private var actionProposedMessage: String? = nil
    @State private var includeSelection: Bool = false
    @State private var selectedText: String? = nil
    @State private var contextSectionExpanded: Bool = false
    @State private var conversationSummary: String? = nil
    @State private var lastSummarizedMessageCount: Int = 0
    @FocusState private var isInputFocused: Bool

    @State private var pageTitle: String? = nil
    @State private var pageText: String? = nil
    @State private var isLoadingContext: Bool = false
    @State private var contextRefreshTimer: Timer? = nil

    @State private var attachedDocuments: [AttachedDocument] = []
    @State private var documentPickerPresented: Bool = false
    @State private var documentError: String? = nil

    private var chatFontSize: CGFloat { CGFloat(aiPanelFontSizeRaw) }

    var body: some View {
        VStack(spacing: 0) {
            panelHeader()
            contextSourcesSection()
            conversationStream()
            inputArea()
        }
        .background(
            ZStack {
                VisualEffectView(
                    material: .hudWindow,
                    blendingMode: .behindWindow,
                    state: .active
                )
                panelGlassTint.opacity(panelGlassTintOpacity)
                // Subtle top-edge shine
                LinearGradient(
                    colors: [Color.white.opacity(0.04), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: PanelTokens.cornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PanelTokens.cornerRadiusLarge, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .onAppear {
            loadPageContext()
            startContextRefreshTimer()
        }
        .onDisappear { stopContextRefreshTimer() }
    }

    // MARK: - Header

    private func panelHeader() -> some View {
        HStack(spacing: 10) {
            Text("Context-aware • This tab")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(PanelTokens.textSecondary)
                .accessibilityLabel("Context-aware for this tab")

            statusBadge()

            if KeychainManager.shared.fetchGeminiKey() == nil || GeminiClient.lastNetworkError != nil {
                SettingsLink {
                    Text("Settings")
                        .font(.caption2)
                        .foregroundColor(PanelTokens.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open settings")
            }
            Spacer(minLength: 0)
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(PanelTokens.textSecondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityLabel("Close AI panel")
            .accessibilityHint("Closes the AI panel")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(panelGlassTint.opacity(panelGlassTintOpacity * 0.95))
    }

    private func statusBadge() -> some View {
        let (color, label) = statusDotState()
        return HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(PanelTokens.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(label)")
    }

    private func statusDotState() -> (Color, String) {
        if GeminiClient.lastNetworkError != nil {
            return (.red, "Error")
        }
        if KeychainManager.shared.fetchGeminiKey() == nil {
            return (.gray, "No API key")
        }
        return (.green, "Ready")
    }

    // MARK: - Context sources (this page + documents + other tabs teaser)

    private func contextSourcesSection() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup(isExpanded: $contextSectionExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    thisPageBadge()
                    documentsRow()
                    otherTabsTeaser()
                    if contextSectionExpanded {
                        contextPreviewSnippet()
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 4)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(PanelTokens.textSecondary)
                    Text("Context")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(PanelTokens.textPrimary)
                    contextCountBadge()
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(panelGlassTint.opacity(panelGlassTintOpacity * 0.75))
            .tint(PanelTokens.textSecondary)
            .accessibilityLabel("Context sources")
            .accessibilityHint("Expand to see page, documents, and what will be sent")
        }
    }

    @ViewBuilder
    private func thisPageBadge() -> some View {
        HStack(spacing: 6) {
            if isLoadingContext {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(PanelTokens.textSecondary)
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 10))
                    .foregroundColor(PanelTokens.textSecondary)
            }
            Text(thisPageLabel())
                .font(.system(size: 11))
                .foregroundColor(PanelTokens.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(PanelTokens.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityLabel("This page: \(thisPageLabel())")
    }

    private func thisPageLabel() -> String {
        if let title = pageTitle, !title.isEmpty { return title }
        if let host = webViewWrapper.currentURL?.host { return host }
        return "Loading…"
    }

    @ViewBuilder
    private func contextCountBadge() -> some View {
        let count = 1 + (attachedDocuments.isEmpty ? 0 : attachedDocuments.count)
        if count > 0 {
            Text("\(count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(PanelTokens.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(PanelTokens.surfaceElevated)
                .clipShape(Capsule())
        }
    }

    private func documentsRow() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Documents")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(PanelTokens.textSecondary)
                if !attachedDocuments.isEmpty {
                    Text("(\(attachedDocuments.count))")
                        .font(.caption2)
                        .foregroundColor(PanelTokens.textTertiary)
                }
                Spacer()
                Button(action: { documentPickerPresented = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 11))
                        Text("Add file")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(PanelTokens.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add file")
                .accessibilityHint("Attach a document for AI context")
            }
            if let err = documentError {
                Text(err)
                    .font(.system(size: 10))
                    .foregroundColor(PanelTokens.errorText)
                    .lineLimit(2)
                    .accessibilityLabel("Document error: \(err)")
            }
            if attachedDocuments.isEmpty {
                Text("No documents")
                    .font(.system(size: 11))
                    .foregroundColor(PanelTokens.textTertiary)
                    .padding(.vertical, 4)
                    .accessibilityLabel("No documents attached")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(attachedDocuments) { doc in
                            documentChip(doc)
                        }
                    }
                }
                .frame(maxHeight: 36)
            }
        }
        .onDrop(of: [.fileURL, .pdf, .plainText, .utf8PlainText], isTargeted: nil) { providers in
            handleDocumentDrop(providers: providers)
        }
        .fileImporter(
            isPresented: $documentPickerPresented,
            allowedContentTypes: [UTType.pdf, .plainText, .utf8PlainText, .commaSeparatedText, .xml, .html],
            allowsMultipleSelection: true
        ) { result in
            documentError = nil
            switch result {
            case .success(let urls):
                for url in urls {
                    guard url.startAccessingSecurityScopedResource() else { continue }
                    defer { url.stopAccessingSecurityScopedResource() }
                    addDocument(from: url)
                }
            case .failure(let error):
                documentError = error.localizedDescription
            }
        }
    }

    private func documentChip(_ doc: AttachedDocument) -> some View {
        HStack(spacing: 6) {
            Image(systemName: doc.displayName.lowercased().hasSuffix(".pdf") ? "doc.fill" : "doc.text.fill")
                .font(.system(size: 10))
                .foregroundColor(PanelTokens.textSecondary)
            Text(doc.displayName)
                .font(.system(size: 11))
                .foregroundColor(PanelTokens.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Button(action: { removeAttachedDocument(id: doc.id) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(PanelTokens.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(doc.displayName)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(PanelTokens.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func otherTabsTeaser() -> some View {
        HStack(spacing: 6) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 10))
                .foregroundColor(PanelTokens.textTertiary)
            Text(otherTabsMicrocopy)
                .font(.system(size: 10))
                .foregroundColor(PanelTokens.textTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PanelTokens.surfaceElevated.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityLabel(otherTabsMicrocopy)
        .accessibilityHint("Feature not yet available")
    }

    @ViewBuilder
    private func contextPreviewSnippet() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let url = webViewWrapper.currentURL {
                Text(url.absoluteString)
                    .font(.system(size: 10))
                    .foregroundColor(PanelTokens.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if let text = pageText, !text.isEmpty {
                Text("\(text.prefix(180))\(text.count > 180 ? "…" : "")")
                    .font(.system(size: 10))
                    .foregroundColor(PanelTokens.textTertiary)
                    .lineLimit(3)
            }
            if includeSelection, let sel = selectedText, !sel.isEmpty {
                Text("Selection: \(sel.prefix(80))\(sel.count > 80 ? "…" : "")")
                    .font(.system(size: 10))
                    .foregroundColor(PanelTokens.textTertiary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Conversation stream

    private func conversationStream() -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if messages.isEmpty {
                        emptyConversationState()
                    } else {
                        ForEach(messages) { msg in
                            ChatBubble(message: msg, isUser: msg.role == .user, fontSize: chatFontSize) { url in
                                openLinkInNewTab(url)
                            }
                        }
                        if isSending {
                            loadingIndicator()
                        }
                        if let err = errorMessage {
                            errorInlineView(message: err)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .frame(maxHeight: .infinity)
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation(.easeOut(duration: 0.18)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .background(Color.clear)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Conversation")
    }

    private func emptyConversationState() -> some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 32))
                .foregroundColor(PanelTokens.textTertiary)
            Text("Ask about this page, or attach a document.")
                .font(.system(size: 13))
                .foregroundColor(PanelTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No messages yet. Ask about this page or attach a document.")
    }

    private func loadingIndicator() -> some View {
        HStack(alignment: .top, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(PanelTokens.textTertiary)
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            Text("Thinking…")
                .font(.system(size: chatFontSize))
                .foregroundColor(PanelTokens.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("Assistant is thinking")
    }

    private func errorInlineView(message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(PanelTokens.errorText)
            Text(message)
                .font(.system(size: chatFontSize))
                .foregroundColor(PanelTokens.errorText)
                .lineLimit(3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PanelTokens.errorText.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: PanelTokens.cornerRadius, style: .continuous))
        .accessibilityLabel("Error: \(message)")
    }

    // MARK: - Input area

    private func inputArea() -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                let isGlowActive = isInputFocused || !inputText.isEmpty
                GrowingTextEditor(
                    text: $inputText,
                    placeholder: "Message…",
                    minHeight: 36,
                    fontSize: chatFontSize,
                    isFocused: $isInputFocused,
                    onSubmit: sendCommand
                )
                .padding(12)
                .frame(maxHeight: 80)
                .background(PanelTokens.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: PanelTokens.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PanelTokens.cornerRadius, style: .continuous)
                        .stroke(isGlowActive ? PanelTokens.accent : PanelTokens.accentDim, lineWidth: isGlowActive ? 1.5 : 1)
                )
                .animation(.easeInOut(duration: 0.2), value: isGlowActive)
                .accessibilityLabel("Message input")
                .accessibilityHint("Type your message. Enter to send.")

                Button(action: sendCommand) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(inputText.isEmpty || isSending ? PanelTokens.textTertiary : PanelTokens.textPrimary)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty || isSending)
                .keyboardShortcut(.return, modifiers: .command)
                .help("Send (Enter or ⌘↵)")
                .accessibilityLabel("Send message")
                .accessibilityHint(inputText.isEmpty ? "Type a message first" : "Sends your message")
            }

            HStack(spacing: 12) {
                Toggle(isOn: $includeSelection) {
                    Text("Include selection")
                        .font(.system(size: 11))
                        .foregroundColor(PanelTokens.textSecondary)
                }
                .toggleStyle(.checkbox)
                .tint(PanelTokens.textSecondary)
                .onChange(of: includeSelection) { _, on in
                    if on { fetchSelectedText() }
                    else { selectedText = nil }
                }
                .accessibilityLabel("Include selection")
                .accessibilityHint("Add current page selection to context")

                if let msg = actionProposedMessage {
                    Text(msg)
                        .font(.caption2)
                        .foregroundColor(PanelTokens.textSecondary)
                }
                if let err = errorMessage {
                    Text(err)
                        .font(.caption2)
                        .foregroundColor(PanelTokens.errorText)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(panelGlassTint.opacity(panelGlassTintOpacity * 0.75))
    }

    private func sendIfEnter() {
        if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sendCommand()
        }
    }

    private struct ChatBubble: View {
        let message: ChatMessage
        let isUser: Bool
        let fontSize: CGFloat
        let onLinkTapped: (URL) -> Void

        private let userBubbleColor = Color(white: 0.22)
        private let assistantTextColor = Color(white: 0.94)
        private let linkColor = Color(red: 0.4, green: 0.6, blue: 1.0)

        var body: some View {
            HStack(alignment: .top, spacing: 0) {
                if isUser { Spacer(minLength: 32) }
                if isUser {
                    messageTextView
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(userBubbleColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    messageTextView
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !isUser { Spacer(minLength: 32) }
            }
        }

        private func styledAttributedString() -> AttributedString? {
            guard var attributed = try? AttributedString(markdown: message.text) else {
                return nil
            }
            // Style links to be visible (blue + underlined)
            for run in attributed.runs {
                if run.link != nil {
                    let range = run.range
                    attributed[range].foregroundColor = linkColor
                    attributed[range].underlineStyle = .single
                }
            }
            return attributed
        }

        @ViewBuilder
        private var messageTextView: some View {
            Group {
                if let attributed = styledAttributedString() {
                    Text(attributed)
                } else {
                    Text(message.text)
                }
            }
            .font(.system(size: fontSize))
            .foregroundColor(isUser ? .white : assistantTextColor)
            .textSelection(.enabled)
            .multilineTextAlignment(.leading)
            .lineSpacing(isUser ? 0 : 5)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.openURL, OpenURLAction { url in
                onLinkTapped(url)
                return .handled
            })
            .accessibilityElement(children: .combine)
            .accessibilityLabel(isUser ? "You: \(message.text)" : "Assistant: \(message.text)")
        }
    }

    private func openLinkInNewTab(_ url: URL) {
        // Open URL in a new browser tab
        if let tabManager = webViewWrapper.tabManager {
            let newTabId = tabManager.newTab(url: url)
            webViewWrapper.load(url: url, in: newTabId)
        }
    }

    private func fetchSelectedText() {
        webViewWrapper.evaluateSelectedText { text in
            selectedText = text
        }
    }

    // Legacy contextPreviewContent removed; see contextPreviewSnippet() and contextSourcesSection()

    @ViewBuilder
    private func _unused_contextPreviewContent() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let url = webViewWrapper.currentURL {
                Text("URL: \(url.absoluteString)")
                    .foregroundColor(Color(white: 0.65))
                    .lineLimit(1)
            }
            if let title = pageTitle, !title.isEmpty {
                Text("Title: \(title)")
                    .foregroundColor(Color(white: 0.65))
                    .lineLimit(1)
            }
            if let text = pageText, !text.isEmpty {
                Text("Page: \(text.prefix(200))\(text.count > 200 ? "…" : "")")
                    .foregroundColor(Color(white: 0.65))
                    .lineLimit(3)
            }
            if includeSelection, let sel = selectedText, !sel.isEmpty {
                Text("Selection: \(sel.prefix(100))\(sel.count > 100 ? "…" : "")")
                    .foregroundColor(Color(white: 0.65))
                    .lineLimit(2)
            }
            if !attachedDocuments.isEmpty {
                Text("Documents: \(attachedDocuments.map(\.displayName).joined(separator: ", "))")
                    .foregroundColor(Color(white: 0.65))
                    .lineLimit(2)
                ForEach(attachedDocuments) { doc in
                    Text("  “\(doc.displayName)”: \(doc.extractedText.prefix(80))\(doc.extractedText.count > 80 ? "…" : "")")
                        .foregroundColor(Color(white: 0.55))
                        .lineLimit(1)
                }
            }
            if isLoadingContext {
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func attachedDocumentsSection() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Attached documents")
                    .font(.caption)
                    .foregroundColor(PanelTokens.textSecondary)
                if !attachedDocuments.isEmpty {
                    Text("(\(attachedDocuments.count))")
                        .font(.caption2)
                        .foregroundColor(PanelTokens.textSecondary.opacity(0.8))
                }
                Spacer()
                Button(action: { documentPickerPresented = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                        Text("Add file")
                            .font(.caption)
                    }
                    .foregroundColor(PanelTokens.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)

            if let err = documentError {
                Text(err)
                    .font(.caption2)
                    .foregroundColor(.red.opacity(0.9))
                    .padding(.horizontal, 18)
            }

            if !attachedDocuments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(attachedDocuments) { doc in
                            HStack(spacing: 6) {
                                Image(systemName: doc.displayName.hasSuffix(".pdf") ? "doc.fill" : "doc.text.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(PanelTokens.textSecondary)
                                Text(doc.displayName)
                                    .font(.caption)
                                    .foregroundColor(PanelTokens.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Button(action: { removeAttachedDocument(id: doc.id) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(PanelTokens.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color(white: 0.14))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 6)
                }
                .frame(maxHeight: 32)
            }
        }
        .background(PanelTokens.panelBgSecondary.opacity(0.6))
        .onDrop(of: [.fileURL, .pdf, .plainText, .utf8PlainText], isTargeted: nil) { providers in
            handleDocumentDrop(providers: providers)
        }
        .fileImporter(
            isPresented: $documentPickerPresented,
            allowedContentTypes: [UTType.pdf, .plainText, .utf8PlainText, .commaSeparatedText, .xml, .html],
            allowsMultipleSelection: true
        ) { result in
            documentError = nil
            switch result {
            case .success(let urls):
                for url in urls {
                    guard url.startAccessingSecurityScopedResource() else { continue }
                    defer { url.stopAccessingSecurityScopedResource() }
                    addDocument(from: url)
                }
            case .failure(let error):
                documentError = error.localizedDescription
            }
        }
    }

    private func addDocument(from url: URL) {
        guard DocumentTextExtractor.isSupported(url) else {
            documentError = "Unsupported format. Use PDF, TXT, MD, JSON, CSV, XML, or HTML."
            return
        }
        guard let text = DocumentTextExtractor.extractText(from: url), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            documentError = "Could not read text from “\(url.lastPathComponent)”."
            return
        }
        let name = url.lastPathComponent
        let doc = AttachedDocument(displayName: name, extractedText: text, fileURL: url)
        attachedDocuments.append(doc)
        documentError = nil
    }

    private func removeAttachedDocument(id: UUID) {
        attachedDocuments.removeAll { $0.id == id }
    }

    private func handleDocumentDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let u = url else { return }
            DispatchQueue.main.async {
                addDocument(from: u)
            }
        }
        return true
    }

    private func close() {
        stopContextRefreshTimer()
        isPresented = false
        inputText = ""
        errorMessage = nil
        isSending = false
        actionProposedMessage = nil
        attachedDocuments = []
    }

    /// Starts a timer to refresh context every 3 seconds.
    private func startContextRefreshTimer() {
        stopContextRefreshTimer()
        contextRefreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            loadPageContext()
        }
    }

    /// Stops the context refresh timer.
    private func stopContextRefreshTimer() {
        contextRefreshTimer?.invalidate()
        contextRefreshTimer = nil
    }

    /// Loads page context (title + visible text) when panel appears.
    private func loadPageContext() {
        isLoadingContext = true
        let group = DispatchGroup()

        group.enter()
        webViewWrapper.evaluatePageTitle { title in
            pageTitle = title
            group.leave()
        }

        group.enter()
        webViewWrapper.evaluateVisibleText(maxChars: 4000) { text in
            pageText = text
            group.leave()
        }

        group.notify(queue: .main) {
            isLoadingContext = false
        }
    }

    /// Builds context string from page metadata and/or selection.
    /// Page context is always included for agentic behavior.
    private func buildContextString() -> String? {
        var parts: [String] = []

        // Always include page context
        if let url = webViewWrapper.currentURL {
            parts.append("URL: \(url.absoluteString)")
        }
        if let title = pageTitle, !title.isEmpty {
            parts.append("Title: \(title)")
        }
        if let text = pageText, !text.isEmpty {
            parts.append("Page content:\n\(text)")
        }

        if includeSelection, let sel = selectedText, !sel.isEmpty {
            parts.append("Selection:\n\(sel)")
        }

        for doc in attachedDocuments {
            parts.append("Document \"\(doc.displayName)\":\n\(doc.textForContext)")
        }

        return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
    }

    private func sendCommand() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSending = true
        errorMessage = nil
        actionProposedMessage = nil

        let userMsg = ChatMessage(
            role: .user,
            text: trimmed,
            pageURL: webViewWrapper.currentURL?.absoluteString,
            pageTitle: pageTitle
        )
        messages.append(userMsg)
        inputText = ""

        let context = buildContextString()
        proceedWithSend(prompt: trimmed, context: context)
    }

    private func proceedWithSend(prompt: String, context: String?) {
        let promptToSend = prompt
        let contextToSend = context
        
        // Only send last 4-6 messages for immediate context to save tokens
        let recentContext = messages.dropLast().suffix(6)

        gemini.generate(
            prompt: promptToSend,
            context: contextToSend,
            recentMessages: Array(recentContext),
            conversationSummary: conversationSummary
        ) { result in
            DispatchQueue.main.async {
                isSending = false

                switch result {
                case .success(let data):
                    if let response = try? JSONDecoder().decode(LLMResponse.self, from: data) {
                        let assistantMsg = ChatMessage(
                            role: .assistant,
                            text: response.text,
                            pageURL: webViewWrapper.currentURL?.absoluteString,
                            pageTitle: pageTitle
                        )
                        messages.append(assistantMsg)
                        
                        // Auto-summarize every 8 messages
                        checkAndSummarize()
                        
                        if response.action != nil {
                            onActionProposed(response)
                            actionProposedMessage = "Action proposed"
                        }
                    } else {
                        errorMessage = "Failed to parse response"
                    }

                case .failure(let error):
                    let msg = error.localizedDescription
                    errorMessage = msg
                    let errorMsg = ChatMessage(role: .assistant, text: "Error: \(msg)")
                    messages.append(errorMsg)
                    actionProposedMessage = nil
                }
            }
        }
    }
    
    private func checkAndSummarize() {
        // Auto-summarize every 8 messages (4 exchanges)
        let messagesToSummarize = messages.count - lastSummarizedMessageCount
        
        if messagesToSummarize >= 8 {
            let messagesToProcess = Array(messages.suffix(messagesToSummarize))
            
            gemini.summarizeConversation(messages: messagesToProcess) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let summary):
                        // Append to existing summary or create new one
                        if let existing = conversationSummary {
                            conversationSummary = "\(existing)\n\nRecent: \(summary)"
                        } else {
                            conversationSummary = summary
                        }
                        lastSummarizedMessageCount = messages.count
                        
                        // Save summary to history if we have a tab ID
                        if let tabId = tabId {
                            let summaryObj = ConversationSummary(
                                tabId: tabId,
                                summary: summary,
                                messageRange: (messages.count - messagesToSummarize)...(messages.count - 1)
                            )
                            HistoryManager.shared.addConversationSummary(tabId: tabId, summary: summaryObj)
                        }
                        
                    case .failure:
                        // Silently fail - summarization is optimization, not critical
                        break
                    }
                }
            }
        }
    }
}

// MARK: - Growing multiline text editor

private struct TextHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct GrowingTextEditor: View {
    @Binding var text: String
    var placeholder: String
    var minHeight: CGFloat
    var fontSize: CGFloat = 13
    @FocusState.Binding var isFocused: Bool
    var onSubmit: (() -> Void)? = nil

    /// Height from content; no upper bound so the whole query is visible.
    @State private var contentHeight: CGFloat = 36

    private var font: Font { Font.system(size: fontSize) }
    private let textColor = Color(white: 0.9)
    private let placeholderColor = Color(white: 0.5)

    private var boxHeight: CGFloat {
        max(minHeight, contentHeight)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Measure content height using invisible text (opacity 0 so no double-text overlay)
            Text(text.isEmpty ? " " : text)
                .font(font)
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(8)
                .opacity(0)
                .background(
                    GeometryReader { g in
                        Color.clear.preference(key: TextHeightKey.self, value: g.size.height)
                    }
                )
                .allowsHitTesting(false)

            EnterSubmittingTextEditor(
                text: $text,
                fontSize: fontSize,
                minHeight: minHeight,
                onSubmit: onSubmit
            )
            .focused($isFocused)
            .frame(height: boxHeight)

            if text.isEmpty {
                Text(placeholder)
                    .font(font)
                    .foregroundColor(placeholderColor)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .frame(height: boxHeight)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: boxHeight)
        .onPreferenceChange(TextHeightKey.self) { h in
            contentHeight = max(minHeight, h)
        }
    }
}

// MARK: - Enter-submitting NSTextView (Return/Enter sends, Shift+Return newline)

/// NSTextView subclass that submits on Enter/Return and inserts newline on Shift+Enter.
private final class EnterSubmittingField: NSTextView {
    var onSubmit: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let isReturn = event.keyCode == 36   // main Return
        let isKeypadEnter = event.keyCode == 76
        let isSubmitKey = (isReturn || isKeypadEnter) && !event.modifierFlags.contains(.shift)
        if isSubmitKey {
            onSubmit?()
            return
        }
        super.keyDown(with: event)
    }
}

private final class EnterSubmittingTextView: NSScrollView {
    private let onSubmit: (() -> Void)?
    private var textView: EnterSubmittingField!
    var onTextChange: ((String) -> Void)?
    var fontSize: CGFloat = 13 { didSet { textView?.font = .systemFont(ofSize: fontSize) } }

    init(onSubmit: (() -> Void)?, fontSize: CGFloat) {
        self.onSubmit = onSubmit
        self.fontSize = fontSize
        super.init(frame: .zero)
        hasVerticalScroller = true
        hasHorizontalScroller = false
        autohidesScrollers = true
        borderType = .noBorder
        drawsBackground = false

        let tv = EnterSubmittingField()
        tv.onSubmit = onSubmit
        tv.isRichText = false
        tv.drawsBackground = false
        tv.font = .systemFont(ofSize: fontSize)
        tv.textColor = NSColor(white: 0.9, alpha: 1)
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        let contentSize = self.contentSize
        tv.frame = NSRect(origin: .zero, size: contentSize)
        tv.minSize = NSSize(width: 0, height: contentSize.height)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]

        if let container = tv.textContainer {
            container.widthTracksTextView = true
            container.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)}
        tv.isSelectable = true
        documentView = tv
        textView = tv
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setDelegate(_ delegate: NSTextViewDelegate?) {
        textView.delegate = delegate
    }

    func setText(_ string: String) {
        textView.string = string
    }
}

private struct EnterSubmittingTextEditor: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var minHeight: CGFloat
    var onSubmit: (() -> Void)?

    func makeNSView(context: Context) -> EnterSubmittingTextView {
        let view = EnterSubmittingTextView(onSubmit: onSubmit, fontSize: fontSize)
        view.setText(text)
        view.setDelegate(context.coordinator)
        return view
    }

    func updateNSView(_ nsView: EnterSubmittingTextView, context: Context) {
        if let tv = nsView.documentView as? EnterSubmittingField {
            if tv.string != text { tv.string = text }
            tv.onSubmit = onSubmit
        }
        nsView.fontSize = fontSize
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EnterSubmittingTextEditor

        init(_ parent: EnterSubmittingTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

// MARK: - Attached documents (upload for AI context)

private struct AttachedDocument: Identifiable {
    let id: UUID
    let displayName: String
    let extractedText: String
    let fileURL: URL?

    init(id: UUID = UUID(), displayName: String, extractedText: String, fileURL: URL? = nil) {
        self.id = id
        self.displayName = displayName
        self.extractedText = extractedText
        self.fileURL = fileURL
    }

    /// Max chars per document in context to avoid token overflow.
    static let maxCharsInContext: Int = 12_000

    var textForContext: String {
        if extractedText.count <= Self.maxCharsInContext { return extractedText }
        return String(extractedText.prefix(Self.maxCharsInContext)) + "\n\n[Document truncated for length.]"
    }
}

private enum DocumentTextExtractor {
    static let supportedExtensions: Set<String> = ["pdf", "txt", "md", "json", "csv", "xml", "html"]

    static func extractText(from url: URL) -> String? {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            guard let doc = PDFDocument(url: url) else { return nil }
            return doc.string
        case "txt", "md", "json", "csv", "xml", "html":
            return (try? String(contentsOf: url, encoding: .utf8))
                ?? (try? String(contentsOf: url, encoding: .utf16))
        default:
            return nil
        }
    }

    static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }
}
