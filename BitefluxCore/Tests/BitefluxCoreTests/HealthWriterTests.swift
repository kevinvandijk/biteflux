import XCTest
@testable import BitefluxCore

final class HealthWriterTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func testAWriterThatTriedRecentlyKeepsTheEntry() {
        XCTAssertFalse(HealthWriter.isQuiet(lastTried: now, now: now))
        XCTAssertFalse(HealthWriter.isQuiet(lastTried: now.addingTimeInterval(-23 * 60 * 60), now: now))
    }

    func testAWriterQuietForADayCanBeTakenOver() {
        XCTAssertTrue(HealthWriter.isQuiet(lastTried: now.addingTimeInterval(-HealthWriter.quietPeriod), now: now))
        XCTAssertTrue(HealthWriter.isQuiet(lastTried: now.addingTimeInterval(-3 * 24 * 60 * 60), now: now))
    }

    func testAnEntryWithNoTryOnRecordCanBeTakenOver() {
        XCTAssertTrue(HealthWriter.isQuiet(lastTried: nil, now: now))
    }

    func testAClockThatRunsFastDoesntMakeAWriterQuiet() {
        XCTAssertFalse(HealthWriter.isQuiet(lastTried: now.addingTimeInterval(60 * 60), now: now))
    }
}
