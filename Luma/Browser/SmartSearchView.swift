// Luma — SmartSearch: full-viewport new tab page with intent classification
import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PDFKit

// MARK: - State machine

private enum SearchViewState: Equatable {
    case idle
    case classifying
    case ambiguous
    case aiChat
    case searching
}

// MARK: - Design tokens (matches start page / side panel glassmorphism)

private enum SmartTokens {
    static let textPrimary   = Color(white: 0.94)
    static let textSecondary = Color(white: 0.62)
    static let textTertiary  = Color(white: 0.50)
    static let accent        = Color(red: 0.45, green: 0.58, blue: 0.72)
    static let errorText     = Color(red: 0.95, green: 0.55, blue: 0.55)
    static let surfaceElevated = Color(white: 0.14)
    static let cornerRadius: CGFloat  = 14
    static let barMaxWidth: CGFloat   = 600
    static let chatMaxWidth: CGFloat  = 720
}

// MARK: - SmartSearchView

struct SmartSearchView: View {
    let gemini: GeminiClient
    let ollama: OllamaClient
    let tabManager: TabManager
    let webViewWrapper: WebViewWrapper
    var tabId: UUID?
    @Binding var messages: [ChatMessage]
    let onNavigate: (URL) -> Void

    @AppStorage("luma_ai_provider")    private var aiProviderRaw: String = AIProvider.gemini.rawValue
    @AppStorage("luma_ollama_base_url") private var ollamaBaseURL: String = "http://127.0.0.1:11434"
    @AppStorage("luma_ollama_model")    private var ollamaModel: String = ""
    @AppStorage("luma_ai_panel_font_size") private var fontSizeRaw: Int = 13

    @State private var viewState: SearchViewState = .idle
    @State private var inputText: String = ""
    @State private var isSending: Bool = false
    @State private var errorMessage: String? = nil
    @FocusState private var isInputFocused: Bool

    @State private var breatheOpacity: Double = 0.12
    @State private var pulseOpacity: Double = 0.3
    @State private var ambiguousPillsVisible: Bool = false
    @State private var hasGeneratedTitle: Bool = false

    // Context system
    @State private var attachedDocuments: [SmartAttachedDocument] = []
    @State private var documentPickerPresented: Bool = false
    @State private var documentError: String? = nil
    @State private var includedOtherTabIds: [UUID] = []
    @State private var otherTabContexts: [UUID: (title: String?, text: String?)] = [:]
    @State private var addTabsSheetPresented: Bool = false

    private var aiProvider: AIProvider { AIProvider(rawValue: aiProviderRaw) ?? .gemini }
    private var fontSize: CGFloat { CGFloat(fontSizeRaw) }

    private let classifier = QueryClassifier()

