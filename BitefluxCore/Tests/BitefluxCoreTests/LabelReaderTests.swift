import XCTest
@testable import BitefluxCore

final class LabelReaderTests: XCTestCase {
    /// An OpenRouter chat completion, with the label JSON as the message content.
    private func answer(_ label: String, finishReason: String = "stop", refusal: String? = nil) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "id": "gen-01", "object": "chat.completion", "model": "openai/gpt-6-luna", "provider": "OpenAI",
            "choices": [[
                "index": 0,
                "finish_reason": finishReason,
                "message": [
                    "role": "assistant",
                    "content": label,
                    "refusal": refusal.map { $0 as Any } ?? NSNull(),
                    "reasoning": NSNull(),
                ],
            ]],
        ])
    }

    /// A label as the model copies it, with every field present as the schema requires.
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

        XCTAssertEqual(LabelReader.endpoint.absoluteString, "https://openrouter.ai/api/v1/chat/completions")
        XCTAssertEqual(body["model"] as? String, "openai/gpt-6-luna")
        XCTAssertEqual((body["reasoning"] as? [String: Any])?["effort"] as? String, "low")
        let format = try XCTUnwrap(body["response_format"] as? [String: Any])
        XCTAssertEqual(format["type"] as? String, "json_schema")
        let jsonSchema = try XCTUnwrap(format["json_schema"] as? [String: Any])
        XCTAssertEqual(jsonSchema["strict"] as? Bool, true)
        let schema = try XCTUnwrap(jsonSchema["schema"] as? [String: Any])
        XCTAssertEqual(schema["additionalProperties"] as? Bool, false)
        XCTAssertEqual((schema["required"] as? [String])?.count, (schema["properties"] as? [String: Any])?.count)

        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.map { $0["role"] as? String }, ["system", "user"])
        XCTAssertEqual(messages[0]["content"] as? String, LabelReader.instructions)
        let parts = try XCTUnwrap(messages[1]["content"] as? [[String: Any]])
        let image = try XCTUnwrap(parts.first { $0["type"] as? String == "image_url" }?["image_url"] as? [String: Any])
        XCTAssertEqual(image["url"] as? String, "data:image/jpeg;base64,AQID")
        XCTAssertEqual(image["detail"] as? String, "high")
        XCTAssertNil(LabelReader.headers["x-api-key"])
        XCTAssertNil(LabelReader.headers["anthropic-version"])
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

        // 1680 kJ is 401.53 kcal, rounded to whole kcal for the form.
        XCTAssertEqual(reading.energyKcal, 402)
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

    func testValuesWorkedOutFromAPortionAreRounded() throws {
        // A US label: 28 g per serving, sodium in milligrams.
        let reading = try LabelReader.reading(fromAnswer: answer(label([
            "column": "per_portion", "portion_grams": 28, "portion_name": "1 serving",
            "energy_kcal": 130, "fat_g": 5, "saturated_fat_g": 3.5, "carbohydrates_g": 20, "protein_g": 1,
            "sodium_mg": 45,
        ])))

        XCTAssertEqual(reading.energyKcal, 464)
        XCTAssertEqual(reading.fatG, 17.9)
        XCTAssertEqual(reading.saturatedFatG, 12.5)
        XCTAssertEqual(reading.carbohydratesG, 71.4)
        XCTAssertEqual(reading.proteinG, 3.6)
        XCTAssertEqual(reading.saltG, 0.4)
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
        // Without a known column the values could be per portion, so they aren't used as per 100 g.
        XCTAssertEqual(problem(try answer(label(["column": NSNull(), "energy_kcal": 402]))), .unknownColumn)
        XCTAssertEqual(problem(try answer(label(["column": "per_serving", "energy_kcal": 402]))), .unknownColumn)
        XCTAssertEqual(problem(try answer("", refusal: "I can't help with that.")), .declined)
        XCTAssertEqual(problem(try answer("", finishReason: "content_filter")), .declined)
        XCTAssertEqual(problem(try answer(#"{"is_nutrition_la"#, finishReason: "length")), .cutOff)
        XCTAssertEqual(problem(try answer("", finishReason: "error")), .interrupted)
        XCTAssertEqual(problem(try answer("Here is the label")), .unreadableAnswer)
        XCTAssertEqual(problem(Data("<html>".utf8)), .unreadableAnswer)
        XCTAssertEqual(problem(Data(#"{"choices": []}"#.utf8)), .unreadableAnswer)
        // An error while the model answers comes with HTTP 200 and no usable choice.
        XCTAssertEqual(problem(Data(#"{"id": "gen-02", "error": {"code": 502, "message": "Provider returned error"}}"#.utf8)), .interrupted)
    }

    func testContentAsTextPartsIsRead() throws {
        let text = try label(["energy_kcal": 402, "fat_g": 18, "carbohydrates_g": 49, "protein_g": 8.1])
        let data = try JSONSerialization.data(withJSONObject: [
            "choices": [["finish_reason": "stop", "message": ["role": "assistant", "content": [["type": "text", "text": text]]]]],
        ])

        XCTAssertEqual(try LabelReader.reading(fromAnswer: data).energyKcal, 402)
    }

    func testFlaggedPhotoIsToldApartFromALimitedKey() {
        XCTAssertTrue(LabelReader.wasFlagged(errorAnswer: Data("""
        {"error": {"code": 403, "message": "Input was flagged", "metadata": {"reasons": ["violence"],
         "flagged_input": "…", "provider_name": "OpenAI", "model_slug": "openai/gpt-6-luna"}}}
        """.utf8)))
        XCTAssertFalse(LabelReader.wasFlagged(errorAnswer: Data("""
        {"error": {"code": 403, "message": "Key limit exceeded", "metadata": {"limit_source": "openrouter_key_limit"}}}
        """.utf8)))
        XCTAssertFalse(LabelReader.wasFlagged(errorAnswer: Data("<html>".utf8)))
    }
}
