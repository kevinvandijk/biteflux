import BitefluxCore
import Foundation
import SwiftData

/// One food eaten, kept in Biteflux and mirrored to Apple Health.
///
/// Every stored property has a default and nothing is marked unique,
/// so the model can later sync through the user's private iCloud.
@Model
final class FoodEntry {
    var entryID: UUID = UUID()
    var name: String = ""
    var brand: String?
    /// How the portion reads on screen, like "150 g" or "1 koek (25 g)".
    var portion: String = ""
    var grams: Double = 0
    var mealRawValue: String = Meal.snacks.rawValue
    var eatenAt: Date = Date()

    var energyKcal: Double = 0
    var proteinG: Double = 0
    var carbohydratesG: Double = 0
    var sugarG: Double?
    var fiberG: Double?
    var fatG: Double = 0
    var saturatedFatG: Double?
    var sodiumMg: Double?

    var syncStateRawValue: String = SyncState.waiting.rawValue
    /// Why the last write to Apple Health failed, in words for the user.
    var syncProblem: String?
    /// The Apple Health food entry this was saved as, once a save succeeded.
    var healthFoodID: UUID?
    /// The library product this was logged from. The entry keeps its own copy of the
    /// nutrients, so changing or removing the product never changes what you ate.
    var productID: UUID?

    init(
        name: String,
        brand: String? = nil,
        portion: String,
        grams: Double,
        meal: Meal,
        eatenAt: Date,
        nutrients: Nutrients,
        productID: UUID? = nil
    ) {
        self.name = name
        self.brand = brand
        self.portion = portion
        self.grams = grams
        self.mealRawValue = meal.rawValue
        self.eatenAt = eatenAt
        self.energyKcal = nutrients.energyKcal
        self.proteinG = nutrients.proteinG
        self.carbohydratesG = nutrients.carbohydratesG
        self.sugarG = nutrients.sugarG
        self.fiberG = nutrients.fiberG
        self.fatG = nutrients.fatG
        self.saturatedFatG = nutrients.saturatedFatG
        self.sodiumMg = nutrients.sodiumMg
        self.productID = productID
    }

    var meal: Meal {
        get { Meal(rawValue: mealRawValue) ?? .snacks }
        set { mealRawValue = newValue.rawValue }
    }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRawValue) ?? .waiting }
        set { syncStateRawValue = newValue.rawValue }
    }

    var nutrients: Nutrients {
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
}
