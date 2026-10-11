import Foundation

extension Double {
    /// Whole kcal or grams for display, like "1,626".
    var wholeNumber: String {
        rounded().formatted(.number.precision(.fractionLength(0)))
    }
}
