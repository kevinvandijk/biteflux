import Foundation

/// Numbers typed from a label, where Dutch packs write "4,5" and English ones "4.5".
public enum DecimalInput {
    /// The number in `text`, accepting a comma or a point as the decimal mark.
    /// Nil for an empty field, anything that isn't a number, or a negative amount.
    public static func value(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !trimmed.isEmpty,
              trimmed.allSatisfy({ ($0.isASCII && $0.isNumber) || $0 == "." }),
              let value = Double(trimmed) else { return nil }
        return value
    }
}
