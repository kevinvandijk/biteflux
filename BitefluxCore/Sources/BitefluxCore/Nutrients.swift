import Foundation

/// Nutrient amounts for one quantity of food.
///
/// Energy is in kcal, masses in grams and sodium in milligrams, matching the units
/// Apple Health shows. Values a label doesn't list are `nil` rather than zero.
public struct Nutrients: Equatable, Hashable, Codable, Sendable {
    public var energyKcal: Double
    public var proteinG: Double
    public var carbohydratesG: Double
    public var sugarG: Double?
    public var fiberG: Double?
    public var fatG: Double
    public var saturatedFatG: Double?
    public var sodiumMg: Double?

    public init(
        energyKcal: Double,
        proteinG: Double,
        carbohydratesG: Double,
        sugarG: Double? = nil,
        fiberG: Double? = nil,
        fatG: Double,
        saturatedFatG: Double? = nil,
        sodiumMg: Double? = nil
    ) {
        self.energyKcal = energyKcal
        self.proteinG = proteinG
        self.carbohydratesG = carbohydratesG
        self.sugarG = sugarG
        self.fiberG = fiberG
        self.fatG = fatG
        self.saturatedFatG = saturatedFatG
        self.sodiumMg = sodiumMg
    }

    public static let zero = Nutrients(energyKcal: 0, proteinG: 0, carbohydratesG: 0, fatG: 0)

    /// Every value multiplied by `factor`.
    public func scaled(by factor: Double) -> Nutrients {
        Nutrients(
            energyKcal: energyKcal * factor,
            proteinG: proteinG * factor,
            carbohydratesG: carbohydratesG * factor,
            sugarG: sugarG.map { $0 * factor },
            fiberG: fiberG.map { $0 * factor },
            fatG: fatG * factor,
            saturatedFatG: saturatedFatG.map { $0 * factor },
            sodiumMg: sodiumMg.map { $0 * factor }
        )
    }

    /// Treats these values as per 100 g and returns them for a portion of `grams`.
    public func per100g(forPortionOf grams: Double) -> Nutrients {
        scaled(by: grams / 100)
    }

    /// Treats these values as a portion of `grams` and returns them for `newGrams` of the same food.
    /// Nil when the portion has no weight to work from.
    public func rescaled(fromPortionOf grams: Double, to newGrams: Double) -> Nutrients? {
        guard grams > 0, newGrams >= 0 else { return nil }
        return scaled(by: newGrams / grams)
    }

    /// Adds two sets of nutrients. An optional value stays `nil` only when both sides lack it.
    public static func + (lhs: Nutrients, rhs: Nutrients) -> Nutrients {
        Nutrients(
            energyKcal: lhs.energyKcal + rhs.energyKcal,
            proteinG: lhs.proteinG + rhs.proteinG,
            carbohydratesG: lhs.carbohydratesG + rhs.carbohydratesG,
            sugarG: sum(lhs.sugarG, rhs.sugarG),
            fiberG: sum(lhs.fiberG, rhs.fiberG),
            fatG: lhs.fatG + rhs.fatG,
            saturatedFatG: sum(lhs.saturatedFatG, rhs.saturatedFatG),
            sodiumMg: sum(lhs.sodiumMg, rhs.sodiumMg)
        )
    }

    private static func sum(_ a: Double?, _ b: Double?) -> Double? {
        switch (a, b) {
        case (nil, nil): return nil
        default: return (a ?? 0) + (b ?? 0)
        }
    }
}

/// Unit conversions needed to turn EU nutrition labels into Apple Health values.
public enum NutritionConversion {
    public static let kilojoulesPerKilocalorie = 4.184

    /// Labels that only list kJ still need kcal.
    public static func kilocalories(fromKilojoules kilojoules: Double) -> Double {
        kilojoules / kilojoulesPerKilocalorie
    }

    /// EU labels list salt, while Apple Health stores sodium.
    /// Salt is 2.5 times the sodium weight, so 1 g of salt is 400 mg of sodium.
    public static func sodiumMilligrams(fromSaltGrams saltGrams: Double) -> Double {
        saltGrams / 2.5 * 1000
    }
}
