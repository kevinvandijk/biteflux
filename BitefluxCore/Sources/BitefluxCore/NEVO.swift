import Foundation

/// Reads NEVO-online, the Dutch food composition table by RIVM, from its CSV export.
///
/// RIVM's conditions of use: the values stay unchanged, the source and version are named
/// wherever values worked out from NEVO are shown, and nobody is charged for them.
public enum NEVO {
    /// The source line RIVM requires next to values worked out from NEVO.
    public static let attribution = "Based on data from NEVO online version 2025/9.0, RIVM, Bilthoven"
    /// The same line for totals that mix NEVO with other sources.
    public static let mixedAttribution = attribution + ", and other data sources"
    /// The export's file name without its extension.
    public static let fileName = "NEVO2025_v9.0"

    /// One food from the table, with its values per 100 g.
    public struct Food: Equatable, Sendable, Identifiable {
        /// The NEVO code, like "875".
        public var code: String
        /// The Dutch name as NEVO writes it, like "Appel m schil gem".
        public var dutchName: String
        public var englishName: String?
        public var synonym: String?
        public var per100g: Nutrients

        public var id: String { code }

        public init(code: String, dutchName: String, englishName: String?, synonym: String?, per100g: Nutrients) {
            self.code = code
            self.dutchName = dutchName
            self.englishName = englishName
            self.synonym = synonym
            self.per100g = per100g
        }
    }

    public enum Problem: Error, Equatable {
        case missingColumn(String)
    }

    /// The foods in a NEVO-online CSV: "|" between columns, quoted header and numbers,
    /// decimal commas, and sodium in mg. Foods given per 100 ml (infant formula) are left
    /// out, since Biteflux logs portions in grams.
    public static func foods(fromCSV text: String) throws -> [Food] {
        // "\r\n" is a single Character in Swift, so this also splits Windows line endings.
        let lines = text.split(whereSeparator: \.isNewline)
        guard let headerLine = lines.first else { return [] }
        let header = fields(headerLine)

        func namedColumn(_ name: String) throws -> Int {
            guard let index = header.firstIndex(of: name) else { throw Problem.missingColumn(name) }
            return index
        }
        /// Nutrient columns read like "ENERCC (kcal)"; the code before the unit identifies them.
        func nutrientColumn(_ code: String) throws -> Int {
            guard let index = header.firstIndex(where: { $0.split(separator: " ").first == Substring(code) }) else {
                throw Problem.missingColumn(code)
            }
            return index
        }

        let codeColumn = try namedColumn("NEVO-code")
        let dutchColumn = try namedColumn("Voedingsmiddelnaam/Dutch food name")
        let englishColumn = try namedColumn("Engelse naam/Food name")
        let synonymColumn = try namedColumn("Synoniem")
        let quantityColumn = try namedColumn("Hoeveelheid/Quantity")
        let kcal = try nutrientColumn("ENERCC")
        let protein = try nutrientColumn("PROT")
        let carbohydrates = try nutrientColumn("CHO")
        let sugar = try nutrientColumn("SUGAR")
        let fiber = try nutrientColumn("FIBT")
        let fat = try nutrientColumn("FAT")
        let saturatedFat = try nutrientColumn("FASAT")
        let sodium = try nutrientColumn("NA")

        return lines.dropFirst().compactMap { line -> Food? in
            let row = fields(line)
            func text(_ index: Int) -> String? {
                guard index < row.count, !row[index].isEmpty else { return nil }
                return row[index]
            }
            func amount(_ index: Int) -> Double? {
                text(index).flatMap(DecimalInput.value)
            }

            guard let code = text(codeColumn),
                  let dutchName = text(dutchColumn),
                  !(text(quantityColumn)?.lowercased().contains("ml") ?? false),
                  let energyKcal = amount(kcal),
                  let proteinG = amount(protein),
                  let carbohydratesG = amount(carbohydrates),
                  let fatG = amount(fat) else { return nil }

            return Food(
                code: code,
                dutchName: dutchName,
                englishName: text(englishColumn),
                synonym: text(synonymColumn),
                per100g: Nutrients(
                    energyKcal: energyKcal,
                    proteinG: proteinG,
                    carbohydratesG: carbohydratesG,
                    sugarG: amount(sugar),
                    fiberG: amount(fiber),
                    fatG: fatG,
                    saturatedFatG: amount(saturatedFat),
                    sodiumMg: amount(sodium)
                )
            )
        }
    }

    /// Foods whose Dutch name, English name or synonym holds every word of `query`.
    /// Names that begin with the query as a whole word come first, then names that begin
    /// with it at all, then names with a word that begins with it, then the rest, each in
    /// table order. So "appel" lists "Appel m schil gem", then "Appelstroop", then
    /// "Taart appel", and only then "Aardappelen", where "appel" sits inside a word.
    public static func search(_ query: String, in foods: [Food], limit: Int = 20) -> [Food] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        let folded = fold(trimmed)
        let queryWords = folded.split(whereSeparator: \.isWhitespace)

        func rank(_ food: Food) -> Int {
            let names = [food.dutchName, food.englishName, food.synonym].compactMap { $0.map(fold) }
            if names.contains(where: { $0 == folded || $0.hasPrefix(folded + " ") }) { return 0 }
            if names.contains(where: { $0.hasPrefix(folded) }) { return 1 }
            let nameWords = names.flatMap { name in name.split { !$0.isLetter && !$0.isNumber } }
            if queryWords.allSatisfy({ word in nameWords.contains { $0.hasPrefix(word) } }) { return 2 }
            return 3
        }

        return foods
            .filter { SearchText.matches(trimmed, in: [$0.dutchName, $0.englishName, $0.synonym]) }
            .enumerated()
            .map { (rank: rank($0.element), offset: $0.offset, food: $0.element) }
            .sorted { ($0.rank, $0.offset) < ($1.rank, $1.offset) }
            .prefix(limit)
            .map { $0.food }
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// Splits one line on "|" and removes the quotes around a value.
    private static func fields(_ line: Substring) -> [String] {
        line.split(separator: "|", omittingEmptySubsequences: false).map { field in
            var value = field.trimmingCharacters(in: .whitespaces)
            if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast()).replacingOccurrences(of: "\"\"", with: "\"")
            }
            return value
        }
    }
}
