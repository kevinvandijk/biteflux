import Foundation

/// The daily calorie goal the Today screen counts down from.
public enum DailyGoal {
    /// Where the goal starts until you set your own.
    public static let standardKcal = 2300.0
    /// Goals Biteflux accepts. Anything outside this is more likely a typo than a plan.
    public static let range = 800.0...6000.0
    /// Quick picks on the goal screen.
    public static let suggestions: [Double] = [1800, 2000, 2300, 2500]

    /// The goal in `text`, as a whole number of kcal, or nil when it isn't a number in `range`.
    public static func kcal(from text: String) -> Double? {
        let digits = text.replacingOccurrences(of: "kcal", with: "").trimmingCharacters(in: .whitespaces)
        guard let value = DecimalInput.value(digits)?.rounded(), range.contains(value) else { return nil }
        return value
    }
}
