import XCTest
@testable import BitefluxCore

final class LabelReaderTests: XCTestCase {
    /// An API answer in the Messages format, with the label JSON as Claude's text.
    private func answer(_ label: String, stopReason: String = "end_turn") throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "id": "msg_01", "type": "message", "role": "assistant", "model": "claude-opus-5-5",
            "stop_reason": stopReason,
            "content": [
                ["type": "thinking", "thinking": "", "signature": "sig"],
                ["type": "text", "text": label],
            ],
        ])
    }

    /// A label as Claude copies it, with every field present as the schema requires.
    private func label(_ values: [String: Any]) throws -> String {
        var label: [String: Any] = [
            "is_nutrition_label": true, "product_name": NSNull(), "brand": NSNull(), "column": "per_100g",
            "portion_grams": NSNull(), "portion_name": NSNull(), "energy_kj": NSNull(), "energy_kcal": NSNull(),
            "fat_g": NSNull(), "saturated_fat_g": NSNull(), "carbohydrates_g": NSNull(), "sugars_g": NSNull(),
            "fiber_g": NSNull(), "protein_g": NSNull(), "salt_g": NSNull(), "sodium_mg": NSNull(), "unsure": [String](),
        ]
        label.merge(values) { $1 }
        return String(decoding: try JSONSerialization.data(withJSONObject: label), as: UTF8.self)
    }

    func testRequestAsksForTheLabelAsJSON() throws {
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: LabelReader.requestBody(jpeg: Data([1, 2, 3]))) as? [String: Any])

        XCTAssertEqual(body["model"] as? String, "claude-opus-5-5")
        XCTAssertEqual(body["fallbacks"] as? String, "default")
        let format = try XCTUnwrap((body["output_config"] as? [String: Any])?["format"] as? [String: Any])
        XCTAssertEqual(format["type"] as? String, "json_schema")
        let schema = try XCTUnwrap(format["schema"] as? [String: Any])
        XCTAssertEqual((schema["required"] as? [String])?.count, (schema["properties"] as? [String: Any])?.count)

        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        let image = try XCTUnwrap((messages.first?["content"] as? [[String: Any]])?.first)
        let source = try XCTUnwrap(image["source"] as? [String: Any])
        XCTAssertEqual(source["media_type"] as? String, "image/jpeg")
        XCTAssertEqual(source["data"] as? String, "AQID")
    }

    func testReadsADutchLabelPer100Gram() throws {
        let reading = try LabelReader.reading(fromAnswer: answer(label([
            "product_name": "Haverkoek pure chocolade", "brand": "Bakkerij Vos",
            "energy_kj": 1680, "energy_kcal": 402, "fat_g": 18, "saturated_fat_g": 7.5,
            "carbohydrates_g": 49, "sugars_g": 21, "fiber_g": 4.2, "protein_g": 8.1, "salt_g": 0.45,
            "portion_grams": 25, "portion_name": "1 koek", "unsure": ["fiber"],
        ])))

        XCTAssertEqual(reading, LabelReader.Reading(
            name: "Haverkoek pure chocolade", brand: "Bakkerij Vos",
            energyKcal: 402, proteinG: 8.1, carbohydratesG: 49, sugarG: 21, fiberG: 4.2,
            fatG: 18, saturatedFatG: 7.5, saltG: 0.45,
            servingGrams: 25, servingName: "1 koek",
            unsure: [.fiber]
        ))
    }

    func testKilojoulesOnlyAndSodiumOnly() throws {
        let reading = try LabelReader.reading(fromAnswer: answer(label([
            "column": "per_100ml", "energy_kj": 1680, "fat_g": 3, "carbohydrates_g": 4.5, "protein_g": 3.5,
            "sodium_mg": 180,
        ])))

        XCTAssertEqual(try XCTUnwrap(reading.energyKcal), 401.53, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(reading.saltG), 0.45, accuracy: 0.0001)
        XCTAssertNil(reading.fiberG)
        XCTAssertTrue(reading.perMillilitre)
        XCTAssertFalse(reading.fromPortion)
    }

    func testPortionOnlyLabelIsWorkedOutPer100Gram() throws {
        let reading = try LabelReader.reading(fromAnswer: answer(label([
            "column": "per_portion", "portion_grams": 25, "portion_name": "1 koek",
            "energy_kcal": 100.5, "fat_g": 4.5, "carbohydrates_g": 12.25, "protein_g": 2, "salt_g": 0.1,
        ])))

        XCTAssertEqual(reading.energyKcal, 402)
        XCTAssertEqual(reading.fatG, 18)
        XCTAssertEqual(reading.carbohydratesG, 49)
        XCTAssertEqual(reading.proteinG, 8)
        XCTAssertEqual(try XCTUnwrap(reading.saltG), 0.4, accuracy: 0.0001)
        XCTAssertEqual(reading.servingGrams, 25)
        XCTAssertTrue(reading.fromPortion)
    }

    func testPortionOnlyLabelWithoutWeightCantBeUsed() {
        XCTAssertThrowsError(try LabelReader.reading(fromAnswer: answer(label([
            "column": "per_portion", "energy_kcal": 100, "portion_name": "1 koek",
        ])))) { error in
            XCTAssertEqual(error as? LabelReader.Problem, .onlyPerPortion)
        }
    }

    func testProblems() throws {
        func problem(_ data: Data) -> LabelReader.Problem? {
            do {
                _ = try LabelReader.reading(fromAnswer: data)
                return nil
            } catch {
                return error as? LabelReader.Problem
            }
        }

        XCTAssertEqual(problem(try answer(label(["is_nutrition_label": false]))), .notALabel)
        XCTAssertEqual(problem(try answer("", stopReason: "refusal")), .declined)
        XCTAssertEqual(problem(try answer(#"{"is_nutrition_la"#, stopReason: "max_tokens")), .cutOff)
        XCTAssertEqual(problem(try answer("Here is the label")), .unreadableAnswer)
        XCTAssertEqual(problem(Data("<html>".utf8)), .unreadableAnswer)
    }
}
