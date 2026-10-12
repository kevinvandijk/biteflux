import Foundation

/// The gram dial on the Match screen: turning it clockwise adds grams, one full turn at a time.
/// Angles are in degrees, clockwise from the top.
public struct GramDial: Equatable, Sendable {
    /// How many grams one full turn adds.
    public var gramsPerTurn: Double
    /// The amount snaps to multiples of this.
    public var step: Double

    /// A dial that suits a product's serving: a finer step for small servings like a sweet,
    /// and a bigger turn for big ones like a meal.
    public init(servingGrams: Double?) {
        let serving = servingGrams ?? 100
        step = serving < 20 ? 1 : 5
        gramsPerTurn = max(500, (serving * 2 / 100).rounded(.up) * 100)
    }

    /// How far the ring is filled for `grams`, from 0 to 1; full from one turn on.
    public func fill(for grams: Double) -> Double {
        min(max(grams / gramsPerTurn, 0), 1)
    }

    /// Where the dial's handle sits for `grams`.
    public func angle(for grams: Double) -> Double {
        (max(grams, 0) / gramsPerTurn * 360).truncatingRemainder(dividingBy: 360)
    }

    /// The grams a drag adds going from one angle to the next. The shorter way round counts,
    /// so passing the top keeps adding instead of jumping back a turn.
    public func grams(turningFrom start: Double, to end: Double) -> Double {
        var degrees = (end - start).truncatingRemainder(dividingBy: 360)
        if degrees > 180 { degrees -= 360 }
        if degrees < -180 { degrees += 360 }
        return degrees / 360 * gramsPerTurn
    }

    /// `grams` on the dial's step, never less than one step.
    public func snapped(_ grams: Double) -> Double {
        max(step, (grams / step).rounded() * step)
    }

    /// The angle of `point` around `center`, as the dial counts it. Screen coordinates: y grows down.
    public static func angle(of point: (x: Double, y: Double), around center: (x: Double, y: Double)) -> Double {
        let degrees = atan2(point.x - center.x, center.y - point.y) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }
}
