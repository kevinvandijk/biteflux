import Foundation

/// Where a logged entry stands with Apple Health.
public enum SyncState: String, Codable, Sendable {
    /// Kept in Biteflux, not written to Apple Health yet.
    case waiting
    /// Written to Apple Health and read back from it.
    case inHealth
    /// Could not be written or confirmed; the entry carries the reason.
    case failed
}
