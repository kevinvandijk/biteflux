import Foundation

/// Reads a nutrition label from a photo with OpenAI's GPT-6 Luna, through OpenRouter's chat
/// completions API.
///
/// This builds the request and reads the answer; the app sends it with the user's own OpenRouter
/// key. The model copies the numbers as printed, and Biteflux does the unit conversions itself,
/// the same way it does for Open Food Facts.
public enum LabelReader {
    public static let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    /// GPT Luna 6 on OpenRouter: fast and cheap, and it reads images.
    public static let model = "openai/gpt-6-luna"

    /// The headers every request carries next to `Authorization`. OpenRouter uses the last two
    /// to show which app sent a request.
    public static let headers = [
        "content-type": "application/json",
        "HTTP-Referer": "https://github.com/kevinvandijk/biteflux",
        "X-OpenRouter-Title": "Biteflux",
    ]

    /// The label values the model can flag as hard to read.
    public enum Field: String, CaseIterable, Hashable, Sendable {
        case energy
        case fat
        case saturatedFat = "saturated_fat"
        case carbohydrates
        case sugars
        case fiber
        case protein
        case salt
    }

    /// What the model read from a label, per 100 g. A value is nil when the label doesn't list it
    /// or the model couldn't read it.
    public struct Reading: Equatable, Hashable, Sendable {
        public var name: String?
        public var brand: String?
        public var energyKcal: Double?
        public var proteinG: Double?
        public var carbohydratesG: Double?
        public var sugarG: Double?
        public var fiberG: Double?
        public var fatG: Double?
        public var saturatedFatG: Double?
        /// Salt as on EU labels; worked out from sodium when the label lists only that.
        public var saltG: Double?
        /// The weight of one portion, when the label prints it.
        public var servingGrams: Double?
        /// How one portion reads, like "1 koek".
        public var servingName: String?
        /// The label gives values per 100 ml, which Biteflux treats as per 100 g.
        public var perMillilitre: Bool
        /// The label only gives values per portion, so these were worked out per 100 g.
        public var fromPortion: Bool
        /// Values the model could only partly read, through glare, blur or a cut-off photo.
        public var unsure: Set<Field>

        public init(
            name: String? = nil,
            brand: String? = nil,
            energyKcal: Double? = nil,
            proteinG: Double? = nil,
            carbohydratesG: Double? = nil,
            sugarG: Double? = nil,
            fiberG: Double? = nil,
            fatG: Double? = nil,
            saturatedFatG: Double? = nil,
            saltG: Double? = nil,
            servingGrams: Double? = nil,
            servingName: String? = nil,
            perMillilitre: Bool = false,
            fromPortion: Bool = false,
            unsure: Set<Field> = []
        ) {
            self.name = name
            self.brand = brand
            self.energyKcal = energyKcal
            self.proteinG = proteinG
            self.carbohydratesG = carbohydratesG
            self.sugarG = sugarG
            self.fiberG = fiberG
            self.fatG = fatG
            self.saturatedFatG = saturatedFatG
            self.saltG = saltG
            self.servingGrams = servingGrams
            self.servingName = servingName
            self.perMillilitre = perMillilitre
            self.fromPortion = fromPortion
            self.unsure = unsure
        }
    }

    public enum Problem: Error, Equatable {
        /// The photo shows no nutrition table.
        case notALabel
        /// The label only gives values per portion and doesn't say what a portion weighs.
        case onlyPerPortion
        /// The model or a content check declined the photo.
        case declined
        /// The answer ran out of room before it was complete.
        case cutOff
        /// The model stopped with an error partway through its answer.
        case interrupted
        /// The answer wasn't what the request asked for.
        case unreadableAnswer
    }

