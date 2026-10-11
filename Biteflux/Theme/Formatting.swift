import Foundation

extension Double {
    /// Whole kcal or grams for display, like "1,626".
    var wholeNumber: String {
        rounded().formatted(.number.precision(.fractionLength(0)))
    }

    /// Grams with at most one decimal, like "25" or "12.5".
    var amount: String {
        formatted(.number.precision(.fractionLength(0...1)))
    }

    /// A number to fill in a field that is read back as one: no thousands separators, and up to
    /// two decimals, so a label's "0,45 g" of salt stays as printed.
    var inputText: String {
        formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }
}