    var body: some View {
        ZStack {
            background

            switch viewState {
            case .idle, .classifying:
                centeredBarLayout
            case .ambiguous:
                ambiguousLayout
            case .aiChat:
                chatLayout
            case .searching:
                EmptyView()
            }
        }
        .onAppear {
            if !messages.isEmpty {
                viewState = .aiChat
            }
            isInputFocused = true
        }
        .sheet(isPresented: $addTabsSheetPresented) {
            SmartAddTabSheet(
                tabManager: tabManager,
                currentTabId: tabId,
                alreadyIncluded: Set(includedOtherTabIds),
                onAdd: { id in
                    if !includedOtherTabIds.contains(id) {
                        includedOtherTabIds.append(id)
                        loadTabContext(for: id)
                    }
                }
            )
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

    // MARK: - Background

    private var background: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow, state: .active)
            startPageGlassTint.opacity(startPageGlassTintOpacity)
        }
        .ignoresSafeArea()
    }

    // MARK: - Centered bar (idle + classifying)

    private var centeredBarLayout: some View {
        VStack {
            Spacer()
            searchBar(centered: true)
                .frame(maxWidth: SmartTokens.barMaxWidth)
            Spacer()
        }
        .padding(.horizontal, 32)
        .transition(.opacity)
    }

    // MARK: - Ambiguous layout

    private var ambiguousLayout: some View {
        VStack(spacing: 0) {
            Spacer()
            searchBar(centered: true)
                .frame(maxWidth: SmartTokens.barMaxWidth)
                .padding(.bottom, 16)
            ambiguousPills
            Spacer()
        }
        .padding(.horizontal, 32)
        .transition(.opacity)
    }

    private var ambiguousPills: some View {
        HStack(spacing: 12) {
            pillButton(label: "Search Google", icon: "magnifyingglass") {
                performSearch(inputText)
            }
            .opacity(ambiguousPillsVisible ? 1 : 0)
            .offset(y: ambiguousPillsVisible ? 0 : 12)

            pillButton(label: "Ask AI", icon: "sparkles") {
                transitionToChat()
            }
            .opacity(ambiguousPillsVisible ? 1 : 0)
            .offset(y: ambiguousPillsVisible ? 0 : 12)
            .animation(.easeOut(duration: 0.3).delay(0.08), value: ambiguousPillsVisible)
        }
        .animation(.easeOut(duration: 0.3), value: ambiguousPillsVisible)
        .onAppear {
            withAnimation { ambiguousPillsVisible = true }
        }
    }

    private func pillButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(SmartTokens.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - AI Chat layout

    private var chatLayout: some View {
        VStack(spacing: 0) {
            chatThread
            chatInputBar
        }
        .transition(.opacity)
    }

    private var chatThread: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, msg in
                        SmartChatBubble(
                            message: msg,
                            isUser: msg.role == .user,
                            fontSize: fontSize,
                            onRetry: msg.role == .assistant ? { retryResponse(at: index) } : nil,
                            onEdit: msg.role == .user ? { editMessage(at: index) } : nil
                        )
                        .frame(maxWidth: SmartTokens.chatMaxWidth,
                               alignment: msg.role == .user ? .trailing : .leading)
                    }
                    if isSending { thinkingIndicator }
                    if let err = errorMessage { errorBanner(err) }
                }
                .frame(maxWidth: SmartTokens.chatMaxWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var thinkingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { _ in
                Circle().fill(Color.white.opacity(0.4)).frame(width: 5, height: 5)
            }
            Text("Thinking\u{2026}")
                .font(.system(size: fontSize))
                .foregroundColor(Color.white.opacity(0.5))
        }
        .frame(maxWidth: SmartTokens.chatMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 32)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(SmartTokens.errorText)
            Text(message)
                .font(.system(size: fontSize))
                .foregroundColor(SmartTokens.errorText)
                .lineLimit(3)
        }
        .padding(12)
        .frame(maxWidth: SmartTokens.chatMaxWidth, alignment: .leading)
        .background(SmartTokens.errorText.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: SmartTokens.cornerRadius, style: .continuous))
    }

    private var chatInputBar: some View {
        let isGlowActive = isInputFocused || !inputText.isEmpty
        return VStack(spacing: 0) {
            // Context chips row
            if !includedOtherTabIds.isEmpty || !attachedDocuments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(includedOtherTabIds, id: \.self) { otherId in
                            SmartContextChip(
                                label: otherTabLabel(tabId: otherId),
                                icon: "square.stack.3d.up",
                                onRemove: { removeIncludedOtherTab(id: otherId) }
                            )
                        }
                        ForEach(attachedDocuments) { doc in
                            SmartContextChip(
                                label: doc.displayName,
                                icon: doc.displayName.lowercased().hasSuffix(".pdf") ? "doc.fill" : "doc.text.fill",
                                onRemove: { removeAttachedDocument(id: doc.id) }
                            )
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .frame(height: 32)
                .frame(maxWidth: SmartTokens.chatMaxWidth)
                .padding(.bottom, 6)
            }

            HStack(alignment: .bottom, spacing: 0) {
                Menu {
                    Button(action: { addTabsSheetPresented = true }) {
                        Label("Tabs", systemImage: "square.stack.3d.up")
                    }
                    Button(action: { documentPickerPresented = true }) {
                        Label("Files", systemImage: "doc.fill")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(SmartTokens.textSecondary)
                        .frame(width: 32, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .menuStyle(.borderlessButton)

                SmartGrowingInput(
                    text: $inputText,
                    placeholder: "Follow up\u{2026}",
                    fontSize: fontSize,
                    isFocused: $isInputFocused,
                    onSubmit: sendChatMessage
                )
                .frame(maxWidth: .infinity)

                Button(action: sendChatMessage) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(inputText.isEmpty || isSending
                                         ? Color.white.opacity(0.3)
                                         : Color.white.opacity(0.9))
                        .frame(width: 28, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty || isSending)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: SmartTokens.chatMaxWidth)
            .background(
                RoundedRectangle(cornerRadius: SmartTokens.cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: SmartTokens.cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: SmartTokens.cornerRadius, style: .continuous)
                    .stroke(isGlowActive ? Color.white.opacity(0.25) : Color.clear, lineWidth: 1.5)
            )
            .animation(.easeInOut(duration: 0.06), value: isGlowActive)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 20)
    }

    // MARK: - Search bar

    private func searchBar(centered: Bool) -> some View {
        let isGlowActive = isInputFocused || !inputText.isEmpty
        let showPulse = viewState == .classifying

        return HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(SmartTokens.textTertiary)

            TextField("Search or ask anything\u{2026}", text: $inputText)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .foregroundColor(SmartTokens.textPrimary)
                .focused($isInputFocused)
                .onSubmit { handleSubmit() }

            if showPulse {
                Circle()
                    .fill(SmartTokens.accent)
                    .frame(width: 8, height: 8)
                    .opacity(pulseOpacity)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                            pulseOpacity = 0.9
                        }
                    }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: SmartTokens.cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: SmartTokens.cornerRadius, style: .continuous)
                .stroke(
                    isGlowActive
                        ? Color.white.opacity(0.25)
                        : Color.white.opacity(breatheOpacity),
                    lineWidth: 1.5
                )
        )
        .animation(.easeInOut(duration: 0.06), value: isGlowActive)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                breatheOpacity = 0.06
            }
        }
    }

    // MARK: - Actions

    private func handleSubmit() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard viewState == .idle || viewState == .ambiguous else { return }

        withAnimation(.easeOut(duration: 0.2)) { viewState = .classifying }

        Task {
            let intent: QueryIntent
            if aiProvider == .ollama {
                intent = await classifier.classify(
                    query: trimmed, using: ollama,
                    baseURL: ollamaBaseURL, model: ollamaModel
                )
            } else {
                intent = QueryClassifier.heuristic(trimmed)
            }

            await MainActor.run {
                switch intent {
                case .search:
                    performSearch(trimmed)
                case .ai:
                    transitionToChat()
                case .ambiguous:
                    withAnimation(.easeOut(duration: 0.25)) {
                        ambiguousPillsVisible = false
                        viewState = .ambiguous
                    }
                }
            }
        }
    }

    private func performSearch(_ query: String) {
        withAnimation(.easeOut(duration: 0.15)) { viewState = .searching }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        if let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
            onNavigate(url)
        }
    }

    private func transitionToChat() {
        let firstMessage = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !firstMessage.isEmpty else { return }

        messages.append(ChatMessage(role: .user, text: firstMessage))
        inputText = ""

        if let id = tabId {
            let aiURL = URL(string: "luma://ai/\(id.uuidString)")!
            tabManager.navigate(tab: id, to: aiURL)
            tabManager.updateTitle(tab: id, title: heuristicTitle(firstMessage))
        }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            viewState = .aiChat
        }

        sendAIRequest(prompt: firstMessage, isFirstMessage: true)
    }

    private func sendChatMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        messages.append(ChatMessage(role: .user, text: trimmed))
        inputText = ""
        sendAIRequest(prompt: trimmed)
    }

    private func sendAIRequest(prompt: String, isFirstMessage: Bool = false) {
        isSending = true
        errorMessage = nil

        let recentContext = Array(messages.dropLast().suffix(6))
        let context = buildContextString()
        let capturedQuery = isFirstMessage ? prompt : nil

        let handler: (Result<Data, Error>) -> Void = { result in
            DispatchQueue.main.async {
                isSending = false
                switch result {
                case .success(let data):
                    if let response = try? JSONDecoder().decode(LLMResponse.self, from: data) {
                        messages.append(ChatMessage(role: .assistant, text: response.text))
                        if let query = capturedQuery {
                            generateAITitle(for: query)
                        }
                    } else {
                        errorMessage = "Failed to parse response"
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }

        switch aiProvider {
        case .gemini:
            gemini.generate(prompt: prompt, context: context,
                            recentMessages: recentContext, completion: handler)
        case .ollama:
            ollama.generate(baseURLString: ollamaBaseURL, model: ollamaModel,
                            prompt: prompt, context: context,
                            recentMessages: recentContext, completion: handler)
        }
    }

    // MARK: - Retry / Edit

    private func retryResponse(at index: Int) {
        guard index < messages.count, messages[index].role == .assistant else { return }
        guard !isSending else { return }

        let userIndex = index - 1
        guard userIndex >= 0, messages[userIndex].role == .user else { return }
        let userPrompt = messages[userIndex].text

        messages.removeSubrange(index...)
        sendAIRequest(prompt: userPrompt)
    }

    private func editMessage(at index: Int) {
        guard index < messages.count, messages[index].role == .user else { return }

        inputText = messages[index].text
        messages.removeSubrange(index...)
        isInputFocused = true
    }

    // MARK: - Tab title

    private func heuristicTitle(_ query: String) -> String {
        let maxLen = 25
        if query.count <= maxLen { return query }
        let prefix = String(query.prefix(maxLen))
        if let lastSpace = prefix.lastIndex(of: " ") {
            return String(prefix[..<lastSpace]) + "\u{2026}"
        }
        return prefix + "\u{2026}"
    }

    private func generateAITitle(for query: String) {
        guard !hasGeneratedTitle, let id = tabId else { return }
        hasGeneratedTitle = true

        let titlePrompt = "Generate a 2-5 word tab title for this conversation. First message: \"\(query)\". Reply with ONLY the title, no quotes, no punctuation."

        let handler: (Result<Data, Error>) -> Void = { result in
            DispatchQueue.main.async {
                if case .success(let data) = result,
                   let response = try? JSONDecoder().decode(LLMResponse.self, from: data) {
                    let title = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !title.isEmpty && title.count < 40 {
                        tabManager.updateTitle(tab: id, title: title)
                    }
                }
            }
        }

        switch aiProvider {
        case .gemini:
            gemini.generate(prompt: titlePrompt, context: nil, completion: handler)
        case .ollama:
            ollama.generate(baseURLString: ollamaBaseURL, model: ollamaModel,
                            prompt: titlePrompt, context: nil, completion: handler)
        }
    }

    // MARK: - Context helpers

    private func buildContextString() -> String? {
        var parts: [String] = []

        for id in includedOtherTabIds {
            if let url = tabManager.tabURL[id] ?? nil {
                var tp: [String] = ["URL: \(url.absoluteString)"]
                let ctx = otherTabContexts[id]
                if let t = ctx?.title ?? tabManager.tabTitle[id], !t.isEmpty {
                    tp.append("Title: \(t)")
                }
                if let text = ctx?.text, !text.isEmpty {
                    tp.append("Page content:\n\(text)")
                }
                parts.append(tp.joined(separator: "\n"))
            }
        }

        for doc in attachedDocuments {
            parts.append("Document \"\(doc.displayName)\":\n\(doc.textForContext)")
        }

        return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
    }

    private func otherTabLabel(tabId: UUID) -> String {
        if let title = tabManager.tabTitle[tabId], !title.isEmpty { return title }
        if let url = tabManager.tabURL[tabId] ?? nil, let host = url.host { return host }
        return "Tab"
    }

    private func removeIncludedOtherTab(id: UUID) {
        includedOtherTabIds.removeAll { $0 == id }
        otherTabContexts.removeValue(forKey: id)
    }

    private func loadTabContext(for id: UUID) {
        let group = DispatchGroup()
        var loadedTitle: String? = nil
        var loadedText: String? = nil

        group.enter()
        webViewWrapper.evaluatePageTitle(for: id) { title in
            loadedTitle = title; group.leave()
        }
        group.enter()
        webViewWrapper.evaluateVisibleText(for: id, maxChars: 4000) { text in
            loadedText = text; group.leave()
        }
        group.notify(queue: .main) {
            otherTabContexts[id] = (title: loadedTitle, text: loadedText)
        }
    }

    private func addDocument(from url: URL) {
        guard SmartDocumentExtractor.isSupported(url) else {
            documentError = "Unsupported format. Use PDF, TXT, MD, JSON, CSV, XML, or HTML."
            return
        }
        guard let text = SmartDocumentExtractor.extractText(from: url),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            documentError = "Could not read text from \"\(url.lastPathComponent)\"."
            return
        }
        attachedDocuments.append(SmartAttachedDocument(
            displayName: url.lastPathComponent,
            extractedText: text,
            fileURL: url
        ))
        documentError = nil
    }

    private func removeAttachedDocument(id: UUID) {
        attachedDocuments.removeAll { $0.id == id }
    }
}

// MARK: - Self-contained chat bubble with retry / edit

private struct SmartChatBubble: View {
    let message: ChatMessage
    let isUser: Bool
    let fontSize: CGFloat
    var onRetry: (() -> Void)?
    var onEdit: (() -> Void)?

    private let userBubbleColor = Color.white.opacity(0.15)
    private let linkColor = Color(red: 0.4, green: 0.6, blue: 1.0)
    @State private var isHovered: Bool = false

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 0) {
                if isUser { Spacer(minLength: 48) }
                bubbleContent
                if !isUser { Spacer(minLength: 48) }
            }
            actionRow
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if isUser {
            HStack(alignment: .bottom, spacing: 6) {
                if isHovered, let onEdit = onEdit {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.5))
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
                textView
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(userBubbleColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
            }
        } else {
            textView
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        if !isUser, let onRetry = onRetry {
            HStack(spacing: 0) {
                Button(action: onRetry) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(isHovered ? 0.6 : 0.35))
                        .frame(width: 24, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
            }
        }
    }

    private var textView: some View {
        Group {
            if let attr = markdownString {
                Text(attr)
            } else {
                Text(message.text)
            }
        }
        .font(.system(size: fontSize))
        .foregroundColor(Color.white.opacity(0.95))
        .textSelection(.enabled)
        .multilineTextAlignment(.leading)
        .lineSpacing(5)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var markdownString: AttributedString? {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        guard var attributed = try? AttributedString(markdown: message.text, options: options, baseURL: nil) else {
            return try? AttributedString(markdown: message.text)
        }
        for run in attributed.runs {
            if run.link != nil {
                attributed[run.range].foregroundColor = linkColor
                attributed[run.range].underlineStyle = .single
            }
        }
        return attributed
    }
}

// MARK: - Context chip

private struct SmartContextChip: View {
    let label: String
    let icon: String
    let onRemove: () -> Void
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Color.white.opacity(0.6))
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color.white.opacity(0.9))
                .lineLimit(1)
                .frame(maxWidth: 120, alignment: .leading)
            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.6))
                        .frame(width: 14, height: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.12)))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
    }
}

