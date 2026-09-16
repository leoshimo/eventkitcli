import ArgumentParser
import EventKit
import SwiftyChrono

enum EventFormat: String, ExpressibleByArgument, CaseIterable {
    case human, json, id
}

struct OutputOptions: ParsableArguments {
    @Flag(help: "Write one JSON value to stdout")
    var json = false

    @Option(name: .shortAndLong, help: "Output format: human, json, or id (default: human)")
    var format: EventFormat?

    var selectedFormat: EventFormat { json ? .json : (format ?? .human) }

    func validate() throws {
        if json, let format, format != .json {
            throw ValidationError("--json cannot be combined with --format \(format.rawValue).")
        }
    }
}

enum EventDates {
    static func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    static func parseISO(_ text: String) -> Date? {
        let pattern = #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,3})?(Z|[+-]\d{2}:\d{2})$"#
        guard text.range(of: pattern, options: .regularExpression) != nil else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.isLenient = false
        formatter.dateFormat = text.contains(".") ? "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX" : "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        return formatter.date(from: text)
    }

    static func parse(_ text: String, now: Date) throws -> Date {
        if let date = parseISO(text) { return date }
        if text.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.isLenient = false
            if let date = formatter.date(from: text), formatter.string(from: date) == text { return date }
            throw CLI.Err.UnsupportedDateFormat(text)
        }
        // Do not let the natural-language parser salvage a malformed ISO timestamp.
        if text.range(of: #"^\d{4}-\d{2}-\d{2}T"#, options: .regularExpression) != nil {
            throw CLI.Err.UnsupportedDateFormat(text)
        }
        guard let date = Chrono().parseDate(text: text, refDate: now) else {
            throw CLI.Err.UnsupportedDateFormat(text)
        }
        return date
    }

    static func validate(start: Date, end: Date) throws {
        guard end > start else { throw ValidationError("End date must be after start date.") }
    }

    static func bounds(start: Date, end: Date, allDay: Bool, timeZone: TimeZone = .current) throws -> (Date, Date) {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let start = allDay ? calendar.startOfDay(for: start) : start
        let end = allDay ? calendar.startOfDay(for: end) : end
        try validate(start: start, end: end)
        return (start, end)
    }

    // macOS EventKit stores all-day ends as the last second of the final day.
    // Keep the CLI's input/output contract consistently exclusive.
    static func storedEnd(_ exclusiveEnd: Date, allDay: Bool) -> Date {
        allDay ? exclusiveEnd.addingTimeInterval(-1) : exclusiveEnd
    }

    static func exclusiveEnd(_ storedEnd: Date, allDay: Bool) -> Date {
        guard allDay else { return storedEnd }
        let midnight = Calendar.current.startOfDay(for: storedEnd)
        if storedEnd == midnight { return storedEnd }
        return Calendar.current.date(byAdding: .day, value: 1, to: midnight)!
    }
}

func authorizedStore() throws -> EKEventStore {
    let status = EKEventStore.authorizationStatus(for: .event)
    if #available(macOS 14.0, *) {
        guard status == .fullAccess else { throw CLI.Err.NoPermission }
    } else {
        guard status == .authorized else { throw CLI.Err.NoPermission }
    }
    return EKEventStore()
}

func writableCalendar(_ id: String?, store: EKEventStore) throws -> EKCalendar {
    let calendar: EKCalendar?
    if let id {
        guard let found = store.calendar(withIdentifier: id), found.allowedEntityTypes.contains(.event) else {
            throw CLI.Err.UnrecognizedIdentifier(id)
        }
        calendar = found
    } else {
        calendar = store.defaultCalendarForNewEvents
    }
    guard let calendar else { throw ValidationError("No default calendar. Select one with --calendar.") }
    guard calendar.allowsContentModifications else { throw ValidationError("Calendar is read-only: \(calendar.title)") }
    return calendar
}

func validateTitle(_ title: String) throws {
    guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw ValidationError("Title must not be empty.")
    }
}

extension EKEvent {
    var isRepeatingOccurrence: Bool { hasRecurrenceRules || isDetached }
    var exclusiveEndDate: Date { EventDates.exclusiveEnd(endDate, allDay: isAllDay) }
}

struct EventRecord: Encodable {
    let id: String
    let title: String
    let startDate: String
    let endDate: String
    let isAllDay: Bool
    let calendarId: String
    let calendarTitle: String
    let isRecurring: Bool
    let isDetached: Bool
    /// Current start, used to select exactly one occurrence (including moved exceptions).
    let occurrence: String?
    let originalOccurrenceDate: String?
    let timeZone: String?

    init(_ event: EKEvent) {
        id = event.eventIdentifier
        title = event.title ?? ""
        startDate = EventDates.iso(event.startDate)
        endDate = EventDates.iso(event.exclusiveEndDate)
        isAllDay = event.isAllDay
        calendarId = event.calendar.calendarIdentifier
        calendarTitle = event.calendar.title
        isRecurring = event.isRepeatingOccurrence
        isDetached = event.isDetached
        occurrence = isRecurring ? startDate : nil
        originalOccurrenceDate = isRecurring ? event.occurrenceDate.map(EventDates.iso) : nil
        timeZone = event.timeZone?.identifier
    }
}

func printJSON<T: Encodable>(_ value: T) throws {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    print(String(decoding: try encoder.encode(value), as: UTF8.self))
}

func printSaved(_ event: EKEvent, action: String, format: EventFormat) throws {
    switch format {
    case .json: try printJSON(EventRecord(event))
    case .id: print(event.eventIdentifier ?? "")
    case .human:
        print("\(action) event - id: \(event.eventIdentifier ?? ""), title: \"\(event.title ?? "")\", startDate: \(EventDates.iso(event.startDate)), endDate: \(EventDates.iso(event.exclusiveEndDate)), isAllDay: \(event.isAllDay)")
    }
}
