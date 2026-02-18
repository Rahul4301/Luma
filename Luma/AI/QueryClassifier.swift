// Luma — Query intent classifier for SmartSearch
import Foundation

enum QueryIntent {
    case search
    case ai
    case ambiguous
}

struct QueryClassifier {

    private static let aiVerbs: Set<String> = [
        "write", "explain", "summarize", "compare", "help",
        "what", "why", "how", "tell", "create", "make",
        "list", "describe", "analyze", "translate", "define",
        "suggest", "recommend", "generate", "rewrite", "simplify"
    ]

    /// Classify a query using Ollama when available, falling back to a heuristic.
    /// Designed to return in < 300ms — uses a raw single-shot /api/generate call
    /// instead of the full OllamaClient.generate() conversation builder.
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

        search — navigational or lookup intent ("youtube", "weather Tokyo", "nba scores today")
        ai — conversational, reasoning, writing, or synthesis intent ("explain black holes", "write me a cover letter")
        ambiguous — genuinely unclear either way
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

    /// Fast offline heuristic — no network required.
    static func heuristic(_ query: String) -> QueryIntent {
        let lower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if lower.contains("?") { return .ai }

        let words = lower.split(separator: " ")
        if words.count > 6 { return .ai }

        if let first = words.first, aiVerbs.contains(String(first)) {
            return .ai
        }

        return .search
    }
}
