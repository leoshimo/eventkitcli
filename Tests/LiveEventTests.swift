import XCTest
import EventKit
@testable import eventkitcli

/// Opt-in only. Writes touch only uniquely marked events created by this test.
final class LiveEventTests: XCTestCase {
    func testDisposableEvents() throws {
        guard ProcessInfo.processInfo.environment["EVENTKITCLI_LIVE_TESTS"] == "1" else {
            throw XCTSkip("Run scripts/test-live.sh to exercise disposable calendar events.")
        }
        let store = try authorizedStore()
        let executable = try XCTUnwrap(ProcessInfo.processInfo.environment["EVENTKITCLI_BINARY"])
        let token = "eventkitcli-test-" + UUID().uuidString
        let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(3 * 86400 + 12 * 3600)
        let end = start.addingTimeInterval(3600)
        let writable = store.calendars(for: .event).filter(\.allowsContentModifications)
        let firstCalendar = try XCTUnwrap(writable.first, "No writable calendar for disposable events")
        let secondCalendar = writable.dropFirst().first ?? firstCalendar
        let calendarIDs = [firstCalendar.calendarIdentifier, secondCalendar.calendarIdentifier]
        if calendarIDs[0] == calendarIDs[1] {
            print("Only one writable calendar; testing explicit calendar assignment, not a cross-calendar move.")
        }
        func remainingFixtures() -> [EKEvent] {
            store.reset()
            let calendars = Set(calendarIDs).compactMap { store.calendar(withIdentifier: $0) }
            let predicate = store.predicateForEvents(withStart: start.addingTimeInterval(-86400),
                                                    end: start.addingTimeInterval(7 * 86400), calendars: calendars)
            return store.events(matching: predicate).filter { $0.title?.contains(token) == true }
                .sorted { $0.startDate < $1.startDate }
        }
        defer {
            // The random marker is retained in every test title, even negative tests.
            // Never remove calendars or events that existed before this test.
            for _ in 0..<10 {
                guard let event = remainingFixtures().first else { break }
                do { try store.remove(event, span: event.isRepeatingOccurrence ? .futureEvents : .thisEvent, commit: true) }
                catch { XCTFail("Cleanup failed for \(token): \(error)"); break }
            }
            XCTAssertTrue(remainingFixtures().isEmpty, "Disposable events remain for \(token)")
            print("Verified disposable event cleanup for \(token)")
        }
        func run(_ args: [String], fails: Bool = false) throws -> Data {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = args
            let out = Pipe(), err = Pipe()
            process.standardOutput = out
            process.standardError = err
            try process.run()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            let error = err.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            if fails {
                XCTAssertNotEqual(process.terminationStatus, 0)
                XCTAssertFalse(error.isEmpty)
                XCTAssertTrue(data.isEmpty)
            } else {
                guard process.terminationStatus == 0 else {
                    XCTFail(String(decoding: error, as: UTF8.self))
                    throw NSError(domain: "LiveTestCommand", code: Int(process.terminationStatus))
                }
            }
            return data
        }
        func object(_ args: [String]) throws -> [String: Any] {
            try XCTUnwrap(JSONSerialization.jsonObject(with: run(["--json"] + args)) as? [String: Any])
        }
        func fetch(_ id: String) throws -> EKEvent {
            store.reset()
            return try XCTUnwrap(store.event(withIdentifier: id))
        }
        let created = try object(["events", "create", "--title", token, "--calendar", calendarIDs[0],
                                  "--start-date", EventDates.iso(start), "--end-date", EventDates.iso(end)])
        var id = try XCTUnwrap(created["id"] as? String)
        XCTAssertEqual(created["start_date"] as? String, EventDates.iso(start))
        XCTAssertEqual(created["calendar_id"] as? String, calendarIDs[0])
        XCTAssertEqual(created["is_all_day"] as? Bool, false)
        XCTAssertNil(created["startDate"])
        let fixture = try fetch(id)
        fixture.notes = "Preserve this note"
        fixture.location = "Disposable location"
        fixture.timeZone = TimeZone(identifier: "Asia/Tokyo")
        fixture.addAlarm(EKAlarm(relativeOffset: -600))
        try store.save(fixture, span: .thisEvent)
        _ = try object(["events", "edit", id, "--title", "Edited \(token)"])
        let renamed = try fetch(id)
        XCTAssertEqual(renamed.title, "Edited \(token)")
        XCTAssertEqual(renamed.startDate, start)
        XCTAssertEqual(renamed.endDate, end)
        XCTAssertEqual(renamed.notes, "Preserve this note")
        XCTAssertEqual(renamed.location, "Disposable location")
        XCTAssertEqual(renamed.timeZone?.identifier, "Asia/Tokyo")
        XCTAssertEqual(renamed.alarms?.first?.relativeOffset, -600)
        _ = try run(["events", "edit", id, "--start-date", EventDates.iso(end.addingTimeInterval(1))], fails: true)
        _ = try run(["events", "edit", id, "--calendar", "missing-\(token)"], fails: true)
        _ = try run(["events", "edit", "missing-\(token)", "--title", "No change \(token)"], fails: true)
        _ = try run(["events", "edit", id, "--all-day"], fails: true)
        XCTAssertEqual(try fetch(id).startDate, start)
        let moved = try object(["events", "edit", id, "--calendar", calendarIDs[1], "--start-date", EventDates.iso(start.addingTimeInterval(7200)), "--end-date", EventDates.iso(end.addingTimeInterval(7200))])
        id = try XCTUnwrap(moved["id"] as? String)
        XCTAssertEqual(try fetch(id).calendar.calendarIdentifier, calendarIDs[1])
        let allDay = try object(["events", "edit", id, "--all-day", "--start-date", EventDates.iso(start), "--end-date", EventDates.iso(start.addingTimeInterval(86400))])
        XCTAssertTrue(try fetch(id).isAllDay)
        XCTAssertEqual(try fetch(id).startDate, Calendar.current.startOfDay(for: start))
        let exclusiveEnd = Calendar.current.startOfDay(for: start.addingTimeInterval(86400))
        XCTAssertEqual(try fetch(id).endDate, exclusiveEnd.addingTimeInterval(-1))
        XCTAssertEqual(allDay["end_date"] as? String, EventDates.iso(exclusiveEnd))
        let renamedAllDay = try object(["events", "edit", id, "--title", "All day renamed \(token)"])
        XCTAssertEqual(renamedAllDay["end_date"] as? String, EventDates.iso(exclusiveEnd))
        _ = try object(["events", "edit", id, "--timed", "--start-date", EventDates.iso(start), "--end-date", EventDates.iso(end)])
        XCTAssertFalse(try fetch(id).isAllDay)

        let createdAllDay = try object(["events", "create", "--calendar", calendarIDs[0], "--title", "All day created \(token)", "--all-day", "--start-date", EventDates.iso(start), "--end-date", EventDates.iso(exclusiveEnd)])
        let allDayID = try XCTUnwrap(createdAllDay["id"] as? String)
        XCTAssertEqual(try fetch(allDayID).endDate, exclusiveEnd.addingTimeInterval(-1))
        XCTAssertEqual(createdAllDay["end_date"] as? String, EventDates.iso(exclusiveEnd))

        let recurring = EKEvent(eventStore: store)
        recurring.calendar = try XCTUnwrap(store.calendar(withIdentifier: calendarIDs[0]))
        recurring.title = "Recurring \(token)"
        recurring.startDate = start
        recurring.endDate = end
        recurring.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: EKRecurrenceEnd(occurrenceCount: 3)))
        try store.save(recurring, span: .thisEvent)
        let query = ["events", "get", "--calendar", calendarIDs[0], "--start-date", EventDates.iso(start.addingTimeInterval(-3600)), "--end-date", EventDates.iso(start.addingTimeInterval(4 * 86400)), "--format", "json"]
        func occurrences() throws -> [[String: Any]] {
            let records = try XCTUnwrap(JSONSerialization.jsonObject(with: run(query)) as? [[String: Any]])
            return records.filter { ($0["title"] as? String)?.contains(token) == true && $0["is_recurring"] as? Bool == true }
        }
        let before = try occurrences()
        XCTAssertEqual(before.count, 3)
        let selected = try XCTUnwrap(before.dropFirst().first)
        let recurringID = try XCTUnwrap(selected["id"] as? String)
        let occurrence = try XCTUnwrap(selected["occurrence"] as? String)
        _ = try run(["events", "edit", recurringID, "--title", "Refuse ambiguous series \(token)"], fails: true)
        _ = try run(["events", "edit", recurringID, "--occurrence", EventDates.iso(start.addingTimeInterval(86400 + 60)), "--title", "Refuse stale selector \(token)"], fails: true)
        let occurrenceStart = try XCTUnwrap(EventDates.parseISO(occurrence))
        let edited = try object(["events", "edit", recurringID, "--occurrence", occurrence, "--title", "Only second occurrence \(token)", "--start-date", EventDates.iso(occurrenceStart.addingTimeInterval(3600)), "--end-date", EventDates.iso(occurrenceStart.addingTimeInterval(7200))])
        let after = try occurrences()
        XCTAssertEqual(after.count, 3)
        guard after.count == 3 else { throw NSError(domain: "LiveTestRecurrenceCount", code: after.count) }
        XCTAssertEqual(after[0]["title"] as? String, "Recurring \(token)")
        XCTAssertEqual(after[1]["title"] as? String, "Only second occurrence \(token)")
        XCTAssertEqual(after[2]["title"] as? String, "Recurring \(token)")
        let detachedID = try XCTUnwrap(edited["id"] as? String)
        let detachedOccurrence = try XCTUnwrap(edited["occurrence"] as? String)
        _ = try run(["events", "edit", detachedID, "--title", "Refuse unspecified exception \(token)"], fails: true)
        _ = try object(["events", "edit", detachedID, "--occurrence", detachedOccurrence, "--title", "Edited moved exception \(token)"])
        XCTAssertEqual(try occurrences().dropFirst().first?["title"] as? String, "Edited moved exception \(token)")
        print("Live checks passed: create, title/time/calendar/all-day edits, preservation, failures, recurrence isolation, moved exception; disposable events will now be removed.")
    }
}
