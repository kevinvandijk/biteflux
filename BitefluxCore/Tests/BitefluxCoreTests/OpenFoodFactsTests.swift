import XCTest
@testable import BitefluxCore

final class OpenFoodFactsTests: XCTestCase {
    private func lookup(_ json: String, barcode: String = "8718452000012") throws -> OpenFoodFacts.Lookup {
        try OpenFoodFacts.lookup(barcode: barcode, from: Data(json.utf8))
    }

    func testFullProduct() throws {
        let result = try lookup("""
        {"code": "8718452000012", "status": 1, "status_verbose": "product found", "product": {
            "product_name": "Haverkoek pure chocolade", "brands": "Bakkerij Vos, Vos",
            "serving_size": "1 koek (25 g)", "serving_quantity": 25,
            "nutriments": {
                "energy-kcal_100g": 402, "energy-kj_100g": 1680, "proteins_100g": 8.1,
                "carbohydrates_100g": 49, "sugars_100g": 21, "fiber_100g": 4.2, "fat_100g": 18,
                "saturated-fat_100g": 7.5, "salt_100g": 0.45, "sodium_100g": 0.18
            }
        }}
        """)

        XCTAssertEqual(result, .found(OpenFoodFacts.Product(
            barcode: "8718452000012",
            name: "Haverkoek pure chocolade",
            brand: "Bakkerij Vos",
            per100g: Nutrients(
                energyKcal: 402, proteinG: 8.1, carbohydratesG: 49, sugarG: 21, fiberG: 4.2,
                fatG: 18, saturatedFatG: 7.5, sodiumMg: 180
            ),
            servingGrams: 25,
            servingDescription: "1 koek (25 g)"
        )))
    }

    func testNumbersAsStringsKilojoulesOnlyAndSodiumOnly() throws {
        guard case let .found(product) = try lookup("""
        {"status": 1, "product": {
            "product_name": " ", "product_name_nl": "Volle yoghurt", "brands": "",
            "serving_quantity": "150",
            "nutriments": {
                "energy_100g": "260", "proteins_100g": "3,5", "carbohydrates_100g": "4.5",
                "fat_100g": "3.0", "sodium_100g": "0.05"
            }
        }}
        """) else { return XCTFail("Expected a product") }

        XCTAssertEqual(product.name, "Volle yoghurt")
        XCTAssertNil(product.brand)
        XCTAssertEqual(product.servingGrams, 150)
        XCTAssertNil(product.servingDescription)
        let per100g = try XCTUnwrap(product.per100g)
        XCTAssertEqual(per100g.energyKcal, 62.14, accuracy: 0.01)
        XCTAssertEqual(per100g.proteinG, 3.5, accuracy: 0.001)
        XCTAssertEqual(per100g.sodiumMg ?? -1, 50, accuracy: 0.001)
        XCTAssertNil(per100g.sugarG)
    }