// MARK: - Growing input (self-contained, same pattern as CommandSurface)

private struct SmartGrowingInput: View {
    @Binding var text: String
    var placeholder: String
    var fontSize: CGFloat
    @FocusState.Binding var isFocused: Bool
    var onSubmit: () -> Void

    @State private var textHeight: CGFloat = 36

    private var font: Font { .system(size: fontSize) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            SmartMultilineField(
                text: $text,
                fontSize: fontSize,
                dynamicHeight: $textHeight,
                minHeight: 36,
                onSubmit: onSubmit
            )
            .focused($isFocused)

            if text.isEmpty {
                Text(placeholder)
                    .font(font)
                    .foregroundColor(Color.white.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: textHeight)
        .animation(.easeOut(duration: 0.15), value: textHeight)
    }
}

private struct SmartMultilineField: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    @Binding var dynamicHeight: CGFloat
    var minHeight: CGFloat
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let tv = SmartSubmitTextView()
        tv.delegate = context.coordinator
        tv.onSubmit = onSubmit
        tv.isRichText = false
        tv.drawsBackground = false
        tv.font = .systemFont(ofSize: fontSize)
        tv.textColor = NSColor(white: 0.95, alpha: 1)
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.allowsUndo = true
        tv.textContainerInset = NSSize(width: 4, height: 6)
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = 5
        tv.defaultParagraphStyle = ps
        tv.typingAttributes[.paragraphStyle] = ps
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        scrollView.documentView = tv
        context.coordinator.textView = tv

