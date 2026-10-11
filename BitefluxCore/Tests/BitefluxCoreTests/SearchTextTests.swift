import XCTest
@testable import BitefluxCore

final class SearchTextTests: XCTestCase {
    func testIgnoresCaseAndAccents() {
        XCTAssertTrue(SearchText.matches("creme", in: ["Crème fraîche", nil]))
        XCTAssertTrue(SearchText.matches("SKYR", in: ["Skyr Naturel", "Arla"]))
    }

    func testEveryWordMustAppearSomewhere() {
        XCTAssertTrue(SearchText.matches("skyr arla", in: ["Skyr Naturel", "Arla"]))
        XCTAssertFalse(SearchText.matches("skyr kaas", in: ["Skyr Naturel", "Arla"]))
    }

    func testEmptyQueryMatchesEverything() {
        XCTAssertTrue(SearchText.matches("  ", in: ["Appel"]))
    }
}
