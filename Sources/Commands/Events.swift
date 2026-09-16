import ArgumentParser
import EventKit

struct Events: AsyncParsableCommand {
    @OptionGroup var output: OutputOptions
    static var configuration = CommandConfiguration(
        commandName: "events", abstract: "Event commands",
        subcommands: [GetEvents.self, CreateEvent.self, EditEvent.self],
        defaultSubcommand: GetEvents.self)
}

struct GetEvents: AsyncParsableCommand {
    static var configuration = CommandConfiguration(commandName: "get", abstract: "Get events in range")

    @Option(name: .shortAndLong, help: "The start date for search range")
    var startDate: String
    @Option(name: .shortAndLong, help: "The end date for search range (exclusive)")
    var endDate: String
    @Flag(help: "Whether or not to skip all-day events in results")
    var excludeAllDay = false
    @Option(name: [.customLong("calendar"), .short], help: "Calendar ID. Repeat to specify multiple. Omit to search all calendars.")
    var calendarIds: [String] = []
    @OptionGroup var output: OutputOptions

    func run() async throws {
        let now = Date()
        let start = try EventDates.parse(startDate, now: now)
        let end = try EventDates.parse(endDate, now: now)
        try EventDates.validate(start: start, end: end)
        guard end <= Calendar.current.date(byAdding: .year, value: 4, to: start)! else {
            throw ValidationError("Search ranges cannot exceed four years (EventKit's limit).")
        }
        let store = try authorizedStore()
        let calendars: [EKCalendar]? = try calendarIds.isEmpty ? nil : calendarIds.map { id in
            guard let calendar = store.calendar(withIdentifier: id) else {
                throw CLI.Err.UnrecognizedIdentifier(id)
            }
            return calendar
        }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let events = store.events(matching: predicate)
            .filter { !excludeAllDay || !$0.isAllDay }
            .sorted { ($0.startDate, $0.eventIdentifier ?? "") < ($1.startDate, $1.eventIdentifier ?? "") }
        switch output.selectedFormat {
        case .json: try printJSON(events.map(EventRecord.init))
        case .id: events.forEach { print($0.eventIdentifier ?? "") }
        case .human: events.forEach { print(businessFormat($0)) }
        }
    }

    func businessFormat(_ event: EKEvent) -> String {
        let time = if event.isAllDay {
            "isAllDay: true, startDate: \(event.startDate.asDateString()), endDate: \(event.exclusiveEndDate.asDateString())"
        } else {
            "startDate: \(event.startDate.asDateTimeString()), endDate: \(event.endDate.asDateTimeString())"
        }
        return "title: \"\(event.title ?? "NO TITLE")\", \(time)"
    }
}

struct CreateEvent: AsyncParsableCommand {
    static var configuration = CommandConfiguration(commandName: "create", abstract: "Create a calendar event")

    @Option(name: .shortAndLong, help: "Title of event")
    var title: String
    @Option(name: .shortAndLong, help: "Start date (natural language, YYYY-MM-DD, or ISO 8601)")
    var startDate: String
    @Option(name: .shortAndLong, help: "End date; exclusive for all-day events")
    var endDate: String
    @Option(name: [.customLong("calendar"), .short], help: "Calendar ID. Omit for default calendar.")
    var calendarId: String?
    @Flag(help: "Create an all-day event; dates use local midnight boundaries")
    var allDay = false
    @OptionGroup var output: OutputOptions

    func run() async throws {
        try validateTitle(title)
        let now = Date()
        let (start, end) = try EventDates.bounds(
            start: EventDates.parse(startDate, now: now), end: EventDates.parse(endDate, now: now), allDay: allDay)
        let store = try authorizedStore()
        let event = EKEvent(eventStore: store)
        event.calendar = try writableCalendar(calendarId, store: store)
        event.title = title
        event.isAllDay = allDay
        event.startDate = start
        event.endDate = EventDates.storedEnd(end, allDay: allDay)
        do { try store.save(event, span: .thisEvent, commit: true) }
        catch { throw CLI.Err.FailedToSave(error) }
        try printSaved(event, action: "Added", format: output.selectedFormat)
    }
}