        DispatchQueue.main.async { context.coordinator.recalculateHeight(tv) }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tv = scrollView.documentView as? SmartSubmitTextView else { return }
        if tv.string != text { tv.string = text }
        tv.onSubmit = onSubmit
        tv.font = .systemFont(ofSize: fontSize)
        if let container = tv.textContainer {
            let w = scrollView.contentSize.width
            if w > 0 { container.containerSize = NSSize(width: w, height: .greatestFiniteMagnitude) }
        }
        DispatchQueue.main.async { context.coordinator.recalculateHeight(tv) }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SmartMultilineField
        weak var textView: SmartSubmitTextView?
        init(_ parent: SmartMultilineField) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
            recalculateHeight(tv)
        }

        func recalculateHeight(_ textView: NSTextView) {
            guard let container = textView.textContainer,
                  let manager = textView.layoutManager else { return }
            manager.ensureLayout(for: container)
            let used = manager.usedRect(for: container)
            let inset = textView.textContainerInset
            let h = max(parent.minHeight, used.height + inset.height * 2)
            if abs(h - parent.dynamicHeight) > 0.5 { parent.dynamicHeight = h }
        }
    }
}

private class SmartSubmitTextView: NSTextView {
    var onSubmit: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let isReturn = event.keyCode == 36
        let isNumpad = event.keyCode == 76
        if (isReturn || isNumpad) && !event.modifierFlags.contains(.shift) {
            onSubmit?()
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) { return super.performKeyEquivalent(with: event) }
        return super.performKeyEquivalent(with: event)
    }
}

