// Luma — Query intent classifier for SmartSearch
import Foundation

enum QueryIntent {
    case search
    case ai
    case ambiguous
}

struct QueryClassifier {

    // MARK: - Verb / phrase sets for heuristic classification

    private static let aiLeadingVerbs: Set<String> = [
        "write", "explain", "summarize", "compare", "help",
        "tell", "create", "make", "list", "describe",
        "analyze", "translate", "define", "suggest", "recommend",
        "generate", "rewrite", "simplify", "elaborate", "clarify",
        "draft", "compose", "plan", "outline", "brainstorm",
        "debug", "fix", "refactor", "optimize", "convert",
        "teach", "show", "give", "find", "solve"
    ]

    private static let aiQuestionStarters: Set<String> = [
        "what", "why", "how", "when", "where", "who",
        "which", "can", "could", "would", "should",
        "is", "are", "do", "does", "did", "will"
    ]

    private static let aiPhrases: [String] = [
        "help me", "give me", "tell me", "show me", "teach me",
        "what should", "what's the difference", "what is the difference",
        "how do i", "how can i", "how to", "how does",
        "why do i", "why does", "why is", "why are",
        "can you", "could you", "would you",
        "write me", "make me", "create a", "generate a",
        "rewrite this", "fix this", "debug this", "optimize this",
        "explain how", "explain why", "explain the",
        "summarize this", "summarize the",
        "what are the pros", "what are the cons",
        "pros and cons", "arguments for and against",
        "ideas for", "suggestions for", "advice on",
        "difference between", "compared to", "versus",
        "like i'm", "like im", "eli5", "in simple terms",
        "step by step", "walk me through"
    ]

    private static let searchPatterns: [String] = [
        "near me", "price of", "cost of", "how much is",
        "hours of", "address of", "phone number",
        "weather in", "weather for", "weather tomorrow",
        "flights to", "flights from", "hotels in",
        "scores today", "scores last night", "scores yesterday",
        "stock price", "stock market",
        "recipe for", "calories in",
        "release date", "when does", "when is",
        "where is", "where to buy",
        "best restaurants", "best pizza", "best coffee",
        "directions to", "map of",
        "download", "install", "login", "log in", "sign in", "sign up"
    ]

    private static let navigationSites: Set<String> = [
        "youtube", "google", "gmail", "reddit", "twitter",
        "facebook", "instagram", "tiktok", "linkedin", "github",
        "netflix", "spotify", "amazon", "ebay", "wikipedia",
        "twitch", "discord", "slack", "notion", "figma",
        "stackoverflow", "stack overflow", "hacker news",
        "craigslist", "yelp", "maps", "drive", "docs",
        "outlook", "yahoo", "bing", "chatgpt", "claude",
        "pinterest", "tumblr", "whatsapp", "telegram",
        "x.com", "threads"
    ]

    private static let ambiguousTopics: Set<String> = [
        "python", "javascript", "react", "swift", "rust",
        "java", "typescript", "css", "html", "sql",
        "docker", "kubernetes", "git", "linux", "node",
        "django", "flask", "rails", "vue", "angular",
        "machine learning", "deep learning", "neural network",
        "blockchain", "cryptocurrency", "bitcoin", "ethereum",
        "ai", "artificial intelligence",
        "stoicism", "philosophy", "meditation", "mindfulness",
        "anxiety", "depression", "therapy",
        "coffee", "wine", "cooking", "nutrition",
        "japan", "korea", "europe", "travel",
        "fitness", "yoga", "running", "gym",
        "investing", "stocks", "real estate",
        "startup", "entrepreneurship"
    ]

    // MARK: - Ollama classification

    func classify(
        query: String,
        using ollama: OllamaClient,
        baseURL: String,
        model: String
    ) async -> QueryIntent {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .search }