    /// The request body for reading one label photo, sent as JPEG.
    public static func requestBody(jpeg: Data) -> Data {
        let body: [String: Any] = [
            "model": model,
            "max_completion_tokens": 16_000,
            // Copying numbers from a photo needs little reasoning, and a lower effort answers faster.
            "reasoning": ["effort": "low"],
            "response_format": [
                "type": "json_schema",
                "json_schema": ["name": "nutrition_label", "strict": true, "schema": answerSchema],
            ],
            "messages": [
                ["role": "system", "content": instructions],
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": "Read this label."],
                        [
                            "type": "image_url",
                            // High detail keeps the small print on a label readable.
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(jpeg.base64EncodedString())",
                                "detail": "high",
                            ],
                        ],
                    ],
                ],
            ],
        ]
        // The dictionary holds only JSON types, so this can't fail.
        return try! JSONSerialization.data(withJSONObject: body, options: [.sortedKeys, .withoutEscapingSlashes])
    }

    /// Reads the API's answer to `requestBody(jpeg:)`: the label JSON in the first choice's message.
    public static func reading(fromAnswer data: Data) throws -> Reading {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw Problem.unreadableAnswer
        }
        // An error that happens while the model answers still comes with HTTP 200.
        if root["error"] != nil { throw Problem.interrupted }
        guard let choice = (root["choices"] as? [[String: Any]])?.first,
              let message = choice["message"] as? [String: Any] else {
            throw Problem.unreadableAnswer
        }
        if let refusal = message["refusal"] as? String,
           !refusal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw Problem.declined
        }
        switch choice["finish_reason"] as? String {
        case "content_filter": throw Problem.declined
        case "length": throw Problem.cutOff
        case "error": throw Problem.interrupted
        default: break
        }
        // Content is a string; some providers send a list of text parts instead.
        let text = (message["content"] as? String)
            ?? (message["content"] as? [[String: Any]])?.compactMap { $0["text"] as? String }.joined()
            ?? ""
        guard let label = (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any] else {
            throw Problem.unreadableAnswer
        }
        return try reading(fromLabel: label)
    }

    /// Whether an error answer (HTTP 403) means OpenRouter's moderation flagged the photo,
    /// rather than the key not being allowed to spend.
    public static func wasFlagged(errorAnswer data: Data) -> Bool {
        let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let metadata = (root?["error"] as? [String: Any])?["metadata"] as? [String: Any]
        return (metadata?["reasons"] as? [Any])?.isEmpty == false || metadata?["flagged_input"] != nil
    }

    /// Turns the label as the model copied it into values per 100 g.
    static func reading(fromLabel label: [String: Any]) throws -> Reading {
        guard label["is_nutrition_label"] as? Bool == true else { throw Problem.notALabel }

        func amount(_ key: String) -> Double? {
            guard let value = label[key] as? NSNumber, value.doubleValue >= 0 else { return nil }
            return value.doubleValue
        }
        func text(_ key: String) -> String? {
            guard let value = (label[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { return nil }
            return value
        }

        let column = label["column"] as? String
        let portionGrams = amount("portion_grams").flatMap { $0 > 0 ? $0 : nil }
        var factor = 1.0
        if column == "per_portion" {
            guard let portionGrams else { throw Problem.onlyPerPortion }
            factor = 100 / portionGrams
        }
        func per100g(_ key: String) -> Double? {
            amount(key).map { $0 * factor }
        }

        let salt = per100g("salt_g") ?? per100g("sodium_mg").map { $0 / NutritionConversion.sodiumMilligrams(fromSaltGrams: 1) }
        let unsure = (label["unsure"] as? [String] ?? []).compactMap(Field.init(rawValue:))

        return Reading(
            name: text("product_name"),
            brand: text("brand"),
            energyKcal: per100g("energy_kcal") ?? per100g("energy_kj").map(NutritionConversion.kilocalories(fromKilojoules:)),
            proteinG: per100g("protein_g"),
            carbohydratesG: per100g("carbohydrates_g"),
            sugarG: per100g("sugars_g"),
            fiberG: per100g("fiber_g"),
            fatG: per100g("fat_g"),
            saturatedFatG: per100g("saturated_fat_g"),
            saltG: salt,
            servingGrams: portionGrams,
            servingName: portionGrams == nil ? nil : text("portion_name"),
            perMillilitre: column == "per_100ml",
            fromPortion: column == "per_portion",
            unsure: Set(unsure)
        )
    }

    static let instructions = """
    You read nutrition labels from photos of food packaging, mostly Dutch and sometimes English. \
    Copy the numbers exactly as printed; don't estimate, round or calculate anything. \
    Biteflux converts units itself.

    Use the per 100 g or per 100 ml column when the label has one, and say which in "column". \
    Use "per_portion" only when the label gives values for a portion and nothing per 100 g or 100 ml.

    Dutch names: Energie is energy, Vetten or Vet is fat, waarvan verzadigd(e vetzuren) is saturated fat, \
    Koolhydraten is carbohydrates, waarvan suikers is sugars, Vezels or Voedingsvezel is fiber, \
    Eiwitten is protein, and Zout is salt. Labels write decimals with a comma; return them as numbers. \
    Give energy in both kJ and kcal when both are printed. A value written as "<0,5" or "sporen" is 0.

    Set a value to null when the label doesn't list it or you can't read it at all. List in "unsure" \
    every value you could only partly read, for example through glare, blur, a fold or a cut-off edge.

    When the label names a portion with its weight, like "per koek (25 g)", give the weight in \
    "portion_grams" and the words in "portion_name", like "1 koek". Give the product name and brand \
    only when they are on the photo.

    Set "is_nutrition_label" to false when the photo shows no nutrition table, and leave the rest null.
    """

    static let answerSchema: [String: Any] = {
        let number: [String: Any] = ["anyOf": [["type": "number"], ["type": "null"]]]
        let string: [String: Any] = ["anyOf": [["type": "string"], ["type": "null"]]]
        let properties: [String: Any] = [
            "is_nutrition_label": ["type": "boolean"],
            "product_name": string,
            "brand": string,
            "column": ["anyOf": [["type": "string", "enum": ["per_100g", "per_100ml", "per_portion"]], ["type": "null"]]],
            "portion_grams": number,
            "portion_name": string,
            "energy_kj": number,
            "energy_kcal": number,
            "fat_g": number,
            "saturated_fat_g": number,
            "carbohydrates_g": number,
            "sugars_g": number,
            "fiber_g": number,
            "protein_g": number,
            "salt_g": number,
            "sodium_mg": number,
            "unsure": ["type": "array", "items": ["type": "string", "enum": Field.allCases.map(\.rawValue)]],
        ]
        return [
            "type": "object",
            "properties": properties,
            "required": properties.keys.sorted(),
            "additionalProperties": false,
        ]
    }()
}