// MARK: - Add Tab Context Sheet

private struct SmartAddTabSheet: View {
    let tabManager: TabManager
    let currentTabId: UUID?
    let alreadyIncluded: Set<UUID>
    let onAdd: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    private var orderedTabs: [UUID] { tabManager.tabOrder }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add tab context")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.9))
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(Color.white.opacity(0.75))
            }
            .padding(16)

            Divider().opacity(0.2)

            ScrollView {
                VStack(spacing: 8) {
                    if orderedTabs.isEmpty {
                        Text("No tabs found.")
                            .foregroundColor(Color.white.opacity(0.55))
                            .padding(.top, 24)
                    } else {
                        ForEach(orderedTabs, id: \.self) { id in
                            tabRow(id: id)
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(minWidth: 420, minHeight: 360)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow, state: .active)
                startPageGlassTint.opacity(startPageGlassTintOpacity)
            }
        )
    }

    @ViewBuilder
    private func tabRow(id: UUID) -> some View {
        let isCurrent = (currentTabId == id)
        let isIncluded = alreadyIncluded.contains(id)
        Button(action: {
            guard !isCurrent, !isIncluded else { return }
            onAdd(id)
        }) {
            HStack(spacing: 10) {
                Image(systemName: isCurrent ? "globe" : "square.stack.3d.up")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.white.opacity(isCurrent ? 0.45 : 0.7))
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tabTitle(id: id))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.9))
                        .lineLimit(1)
                    if let subtitle = tabSubtitle(id: id) {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                Spacer()
                if isCurrent {
                    Text("Current")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.45))
                } else if isIncluded {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.55))
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isCurrent || isIncluded)
        .opacity(isCurrent ? 0.7 : 1.0)
    }

    private func tabTitle(id: UUID) -> String {
        if let t = tabManager.tabTitle[id], !t.isEmpty { return t }
        if let url = tabManager.tabURL[id] ?? nil { return url.host ?? url.absoluteString }
        return "Tab"
    }

    private func tabSubtitle(id: UUID) -> String? {
        guard let url = tabManager.tabURL[id] ?? nil else { return nil }
        return url.absoluteString.isEmpty ? nil : url.absoluteString
    }
}

// MARK: - AttachedDocument

private struct SmartAttachedDocument: Identifiable {
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

    static let maxCharsInContext: Int = 12_000

    var textForContext: String {
        if extractedText.count <= Self.maxCharsInContext { return extractedText }
        return String(extractedText.prefix(Self.maxCharsInContext)) + "\n\n[Document truncated for length.]"
    }
}

// MARK: - DocumentTextExtractor

private enum SmartDocumentExtractor {
    static let supportedExtensions: Set<String> = ["pdf", "txt", "md", "json", "csv", "xml", "html"]

    static func extractText(from url: URL) -> String? {
        switch url.pathExtension.lowercased() {
        case "pdf": return PDFDocument(url: url)?.string
        case "txt", "md", "json", "csv", "xml", "html":
            return (try? String(contentsOf: url, encoding: .utf8))
                ?? (try? String(contentsOf: url, encoding: .utf16))
        default: return nil
        }
    }

    static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }
}
