import Foundation

/// Which device saves a logged food to Apple Health when Biteflux syncs between devices.
///
/// One device writes each entry, because Apple Health syncs between devices itself. Another device
/// only takes an entry over once that writer has left it alone for a while: no device can stop
/// another one at once, so taking over an entry its writer is still saving could count the food twice.
public enum HealthWriter {
    /// How long the writer must have left an entry alone before another device may take it over.
    public static let quietPeriod: TimeInterval = 24 * 60 * 60

    /// Whether the writer, which last tried to save the entry at `lastTried`, has left it alone long
    /// enough. An entry with no try on record counts as left alone; a try that seems to lie ahead,
    /// from a device whose clock runs fast, doesn't.
    public static func isQuiet(lastTried: Date?, now: Date) -> Bool {
        guard let lastTried else { return true }
        return now.timeIntervalSince(lastTried) >= quietPeriod
    }
}
