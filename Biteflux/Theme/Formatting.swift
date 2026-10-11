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

    /// The same, without thousands separators, to fill in a field that is read back as a number.
    var inputText: String {
        formatted(.number.precision(.fractionLength(0...1)).grouping(.never))
    }
}
