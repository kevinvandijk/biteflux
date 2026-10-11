import Foundation

/// Reads answers from the Open Food Facts product API (`/api/v2/product/<barcode>`) and its
/// search service (search.openfoodfacts.org).
///
/// Open Food Facts is crowd-sourced, so a product can lack values or carry wrong ones; the app
/// shows what it found for a check against the label before using it.
public enum OpenFoodFacts {
    /// The fields Biteflux asks for, which keeps each answer small.
    public static let fields = [
        "code", "product_name", "product_name_nl", "product_name_en",
        "brands", "nutriments", "serving_size", "serving_quantity", "serving_quantity_unit",
    ]

    public static func productURL(barcode: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "world.openfoodfacts.org"
        components.path = "/api/v2/product/\(barcode)"
        components.queryItems = [URLQueryItem(name: "fields", value: fields.joined(separator: ","))]
        return components.url!
    }

    /// A search by name on Open Food Facts' search service, which answers apps without an account
    /// where the main site's search often turns them away. The app only searches when asked to.
    public static func searchURL(for terms: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "search.openfoodfacts.org"
        components.path = "/search"
        components.queryItems = [
            URLQueryItem(name: "q", value: terms),
            URLQueryItem(name: "page_size", value: "20"),
            URLQueryItem(name: "fields", value: fields.joined(separator: ",")),
        ]
        return components.url!
    }

    public enum Lookup: Equatable, Sendable {
        case found(Product)
        case notFound
    }

    /// A product as Open Food Facts describes it.
    public struct Product: Equatable, Sendable {
        public var barcode: String
        /// Nil when nobody entered a name.
        public var name: String?
        /// The first of the listed brands.
        public var brand: String?
        /// Nil when energy, protein, carbohydrates or fat is missing,
        /// so the values have to come from the label instead.
        public var per100g: Nutrients?
        /// The weight of one serving. Nil when the pack gives none, or gives a volume like
        /// 330 ml, since Biteflux logs portions in grams.
        public var servingGrams: Double?
        /// How the pack describes one serving, like "1 koek (25 g)".
        public var servingDescription: String?

        public init(
            barcode: String,
            name: String?,
            brand: String?,
            per100g: Nutrients?,
            servingGrams: Double? = nil,
            servingDescription: String? = nil
        ) {
            self.barcode = barcode
            self.name = name
            self.brand = brand
            self.per100g = per100g
            self.servingGrams = servingGrams
            self.servingDescription = servingDescription
        }

        /// The serving's name without its weight, like "1 koek" from "1 koek (25 g)".
        /// Nil when the pack gives only a weight.
        public var servingName: String? {
            guard servingGrams != nil,
                  let description = servingDescription,
                  let bracket = description.firstIndex(of: "(") else { return nil }
            let name = description[..<bracket].trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? nil : name
        }
    }

    public enum Problem: Error, Equatable {
        /// The answer wasn't the JSON object the API sends.
        case unreadableAnswer
    }

    /// Reads the answer to a lookup of `barcode`.
    public static func lookup(barcode: String, from data: Data) throws -> Lookup {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw Problem.unreadableAnswer
        }
        guard number(root["status"]) != 0, let product = root["product"] as? [String: Any] else {
            return .notFound
        }
        return .found(self.product(product, barcode: barcode))
    }

    /// Reads the answer to `searchURL(for:)`: the products with a valid barcode and a name.
    /// The search service lists them under "hits", the main site's search under "products".
    public static func products(fromSearch data: Data) throws -> [Product] {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let products = (root["hits"] ?? root["products"]) as? [[String: Any]] else {
            throw Problem.unreadableAnswer
        }
        // Open Food Facts can list the same barcode twice; the first one counts.
        var seen: Set<String> = []
        return products.compactMap { product in
            guard let code = text(product["code"]) ?? number(product["code"]).map({ String(Int($0)) }),
                  let barcode = Barcode.normalized(code) else { return nil }
            let found = self.product(product, barcode: barcode)
            guard found.name != nil, seen.insert(barcode).inserted else { return nil }
            return found
        }
    }

    private static func product(_ product: [String: Any], barcode: String) -> Product {
        let nutriments = product["nutriments"] as? [String: Any] ?? [:]
        func per100g(_ key: String) -> Double? {
            number(nutriments["\(key)_100g"])
        }

        // Labels give kcal, kJ or both; "energy" is kJ.
        let energyKcal = per100g("energy-kcal")
            ?? (per100g("energy-kj") ?? per100g("energy")).map(NutritionConversion.kilocalories(fromKilojoules:))
        // EU labels list salt, so it is the value people checked; sodium is in grams here.
        let sodiumMg = per100g("salt").map(NutritionConversion.sodiumMilligrams(fromSaltGrams:))
            ?? per100g("sodium").map { $0 * 1000 }

        var nutrients: Nutrients?
        if let energyKcal,
           let protein = per100g("proteins"),
           let carbohydrates = per100g("carbohydrates"),
           let fat = per100g("fat") {
            nutrients = Nutrients(
                energyKcal: energyKcal,
                proteinG: protein,
                carbohydratesG: carbohydrates,
                sugarG: per100g("sugars"),
                fiberG: per100g("fiber"),
                fatG: fat,
                saturatedFatG: per100g("saturated-fat"),
                sodiumMg: sodiumMg
            )
        }

        let name = ["product_name", "product_name_nl", "product_name_en"]
            .lazy
            .compactMap { text(product[$0]) }
            .first
        // The product API sends brands as one comma-separated string, the search service as a list.
        let brands: [Any]
        if let listed = product["brands"] as? String {
            brands = listed.split(separator: ",").map(String.init)
        } else {
            brands = product["brands"] as? [Any] ?? []
        }
        let brand = brands.lazy.compactMap { text($0) }.first

        let servingDescription = text(product["serving_size"])
        // serving_quantity is in grams or millilitres; older products only say which in serving_size.
        let servingIsWeight = text(product["serving_quantity_unit"]).map { $0.lowercased() == "g" }
            ?? !(servingDescription.map(mentionsVolume) ?? false)

        return Product(
            barcode: barcode,
            name: name,
            brand: brand,
            per100g: nutrients,
            servingGrams: servingIsWeight ? number(product["serving_quantity"]).flatMap { $0 > 0 ? $0 : nil } : nil,
            servingDescription: servingDescription
        )
    }

    /// Whether a serving text gives a volume, like "330 ml" or "1 glas (25cl)".
    private static func mentionsVolume(_ text: String) -> Bool {
        text.range(of: #"\d\s*(ml|cl|dl|l|liter|litre)\b"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Open Food Facts sends most numbers as numbers, but some as strings.
    private static func number(_ value: Any?) -> Double? {
        switch value {
        case let number as Double: number
        case let number as Int: Double(number)
        case let number as NSNumber: number.doubleValue
        case let string as String: DecimalInput.value(string)
        default: nil
        }
    }

    private static func text(_ value: Any?) -> String? {
        guard let string = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmpty else { return nil }
        return string
    }
}