        let modelTrimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelTrimmed.isEmpty, !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Self.heuristic(trimmed)
        }

        guard let base = URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let url = URL(string: base.appendingPathComponent("api/generate").absoluteString) else {
            return Self.heuristic(trimmed)
        }

        let systemPrompt = """
        Classify this query as exactly one word: "search", "ai", or "ambiguous". No explanation. No punctuation.

        search — navigational or lookup intent ("youtube", "weather Tokyo", "nba scores today", "best pizza near me", "iphone 16 price")
        ai — conversational, reasoning, writing, or synthesis intent ("explain how transformers work", "write me a cover letter", "help me debug my code", "what's the difference between stoicism and existentialism")
        ambiguous — genuinely unclear; could be a quick lookup or a deep conversation ("python lists", "black holes", "stoicism", "react hooks", "anxiety")
        """

        let body: [String: Any] = [
            "model": modelTrimmed,
            "system": systemPrompt,
            "prompt": trimmed,
            "stream": false
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            return Self.heuristic(trimmed)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 2
        request.httpBody = jsonData

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let response = json["response"] as? String {
                let word = response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if word.hasPrefix("search") { return .search }
                if word.hasPrefix("ai") { return .ai }
                if word.hasPrefix("ambiguous") { return .ambiguous }
            }
            return Self.heuristic(trimmed)
        } catch {
            return Self.heuristic(trimmed)
        }
    }

    // MARK: - Deep heuristic classification

    static func heuristic(_ query: String) -> QueryIntent {
        let lower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let words = lower.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return .search }

        // --- Strong SEARCH signals ---

        // Looks like a URL or domain
        if lower.contains(".com") || lower.contains(".org") || lower.contains(".net")
            || lower.contains(".io") || lower.contains(".dev") || lower.contains(".app")
            || lower.hasPrefix("http://") || lower.hasPrefix("https://")
            || lower.hasPrefix("www.") {
            return .search
        }

        // Exact navigation site name (single word or known compound)
        if words.count <= 2 && navigationSites.contains(lower) {
            return .search
        }
        if words.count == 1 && navigationSites.contains(words[0]) {
            return .search
        }

        // Known search patterns (factual lookups, local queries, navigation)
        for pattern in searchPatterns {
            if lower.contains(pattern) { return .search }
        }

        // --- Strong AI signals ---

        // Contains a question mark
        if lower.contains("?") { return .ai }

        // Starts with an AI verb ("explain X", "write a Y", "help me Z")
        if let first = words.first, aiLeadingVerbs.contains(first) {
            return .ai
        }

        // Contains known AI-intent phrases
        for phrase in aiPhrases {
            if lower.contains(phrase) { return .ai }
        }

        // Multi-sentence or very long input (>8 words) suggests conversational intent
        if words.count > 8 { return .ai }

        // Starts with a question word + has at least 3 words ("what is stoicism")
        if let first = words.first, aiQuestionStarters.contains(first) && words.count >= 3 {
            return .ai
        }

        // Contains personal pronouns with verbs suggesting a request
        let personalPatterns = ["i want", "i need", "i have", "my ", "me "]
        for p in personalPatterns {
            if lower.contains(p) && words.count >= 4 { return .ai }
        }

        // --- AMBIGUOUS signals ---

        // 1-2 word general topic that could go either way
        if words.count <= 2 {
            for topic in ambiguousTopics {
                if lower == topic || lower.hasPrefix(topic + " ") || lower.hasSuffix(" " + topic) {
                    return .ambiguous
                }
            }
        }

        // 3-6 word queries without strong signals are ambiguous territory
        if words.count >= 3 && words.count <= 6 {
            // Check if it starts with a question word (short question → ambiguous)
            if let first = words.first, aiQuestionStarters.contains(first) {
                return .ambiguous
            }
        }

        // Short query (1-3 words) with no strong signals → likely a search
        if words.count <= 3 { return .search }

        // Medium-length (4-6 words) with no strong signals → ambiguous
        if words.count <= 6 { return .ambiguous }

        // Default long queries to AI
        return .ai
    }
}
