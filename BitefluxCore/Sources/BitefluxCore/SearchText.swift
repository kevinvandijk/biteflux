import Foundation

/// Matching typed search words against product names.
public enum SearchText {
    /// Whether every word of `query` appears in at least one of `fields`, ignoring case and
    /// accents, so "creme" finds "Crème fraîche". An empty query matches everything.
    public static func matches(_ query: String, in fields: [String?]) -> Bool {
        let words = fold(query).split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return true }
        let haystack = fields.compactMap { $0 }.map(fold)
        return words.allSatisfy { word in haystack.contains { $0.contains(word) } }
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
