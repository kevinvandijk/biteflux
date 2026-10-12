import BitefluxCore
import Foundation
import SwiftData

/// A food in your library, with its nutrients per 100 g, ready to log in any amount.
///
/// Like `FoodEntry`, every stored property has a default and nothing is marked unique,
/// so the library can later sync through your private iCloud.
@Model
final class Product {
    var productID: UUID = UUID()
    var name: String = ""
    var brand: String?
    var barcode: String?
    var sourceRawValue: String = ProductSource.own.rawValue
    /// The food's code in its source table, like NEVO code "875".
    var sourceCode: String?

    // Per 100 g, as on the label.
    var energyKcal: Double = 0
    var proteinG: Double = 0
    var carbohydratesG: Double = 0
    var sugarG: Double?
    var fiberG: Double?
    var fatG: Double = 0
    var saturatedFatG: Double?
    var sodiumMg: Double?

    /// The weight of one serving, when the pack names one.
    var servingGrams: Double?
    /// How one serving reads, like "1 koek".
    var servingName: String?

    var addedAt: Date = Date()
    var lastLoggedAt: Date?
    /// What you ate last time, so the Match screen starts there.
    var lastLoggedGrams: Double?
    var timesLogged: Int = 0

    init(
        name: String,
        brand: String? = nil,
        barcode: String? = nil,
        source: ProductSource,
        sourceCode: String? = nil,
        per100g: Nutrients,
        servingGrams: Double? = nil,
        servingName: String? = nil
    ) {
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.sourceRawValue = source.rawValue
        self.sourceCode = sourceCode
        self.energyKcal = per100g.energyKcal
        self.proteinG = per100g.proteinG
        self.carbohydratesG = per100g.carbohydratesG
        self.sugarG = per100g.sugarG
        self.fiberG = per100g.fiberG
        self.fatG = per100g.fatG
        self.saturatedFatG = per100g.saturatedFatG
        self.sodiumMg = per100g.sodiumMg
        self.servingGrams = servingGrams
        self.servingName = servingName
    }

    var source: ProductSource {
        ProductSource(rawValue: sourceRawValue) ?? .own
    }

    var per100g: Nutrients {
        get {
            Nutrients(
                energyKcal: energyKcal,
                proteinG: proteinG,
                carbohydratesG: carbohydratesG,
                sugarG: sugarG,
                fiberG: fiberG,
                fatG: fatG,
                saturatedFatG: saturatedFatG,
                sodiumMg: sodiumMg
            )
        }
        set {
            energyKcal = newValue.energyKcal
            proteinG = newValue.proteinG
            carbohydratesG = newValue.carbohydratesG
            sugarG = newValue.sugarG
            fiberG = newValue.fiberG
            fatG = newValue.fatG
            saturatedFatG = newValue.saturatedFatG
            sodiumMg = newValue.sodiumMg
        }
    }

    /// Whether `other` is the same food: the same barcode, or the same code in the same table.
    func isSameFood(as other: Product) -> Bool {
        if let barcode, barcode == other.barcode { return true }
        if let sourceCode, source == other.source, sourceCode == other.sourceCode { return true }
        return false
    }

    /// Takes over what `other` says about the product, keeping this one's identity and history,
    /// so the same food never lives in the library twice.
    func takeValues(from other: Product) {
        name = other.name
        brand = other.brand
        sourceRawValue = other.sourceRawValue
        sourceCode = other.sourceCode
        per100g = other.per100g
        servingGrams = other.servingGrams
        servingName = other.servingName
    }

    /// How a portion of `grams` reads on the Today screen, like "1 koek (25 g)" or "150 g".
    func portion(grams: Double) -> String {
        if let servingName, let servingGrams, abs(grams - servingGrams) < 0.05 {
            return "\(servingName) (\(grams.amount) g)"
        }
        return "\(grams.amount) g"
    }

    /// A food entry for eating `grams` of this product, not yet logged.
    func entry(grams: Double, meal: Meal, eatenAt: Date) -> FoodEntry {
        FoodEntry(
            name: name,
            brand: brand,
            portion: portion(grams: grams),
            grams: grams,
            meal: meal,
            eatenAt: eatenAt,
            nutrients: per100g.per100g(forPortionOf: grams),
            productID: productID,
            productSource: source
        )
    }
}

extension Product {
    /// A product from an Open Food Facts answer that has full nutrients, not yet in the library.
    convenience init?(_ found: OpenFoodFacts.Product) {
        guard let per100g = found.per100g else { return nil }
        self.init(
            name: found.name ?? "Barcode \(found.barcode)",
            brand: found.brand,
            barcode: found.barcode,
            source: .openFoodFacts,
            per100g: per100g,
            servingGrams: found.servingGrams,
            servingName: found.servingName ?? (found.servingGrams == nil ? nil : "1 serving")
        )
    }

    /// A food from the NEVO table, not yet in the library. Its values stay exactly as NEVO gives them,
    /// as RIVM's conditions require.
    convenience init(_ food: NEVO.Food) {
        self.init(name: food.dutchName, source: .nevo, sourceCode: food.code, per100g: food.per100g)
    }
}
