import XCTest
@testable import BitefluxCore

final class MealTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        return calendar
    }

    private func at(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: hour, minute: minute))!
    }

    func testMealBoundaries() {
        XCTAssertEqual(Meal.suggested(at: at(3, 59), calendar: calendar), .snacks)
        XCTAssertEqual(Meal.suggested(at: at(4, 0), calendar: calendar), .breakfast)
        XCTAssertEqual(Meal.suggested(at: at(10, 59), calendar: calendar), .breakfast)
        XCTAssertEqual(Meal.suggested(at: at(11, 0), calendar: calendar), .lunch)
        XCTAssertEqual(Meal.suggested(at: at(14, 59), calendar: calendar), .lunch)
        XCTAssertEqual(Meal.suggested(at: at(15, 30), calendar: calendar), .snacks)
        XCTAssertEqual(Meal.suggested(at: at(17, 0), calendar: calendar), .dinner)
        XCTAssertEqual(Meal.suggested(at: at(21, 29), calendar: calendar), .dinner)
        XCTAssertEqual(Meal.suggested(at: at(21, 30), calendar: calendar), .snacks)
    }
}
