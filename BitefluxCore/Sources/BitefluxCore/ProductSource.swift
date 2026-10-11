import Foundation

/// Where a product in the library came from.
public enum ProductSource: String, Codable, Sendable {
    /// Added by hand from its label.
    case own
    /// Looked up by barcode on Open Food Facts, a shared database anyone can edit.
    case openFoodFacts
    /// From NEVO, the Dutch food composition table by RIVM.
    case nevo
}
