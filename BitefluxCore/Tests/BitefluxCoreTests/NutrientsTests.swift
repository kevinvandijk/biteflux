import XCTest
@testable import BitefluxCore

final class NutrientsTests: XCTestCase {
    func testPer100gScalesToPortion() {
        // Haverkoek label: 402 kcal, 8.1 g protein, 49 g carbs, 18 g fat per 100 g; one koek is 25 g.
        let per100g = Nutrients(energyKcal: 402, proteinG: 8.1, carbohydratesG: 49, sugarG: 21, fatG: 18, sodiumMg: 180)
        let koek = per100g.per100g(forPortionOf: 25)

        XCTAssertEqual(koek.energyKcal, 100.5, accuracy: 0.001)
        XCTAssertEqual(koek.proteinG, 2.025, accuracy: 0.001)
        XCTAssertEqual(koek.carbohydratesG, 12.25, accuracy: 0.001)
        XCTAssertEqual(koek.sugarG ?? -1, 5.25, accuracy: 0.001)
        XCTAssertEqual(koek.fatG, 4.5, accuracy: 0.001)
        XCTAssertEqual(koek.sodiumMg ?? -1, 45, accuracy: 0.001)
        XCTAssertNil(koek.fiberG)
        XCTAssertNil(koek.saturatedFatG)
    }

    func testAddingKeepsMissingValuesMissing() {
        let a = Nutrients(energyKcal: 95, proteinG: 16.5, carbohydratesG: 6, fatG: 0.3)
        let b = Nutrients(energyKcal: 105, proteinG: 1.3, carbohydratesG: 27, fiberG: 3.1, fatG: 0.4)
        let total = a + b

        XCTAssertEqual(total.energyKcal, 200, accuracy: 0.001)
        XCTAssertEqual(total.proteinG, 17.8, accuracy: 0.001)
        XCTAssertEqual(total.fiberG ?? -1, 3.1, accuracy: 0.001)
        XCTAssertNil(total.sugarG)
        XCTAssertNil(total.sodiumMg)
    }

    func testKilojoulesToKilocalories() {
        XCTAssertEqual(NutritionConversion.kilocalories(fromKilojoules: 1680), 401.53, accuracy: 0.01)
    }

    func testSaltToSodium() {
        // The B4 Create screen shows 0.45 g salt as 180 mg sodium.
        XCTAssertEqual(NutritionConversion.sodiumMilligrams(fromSaltGrams: 0.45), 180, accuracy: 0.001)
        XCTAssertEqual(NutritionConversion.sodiumMilligrams(fromSaltGrams: 1), 400, accuracy: 0.001)
    }
}