    func testServingInMillilitresIsLeftOut() throws {
        func serving(_ fields: String) throws -> OpenFoodFacts.Product {
            let result = try lookup(#"{"status": 1, "product": {"product_name": "Cola", "# + fields + "}}")
            guard case let .found(product) = result else {
                XCTFail("Expected a product")
                throw OpenFoodFacts.Problem.unreadableAnswer
            }
            return product
        }

        let millilitres = try serving(#""serving_size": "330 ml", "serving_quantity": 330, "serving_quantity_unit": "ml""#)
        XCTAssertNil(millilitres.servingGrams)
        XCTAssertNil(millilitres.servingName)
        XCTAssertEqual(millilitres.servingDescription, "330 ml")

        // Older products have no unit; the serving text tells.
        XCTAssertNil(try serving(#""serving_size": "1 glas (25cl)", "serving_quantity": 250"#).servingGrams)
        XCTAssertNil(try serving(#""serving_size": "1 liter", "serving_quantity": 1000"#).servingGrams)
        XCTAssertEqual(try serving(#""serving_size": "1 koek (25 g)", "serving_quantity": 25"#).servingGrams, 25)
        XCTAssertEqual(try serving(#""serving_quantity": 30, "serving_quantity_unit": "g""#).servingGrams, 30)
        XCTAssertEqual(try serving(#""serving_quantity": 30"#).servingGrams, 30)
    }

    func testServingName() {
        func product(_ description: String?, grams: Double? = 25) -> OpenFoodFacts.Product {
            OpenFoodFacts.Product(barcode: "1", name: nil, brand: nil, per100g: nil, servingGrams: grams, servingDescription: description)
        }
        XCTAssertEqual(product("1 koek (25 g)").servingName, "1 koek")
        XCTAssertNil(product("25 g").servingName)
        XCTAssertNil(product("(25 g)").servingName)
        XCTAssertNil(product("1 koek (25 g)", grams: nil).servingName)
    }

    func testMissingMacrosLeavesNutrientsEmpty() throws {
        guard case let .found(product) = try lookup("""
        {"status": 1, "product": {"product_name": "Pindakaas",
            "nutriments": {"energy-kcal_100g": 620, "proteins_100g": 25, "carbohydrates_100g": 12}}}
        """) else { return XCTFail("Expected a product") }

        XCTAssertEqual(product.name, "Pindakaas")
        XCTAssertNil(product.per100g)
    }

    func testNotFound() throws {
        XCTAssertEqual(
            try lookup(#"{"code": "8712345000066", "status": 0, "status_verbose": "product not found"}"#),
            .notFound
        )
    }

    func testUnreadableAnswer() {
        XCTAssertThrowsError(try lookup("<html>Service unavailable</html>")) { error in
            XCTAssertEqual(error as? OpenFoodFacts.Problem, .unreadableAnswer)
        }
    }

    func testURLAsksOnlyForNeededFields() {
        let url = OpenFoodFacts.productURL(barcode: "3017624010701")
        XCTAssertEqual(url.host, "world.openfoodfacts.org")
        XCTAssertEqual(url.path, "/api/v2/product/3017624010701")
        XCTAssertTrue(url.query?.contains("fields=code,product_name") == true)
    }

    func testSearchKeepsProductsWithABarcodeAndNameOnce() throws {
        let products = try OpenFoodFacts.products(fromSearch: Data("""
        {"count": 5, "page": 1, "products": [
            {"code": "8710400015727", "product_name": "Pure hagelslag", "brands": "AH",
             "serving_quantity": 20, "serving_quantity_unit": "g",
             "nutriments": {"energy-kcal_100g": 435, "proteins_100g": 5.5, "carbohydrates_100g": 70,
                            "fat_100g": 15, "salt_100g": 0.3}},
            {"code": "3017624010701", "product_name": "Nutella", "nutriments": {}},
            {"code": "3017624010701", "product_name": "Nutella 400 g"},
            {"code": "12345", "product_name": "Not a real barcode"},
            {"code": "5449000000996", "product_name": ""}
        ]}
        """.utf8))

        XCTAssertEqual(products.map(\.barcode), ["8710400015727", "3017624010701"])
        XCTAssertEqual(products[0].per100g?.energyKcal, 435)
        XCTAssertEqual(products[0].servingGrams, 20)
        XCTAssertEqual(products[1].name, "Nutella")
        XCTAssertNil(products[1].per100g)
    }

    func testSearchURLAsksForTheSameFields() throws {
        let url = OpenFoodFacts.searchURL(for: "pure hagelslag")
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)

        XCTAssertEqual(url.host, "world.openfoodfacts.org")
        XCTAssertEqual(items.first { $0.name == "search_terms" }?.value, "pure hagelslag")
        XCTAssertEqual(items.first { $0.name == "fields" }?.value, OpenFoodFacts.fields.joined(separator: ","))
    }
}
