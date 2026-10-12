import XCTest
@testable import BitefluxCore

final class DailyGoalTests: XCTestCase {
    func testReadsATypedGoal() {
        XCTAssertEqual(DailyGoal.kcal(from: "2100"), 2100)
        XCTAssertEqual(DailyGoal.kcal(from: " 1950 kcal "), 1950)
        XCTAssertEqual(DailyGoal.kcal(from: "2099,6"), 2100)
    }

    func testRefusesWhatIsntAGoal() {
        XCTAssertNil(DailyGoal.kcal(from: ""))
        XCTAssertNil(DailyGoal.kcal(from: "lots"))
        // A missing digit or one too many.
        XCTAssertNil(DailyGoal.kcal(from: "230"))
        XCTAssertNil(DailyGoal.kcal(from: "23000"))
    }

    func testSuggestionsAreValidGoals() {
        XCTAssertTrue(DailyGoal.range.contains(DailyGoal.standardKcal))
        for kcal in DailyGoal.suggestions {
            XCTAssertTrue(DailyGoal.range.contains(kcal))
        }
    }
}
