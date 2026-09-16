import XCTest
import ArgumentParser
@testable import eventkitcli

final class EventTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testISOOutputRoundTripsExactly() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000.125)
        XCTAssertEqual(try XCTUnwrap(EventDates.parseISO(EventDates.iso(date))), date)
        XCTAssertEqual(try EventDates.parse("2026-09-16T10:00:00-07:00", now: now),
                       EventDates.parseISO("2026-09-16T17:00:00Z"))
    }

    func testDateOnlyIsLocalMidnight() throws {
        let date = try EventDates.parse("2026-09-16", now: now)
        XCTAssertEqual(Calendar.current.component(.hour, from: date), 0)
        XCTAssertEqual(Calendar.current.component(.day, from: date), 16)
    }

    func testInvalidDatesFailInsteadOfBeingPartiallyParsed() {
        for text in ["2026-02-30", "2026-09-16Tgarbage", "2026-02-30T09:00:00Z", "2026-09-16T25:00:00Z", "not-a-date"] {
            XCTAssertThrowsError(try EventDates.parse(text, now: now), text)
        }
    }

    func testNaturalLanguageStillWorks() throws {
        let date = try EventDates.parse("in one hour", now: now)
        XCTAssertEqual(date.timeIntervalSince(now), 3600, accuracy: 1)
    }

    func testInvalidIntervalsFail() {
        XCTAssertThrowsError(try EventDates.validate(start: now, end: now))
        XCTAssertThrowsError(try EventDates.validate(start: now, end: now.addingTimeInterval(-1)))
    }

    func testAllDayUsesCalendarBoundariesAcrossDST() throws {
        let zone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let start = try XCTUnwrap(EventDates.parseISO("2026-03-08T12:00:00-07:00"))
        let end = try XCTUnwrap(EventDates.parseISO("2026-03-09T12:00:00-07:00"))
        let bounds = try EventDates.bounds(start: start, end: end, allDay: true, timeZone: zone)
        XCTAssertEqual(bounds.1.timeIntervalSince(bounds.0), 23 * 3600)
        XCTAssertThrowsError(try EventDates.bounds(start: start, end: start.addingTimeInterval(3600), allDay: true, timeZone: zone))
    }

    func testEditRequiresFieldsAndRejectsContradictoryFlags() {
        XCTAssertThrowsError(try EditEvent.parse(["example-id"]))
        XCTAssertThrowsError(try EditEvent.parse(["example-id", "--all-day", "--timed"]))
        XCTAssertThrowsError(try EditEvent.parse(["example-id", "--title", "  "]))
        XCTAssertThrowsError(try EditEvent.parse(["example-id", "--title", "Hello", "--occurrence", "tomorrow"]))
        XCTAssertThrowsError(try EditEvent.parse(["example-id", "--title", "Hello", "--span", "future-events"]))
    }

    func testEditLeavesOmittedFieldsUnset() throws {
        let edit = try EditEvent.parse(["example-id", "--title", "New title", "--format", "json"])
        XCTAssertEqual(edit.title, "New title")
        XCTAssertNil(edit.startDate)
        XCTAssertNil(edit.endDate)
        XCTAssertNil(edit.calendarId)
        XCTAssertFalse(edit.allDay)
        XCTAssertFalse(edit.timed)
    }

    func testOccurrenceAcceptsDiscoveryTimestamp() throws {
        let edit = try EditEvent.parse(["example-id", "--title", "New title", "--occurrence", "2026-09-16T17:00:00.000Z"])
        XCTAssertEqual(edit.occurrence, "2026-09-16T17:00:00.000Z")
    }

    func testJSONWorksBeforeAndAfterSubcommands() throws {
        for arguments in [
            ["--json", "events", "edit", "example-id", "--title", "New title"],
            ["events", "--json", "edit", "example-id", "--title", "New title"],
            ["events", "edit", "example-id", "--title", "New title", "--json"],
            ["events", "edit", "example-id", "--title", "New title", "--format", "json"]
        ] {
            let edit = try XCTUnwrap(CLI.parseAsRoot(arguments) as? EditEvent)
            XCTAssertEqual(edit.output.selectedFormat, .json)
        }
        XCTAssertThrowsError(try CLI.parseAsRoot(["--json", "events", "edit", "example-id", "--title", "Hello", "--format", "id"]))
        let calendars = try XCTUnwrap(CLI.parseAsRoot(["--json", "cal"]) as? Calendars.Get)
        XCTAssertEqual(calendars.output.selectedFormat, .json)
    }
}
