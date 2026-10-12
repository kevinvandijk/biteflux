import XCTest
@testable import BitefluxCore

final class GramDialTests: XCTestCase {
    func testStepAndTurnSuitTheServing() {
        XCTAssertEqual(GramDial(servingGrams: nil), GramDial(servingGrams: 100))
        XCTAssertEqual(GramDial(servingGrams: 150).step, 5)
        XCTAssertEqual(GramDial(servingGrams: 150).gramsPerTurn, 500)
        // A sweet of 2.2 g moves a gram at a time.
        XCTAssertEqual(GramDial(servingGrams: 2.2).step, 1)
        // A 450 g meal gets a bigger turn.
        XCTAssertEqual(GramDial(servingGrams: 450).gramsPerTurn, 900)
    }

    func testFillAndHandle() {
        let dial = GramDial(servingGrams: 150)
        XCTAssertEqual(dial.fill(for: 125), 0.25)
        XCTAssertEqual(dial.angle(for: 125), 90)
        // Past one turn the ring stays full and the handle keeps going round.
        XCTAssertEqual(dial.fill(for: 750), 1)
        XCTAssertEqual(dial.angle(for: 750), 180)
    }

    func testTurningAddsAndTakesAway() {
        let dial = GramDial(servingGrams: 150)
        XCTAssertEqual(dial.grams(turningFrom: 0, to: 72), 100, accuracy: 0.0001)
        XCTAssertEqual(dial.grams(turningFrom: 72, to: 0), -100, accuracy: 0.0001)
        // Passing the top clockwise adds, rather than taking a whole turn away.
        XCTAssertEqual(dial.grams(turningFrom: 350, to: 10), 500 * 20 / 360, accuracy: 0.0001)
        XCTAssertEqual(dial.grams(turningFrom: 10, to: 350), -500 * 20 / 360, accuracy: 0.0001)
    }

    func testSnapping() {
        let dial = GramDial(servingGrams: 150)
        XCTAssertEqual(dial.snapped(152.4), 150)
        XCTAssertEqual(dial.snapped(152.6), 155)
        XCTAssertEqual(dial.snapped(-20), 5)
        XCTAssertEqual(GramDial(servingGrams: 2.2).snapped(2.4), 2)
    }

    func testAngleOfATouch() {
        let center = (x: 100.0, y: 100.0)
        XCTAssertEqual(GramDial.angle(of: (x: 100, y: 0), around: center), 0, accuracy: 0.0001)
        XCTAssertEqual(GramDial.angle(of: (x: 200, y: 100), around: center), 90, accuracy: 0.0001)
        XCTAssertEqual(GramDial.angle(of: (x: 100, y: 200), around: center), 180, accuracy: 0.0001)
        XCTAssertEqual(GramDial.angle(of: (x: 0, y: 100), around: center), 270, accuracy: 0.0001)
    }
}
