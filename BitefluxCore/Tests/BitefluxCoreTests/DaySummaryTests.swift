import XCTest
@testable import BitefluxCore

final class DaySummaryTests: XCTestCase {
    func testRemainingAndProgress() {
        // The B4 Today screen: 674 eaten of 2,300 leaves 1,626.
        let summary = DaySummary(goalKcal: 2300, eaten: [
            Nutrients(energyKcal: 200, proteinG: 18, carbohydratesG: 33, fatG: 1),
            Nutrients(energyKcal: 278, proteinG: 15, carbohydratesG: 40, fatG: 10),
            Nutrients(energyKcal: 196, proteinG: 2, carbohydratesG: 25, fatG: 5),
        ])

        XCTAssertEqual(summary.eaten.energyKcal, 674, accuracy: 0.001)
        XCTAssertEqual(summary.remainingKcal, 1626, accuracy: 0.001)
        XCTAssertEqual(summary.progress, 674.0 / 2300.0, accuracy: 0.0001)
    }

    func testOverGoalGoesNegativeAndProgressCaps() {
        let summary = DaySummary(goalKcal: 2000, eaten: [
            Nutrients(energyKcal: 2150, proteinG: 0, carbohydratesG: 0, fatG: 0),
        ])

        XCTAssertEqual(summary.remainingKcal, -150, accuracy: 0.001)
        XCTAssertEqual(summary.progress, 1)
    }

    func testEmptyDay() {
        let summary = DaySummary(goalKcal: 2300, eaten: [])

        XCTAssertEqual(summary.eaten, .zero)
        XCTAssertEqual(summary.progress, 0)
    }
}
