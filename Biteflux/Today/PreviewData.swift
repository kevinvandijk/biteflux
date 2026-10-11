import BitefluxCore
import Foundation
import SwiftData

/// An in-memory library and food log for SwiftUI previews, with one entry in each sync state.
@MainActor
enum PreviewData {
    /// The foods from the B4 design, with typical values per 100 g. Not taken from real labels.
    static func products() -> [Product] {
        [
            Product(
                name: "Skyr Naturel", brand: "Arla", source: .openFoodFacts,
                per100g: Nutrients(energyKcal: 63, proteinG: 11, carbohydratesG: 4, sugarG: 4, fatG: 0.2, saturatedFatG: 0.1, sodiumMg: 40),
                servingGrams: 150, servingName: "1 bakje"
            ),
            Product(
                name: "Banaan", source: .own,
                per100g: Nutrients(energyKcal: 89, proteinG: 1.1, carbohydratesG: 22.8, sugarG: 12.2, fiberG: 2.6, fatG: 0.3, saturatedFatG: 0.1, sodiumMg: 1),
                servingGrams: 118, servingName: "1 medium"
            ),
            Product(
                name: "Volkoren brood", source: .own,
                per100g: Nutrients(energyKcal: 243, proteinG: 9.5, carbohydratesG: 39, sugarG: 3, fiberG: 7, fatG: 3, saturatedFatG: 0.6, sodiumMg: 400),
                servingGrams: 35, servingName: "1 slice"
            ),
            Product(
                name: "Jonge kaas", source: .own,
                per100g: Nutrients(energyKcal: 360, proteinG: 24, carbohydratesG: 0, sugarG: 0, fatG: 29, saturatedFatG: 19, sodiumMg: 800)
            ),
            Product(
                name: "Haverkoek pure chocolade", brand: "Bakkerij Vos", source: .openFoodFacts,
                per100g: Nutrients(energyKcal: 402, proteinG: 8.1, carbohydratesG: 49, sugarG: 21, fiberG: 4.2, fatG: 18, saturatedFatG: 7.5, sodiumMg: 180),
                servingGrams: 25, servingName: "1 koek"
            ),
            Product(
                name: "Appel", source: .own,
                per100g: Nutrients(energyKcal: 52, proteinG: 0.3, carbohydratesG: 14, sugarG: 10, fiberG: 2.4, fatG: 0.2, saturatedFatG: 0, sodiumMg: 1),
                servingGrams: 182, servingName: "1 medium"
            ),
        ]
    }

    static func container() -> ModelContainer {
        FontRegistration.registerBundledFonts()
        let container = try! ModelContainer(
            for: FoodEntry.self, Product.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let meals: [Meal] = [.breakfast, .breakfast, .lunch, .lunch, .snacks, .snacks]
        let states: [SyncState] = [.inHealth, .inHealth, .inHealth, .inHealth, .waiting, .failed]
        for (index, product) in products().enumerated() {
            container.mainContext.insert(product)
            let entry = product.entry(grams: product.servingGrams ?? 30, meal: meals[index], eatenAt: .now)
            entry.syncState = states[index]
            if entry.syncState == .failed {
                entry.syncProblem = HealthStore.Problem.notAllowed.localizedDescription
            }
            container.mainContext.insert(entry)
        }
        return container
    }
}
