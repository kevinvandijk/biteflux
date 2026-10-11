import Foundation

/// The number under a product's barcode: EAN-8, UPC-A, EAN-13 or GTIN-14.
public enum Barcode {
    /// The digits of `input` without spaces or dashes when they form a barcode with a correct
    /// check digit, so a mistyped number is caught before it is looked up. Otherwise nil.
    public static func normalized(_ input: String) -> String? {
        let digits = input.filter { !$0.isWhitespace && $0 != "-" }
        guard [8, 12, 13, 14].contains(digits.count),
              digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }

        let values = digits.compactMap(\.wholeNumberValue)
        // From the right, leaving out the check digit, digits count three times and once in turn.
        var sum = 0
        for (offset, value) in values.dropLast().reversed().enumerated() {
            sum += value * (offset.isMultiple(of: 2) ? 3 : 1)
        }
        guard (10 - sum % 10) % 10 == values.last else { return nil }
        return digits
    }
}
