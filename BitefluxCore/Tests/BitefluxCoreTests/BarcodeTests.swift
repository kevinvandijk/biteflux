import XCTest
@testable import BitefluxCore

final class BarcodeTests: XCTestCase {
    func testAcceptsEachLengthWithACorrectCheckDigit() {
        XCTAssertEqual(Barcode.normalized("3017624010701"), "3017624010701")  // EAN-13
        XCTAssertEqual(Barcode.normalized("96385074"), "96385074")  // EAN-8
        XCTAssertEqual(Barcode.normalized("036000291452"), "036000291452")  // UPC-A
        XCTAssertEqual(Barcode.normalized("03017624010701"), "03017624010701")  // GTIN-14
    }

    func testDropsSpacesAndDashes() {
        XCTAssertEqual(Barcode.normalized(" 3017 6240-10701 "), "3017624010701")
    }

    func testRejectsTyposAndOtherInput() {
        XCTAssertNil(Barcode.normalized("3017624010702"))  // wrong check digit
        XCTAssertNil(Barcode.normalized("3017624010170"))  // two digits swapped
        XCTAssertNil(Barcode.normalized("12345"))
        XCTAssertNil(Barcode.normalized("301762401070A"))
        XCTAssertNil(Barcode.normalized(""))
    }
}
