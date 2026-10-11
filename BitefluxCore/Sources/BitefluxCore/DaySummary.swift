import Foundation

/// Totals for one day against the daily calorie goal.
public struct DaySummary: Equatable, Sendable {
    public var goalKcal: Double
    public var eaten: Nutrients

    public init(goalKcal: Double, eaten: [Nutrients]) {
        self.goalKcal = goalKcal
        self.eaten = eaten.reduce(.zero, +)
    }

    /// Calories left today; negative once the goal is passed.
    public var remainingKcal: Double {
        goalKcal - eaten.energyKcal
    }

    /// How much of the goal is eaten, from 0 to 1.
    public var progress: Double {
        guard goalKcal > 0 else { return 0 }
        return min(max(eaten.energyKcal / goalKcal, 0), 1)
    }
}
