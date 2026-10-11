import XCTest
@testable import BitefluxCore

final class DecimalInputTests: XCTestCase {
    func testCommaOrPoint() {
        XCTAssertEqual(DecimalInput.value("4,5"), 4.5)
        XCTAssertEqual(DecimalInput.value("4.5"), 4.5)
        XCTAssertEqual(DecimalInput.value(" 402 "), 402)
    }

    func testRejectsWhatIsNotAnAmount() {
        XCTAssertNil(DecimalInput.value(""))
        XCTAssertNil(DecimalInput.value("abc"))
        XCTAssertNil(DecimalInput.value("-3"))
        XCTAssertNil(DecimalInput.value("4,5,1"))
    }
}
