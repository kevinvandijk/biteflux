import XCTest
@testable import BitefluxCore

final class NEVOTests: XCTestCase {
    /// A few rows in the layout of the NEVO-online 2025/9.0 CSV, with only the columns Biteflux reads.
    private let csv = [
        #""NEVO-versie/NEVO-version"|"Voedingsmiddelgroep"|"Food group"|"NEVO-code"|"Voedingsmiddelnaam/Dutch food name"|"Engelse naam/Food name"|"Synoniem"|"Hoeveelheid/Quantity"|"Opmerking"|"ENERCJ (kJ)"|"ENERCC (kcal)"|"WATER (g)"|"PROT (g)"|"CHO (g)"|"SUGAR (g)"|"FAT (g)"|"FASAT (g)"|"FIBT (g)"|"NA (mg)""#,
        #"2025/9.0|Fruit|Fruit|"875"|Appel m schil gem|Apple w skin av||per 100g||"238"|"56"|"85,8"|"0,3"|"12"|"10,4"|"0,2"|"0"|"2"|"1""#,
        #"2025/9.0|Brood|Bread|"246"|Tarwebrood volkoren gem v fijn en grof|Wheat bread wholemeal av fine and coarse||per 100g||"991"|"235"|"38"|"11,1"|"39"|"1,9"|"2,3"|"0,5"|"6,7"|"383""#,
        #"2025/9.0|Suiker, snoep, zoet beleg en zoete sauzen|Sugar, sweets, sweet spreads and sweet sauces|"336"|Appelstroop|Apple syrup|Rinse appelstroop|per 100g||"1180"|"278"|"30"|"0,8"|"66,3"|"52"|"0,1"|"0"||"40""#,
        #"2025/9.0|Voedingsmiddelen voor bijzondere voeding|Foods for special nutritional use|"2000"|Zuigelingenvoeding|Infant formula||per 100ml||"280"|"67"|"88"|"1,3"|"7,5"|"7,5"|"3,5"|"1,2"||"20""#,
    ].joined(separator: "\r\n") + "\r\n"

    func testReadsFoodsPer100Gram() throws {
        let foods = try NEVO.foods(fromCSV: csv)

        XCTAssertEqual(foods.map(\.code), ["875", "246", "336"])  // the per 100 ml formula is left out
        XCTAssertEqual(foods[0], NEVO.Food(
            code: "875",
            dutchName: "Appel m schil gem",
            englishName: "Apple w skin av",
            synonym: nil,
            group: "Fruit",
            englishGroup: "Fruit",
            per100g: Nutrients(
                energyKcal: 56, proteinG: 0.3, carbohydratesG: 12, sugarG: 10.4, fiberG: 2,
                fatG: 0.2, saturatedFatG: 0, sodiumMg: 1
            )
        ))
        XCTAssertEqual(foods[2].synonym, "Rinse appelstroop")
        XCTAssertEqual(foods[1].group, "Brood")
        XCTAssertNil(foods[2].per100g.fiberG)
    }

    func testMissingColumnIsReported() {
        XCTAssertThrowsError(try NEVO.foods(fromCSV: #""NEVO-code"|"Voedingsmiddelnaam/Dutch food name""#)) { error in
            XCTAssertEqual(error as? NEVO.Problem, .missingColumn("Engelse naam/Food name"))
        }
    }

    func testSearchPutsNamesStartingWithTheQueryFirst() throws {
        let foods = try NEVO.foods(fromCSV: csv)

        XCTAssertEqual(NEVO.search("appel", in: foods).map(\.code), ["875", "336"])
        XCTAssertEqual(NEVO.search("wholemeal bread", in: foods).map(\.code), ["246"])
        XCTAssertEqual(NEVO.search("rinse", in: foods).map(\.code), ["336"])
        XCTAssertEqual(NEVO.search(" ", in: foods), [])
    }

    /// Orange juice ("sinaasappel", with the brand Appelsientje as its synonym) and potatoes
    /// ("aardappel") only hold "appel" inside a word or in the synonym, so apple foods come first.
    func testSearchPutsWordsBeforePartsOfWords() {
        let foods = [
            food("1", "Sap sinaasappel-", synonym: "Sinaasappelsap Appelsientje", group: "Niet-alcoholische dranken"),
            food("2", "Aardappelen gekookt", group: "Aardappelen en knolgewassen"),
            food("3", "Appelmoes", group: "Fruit"),
            food("4", "Taart appel-", group: "Gebak en koek"),
            food("5", "Appel z schil gem", group: "Fruit"),
        ]

        XCTAssertEqual(NEVO.search("appel", in: foods).map(\.code), ["5", "3", "4", "1", "2"])
        XCTAssertEqual(NEVO.search("appel", in: foods, limit: 3).map(\.code), ["5", "3", "4"])
    }

    /// Dutch breads are compound words ending in "brood", so the group "Brood" lifts them
    /// above rolls and other foods that only begin with it.
    func testSearchCountsTheFoodGroup() {
        let foods = [
            food("1", "Broodje kaas", group: "Samengestelde gerechten"),
            food("2", "Broodje krenten", group: "Brood"),
            food("3", "Brooddeeg", group: "Graanproducten en bindmiddelen"),
            food("4", "Tarwebrood bruin", group: "Brood"),
            food("5", "Aardappelen gekookt", group: "Aardappelen en knolgewassen"),
        ]

        XCTAssertEqual(NEVO.search("brood", in: foods).map(\.code), ["4", "1", "2", "3"])
        XCTAssertEqual(NEVO.search("appel", in: foods).map(\.code), ["5"])
    }

    private func food(_ code: String, _ name: String, synonym: String? = nil, group: String) -> NEVO.Food {
        NEVO.Food(
            code: code, dutchName: name, englishName: nil, synonym: synonym, group: group,
            per100g: Nutrients(energyKcal: 0, proteinG: 0, carbohydratesG: 0, fatG: 0)
        )
    }

    /// Runs against the real export when NEVO_CSV points to it, for example:
    /// NEVO_CSV=~/claude/nevo/NEVO2025_v9.0/NEVO2025_v9.0.csv swift test
    func testRealTable() throws {
        guard let path = ProcessInfo.processInfo.environment["NEVO_CSV"] else {
            throw XCTSkip("Set NEVO_CSV to the NEVO-online CSV to check the real table.")
        }
        let foods = try NEVO.foods(fromCSV: String(contentsOfFile: path, encoding: .utf8))

        XCTAssertEqual(foods.count, 2_275)  // 2,328 foods minus 53 given per 100 ml
        let apple = try XCTUnwrap(foods.first { $0.code == "875" })
        XCTAssertEqual(apple.dutchName, "Appel m schil gem")
        XCTAssertEqual(apple.per100g.energyKcal, 56)
        XCTAssertEqual(apple.per100g.sodiumMg, 1)
        let bread = try XCTUnwrap(foods.first { $0.code == "246" })
        XCTAssertEqual(bread.per100g.proteinG, 11.1, accuracy: 0.0001)
        XCTAssertEqual(bread.per100g.sodiumMg, 383)
    }
}
