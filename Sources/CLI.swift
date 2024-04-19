import ArgumentParser
import EventKit
import SwiftyChrono

@main
struct CLI: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "eventkitcli",
        abstract: "A CLI to EventKit Framework",
        subcommands: [Setup.self, AddEvent.self, GetEvents.self, ParseDate.self])

    enum Err: Error {
        typealias RawValue = String
        case NoPermission
        case UnsupportedDateFormat(String)
        case FailedToSave(Error)
    }
}

struct Setup: AsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Setup CLI")
    func run() async throws {
        let store = EKEventStore()
        
        let granted = if #available(macOS 14.0, *) {
            try await store.requestFullAccessToEvents()
        } else {
            try await store.requestAccess(to: .event)
        }
        if granted {
            print("Permissions are granted")
        } else {
            throw CLI.Err.NoPermission
        }
    }
}

struct AddEvent: AsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Add a new event")
    
    @Option(help: "Title of event")
    var title: String
    
    @Option(help: "The start date as date string")
    var startDate: String
    
    @Option(help: "The end date as date string")
    var endDate: String
    
    func run() async throws {
        let chrono = Chrono()
        let now = Date()
        guard let startDate = chrono.parseDate(text: startDate, refDate: now) else {
            throw CLI.Err.UnsupportedDateFormat(startDate)
        }
        guard let endDate = chrono.parseDate(text: endDate, refDate: now) else {
            throw CLI.Err.UnsupportedDateFormat(endDate)
        }

        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = title
        event.calendar = store.defaultCalendarForNewEvents
        event.startDate = startDate
        event.endDate = endDate
        
        do {
            try store.save(event, span: .thisEvent, commit: true)
        } catch let e {
            print("Failed to add event - title: \"\(title)\", startDate: (\(startDate.asDateTimeString())), endDate: (\(endDate.asDateTimeString()))")
            throw CLI.Err.FailedToSave(e)
        }
        
        print("Added event - title: \"\(title)\", startDate: (\(startDate.asDateTimeString())), endDate: (\(endDate.asDateTimeString()))")
    }
}

struct GetEvents: AsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Get events in range")

    @Option(help: "Start date for search range")
    var startDate: String

    @Option(help: "The end date for search range")
    var endDate: String

    @Flag(help: "Whether or not to skip all-day events in results")
    var excludeAllDay: Bool = false

    func run() async throws {
        let chrono = Chrono()
        let now = Date()
        guard let startDate = chrono.parseDate(text: startDate, refDate: now) else {
            throw CLI.Err.UnsupportedDateFormat(startDate)
        }
        guard let endDate = chrono.parseDate(text: endDate, refDate: now) else {
            throw CLI.Err.UnsupportedDateFormat(endDate)
        }

        let store = EKEventStore()
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = store.events(matching: predicate)

        for e in events {
            if e.isAllDay && excludeAllDay {
                continue
            }
            print("\(businessFormat(e))")
        }
    }

    func businessFormat(_ event: EKEvent) -> String {
        let time = if event.isAllDay {
            "isAllDay: true, startDate: \(event.startDate.asDateString()), endDate: \(event.endDate.asDateString())"
        } else {
            "startDate: \(event.startDate.asDateTimeString()), endDate: \(event.endDate.asDateTimeString())"
        }
        return "title: \"\(event.title ?? "NO TITLE")\", \(time)"
    }
}

struct ParseDate: AsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Parse a string into date")

    @Argument(help: "The date expression to parse")
    var date: String

    func run() async throws {
        let chrono = Chrono()
        let now = Date()
        guard let date = chrono.parseDate(text: date, refDate: now) else {
            throw CLI.Err.UnsupportedDateFormat(date)
        }
        print(date.asDateTimeString())
    }

}