struct EditEvent: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "edit", abstract: "Edit selected fields of an event",
        discussion: "Omitted fields stay unchanged. For repeating events, pass --occurrence using the exact 'occurrence' value from events get --format json. Only that occurrence is changed; series-wide editing is not supported. All-day end dates are exclusive. Changing between all-day and timed requires both dates.")

    @Argument(help: "EventKit event ID from events get --format json")
    var id: String
    @Option(name: .shortAndLong, help: "New title")
    var title: String?
    @Option(name: .shortAndLong, help: "New start date (natural language, YYYY-MM-DD, or ISO 8601)")
    var startDate: String?
    @Option(name: .shortAndLong, help: "New end date; exclusive for all-day events")
    var endDate: String?
    @Option(name: [.customLong("calendar"), .short], help: "Destination calendar ID")
    var calendarId: String?
    @Flag(help: "Make the event all-day")
    var allDay = false
    @Flag(help: "Make the event timed")
    var timed = false
    @Option(help: "Exact current start of a repeating occurrence, as ISO 8601 from JSON discovery")
    var occurrence: String?
    @OptionGroup var output: OutputOptions

    func validate() throws {
        guard title != nil || startDate != nil || endDate != nil || calendarId != nil || allDay || timed else {
            throw ValidationError("Specify at least one field to edit.")
        }
        guard !(allDay && timed) else { throw ValidationError("Use only one of --all-day and --timed.") }
        if let title { try validateTitle(title) }
        if let occurrence, EventDates.parseISO(occurrence) == nil {
            throw ValidationError("--occurrence must be an ISO 8601 timestamp from events get --format json.")
        }
    }

    func run() async throws {
        let now = Date()
        let newStart = try startDate.map { try EventDates.parse($0, now: now) }
        let newEnd = try endDate.map { try EventDates.parse($0, now: now) }
        if let newStart, let newEnd { try EventDates.validate(start: newStart, end: newEnd) }
        let store = try authorizedStore()
        let event = try findEvent(store: store)
        guard event.calendar.allowsContentModifications else {
            throw ValidationError("Event's calendar is read-only: \(event.calendar.title)")
        }
        let targetCalendar = try calendarId.map { try writableCalendar($0, store: store) }
        let targetAllDay = allDay ? true : (timed ? false : event.isAllDay)
        if targetAllDay != event.isAllDay && (newStart == nil || newEnd == nil) {
            throw ValidationError("Changing between all-day and timed requires --start-date and --end-date.")
        }
        let (start, end) = try EventDates.bounds(
            start: newStart ?? event.startDate, end: newEnd ?? event.exclusiveEndDate,
            allDay: targetAllDay)
        // Apply only after all validation succeeds, then save exactly one event/occurrence.
        if let title { event.title = title }
        if let targetCalendar { event.calendar = targetCalendar }
        if allDay || timed { event.isAllDay = targetAllDay }
        if newStart != nil { event.startDate = start }
        if newEnd != nil { event.endDate = EventDates.storedEnd(end, allDay: targetAllDay) }
        do { try store.save(event, span: .thisEvent, commit: true) }
        catch { throw CLI.Err.FailedToSave(error) }
        try printSaved(event, action: "Updated", format: output.selectedFormat)
    }

    func findEvent(store: EKEventStore) throws -> EKEvent {
        if let occurrence, let date = EventDates.parseISO(occurrence) {
            let predicate = store.predicateForEvents(
                withStart: date.addingTimeInterval(-1), end: date.addingTimeInterval(1), calendars: nil)
            let matches = store.events(matching: predicate).filter {
                $0.eventIdentifier == id && abs($0.startDate.timeIntervalSince(date)) < 0.001
            }
            guard matches.count == 1 else {
                throw ValidationError("No unique event matches that ID and occurrence. Refresh events get --format json; nothing was changed.")
            }
            return matches[0]
        }
        guard let event = store.event(withIdentifier: id) else {
            throw ValidationError("Event ID not found. Refresh events get --format json; nothing was changed.")
        }
        guard !event.isRepeatingOccurrence else {
            throw ValidationError("Repeating events require --occurrence from events get --format json. Only that occurrence will change; series editing is not supported.")
        }
        return event
    }
}
