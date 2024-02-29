import ArgumentParser
import EventKit
import SwiftyChrono

@main
struct CLI: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "A CLI to EventKit Framework",
        subcommands: [Setup.self, AddEvent.self])
    
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
        let granted = try await store.requestAccess(to: .event)
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
        guard let startDate = chrono.parseDate(text: startDate, refDate: Date()) else {
            throw CLI.Err.UnsupportedDateFormat(startDate)
        }
        guard let endDate = chrono.parseDate(text: endDate, refDate: startDate) else {
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
            print("Failed to add event - title: \(title), startDate: (\(startDate.stringForDisplay())), endDate: (\(endDate.stringForDisplay()))")
            throw CLI.Err.FailedToSave(e)
        }
        
        print("Added event - title: \(title), startDate: (\(startDate.stringForDisplay())), endDate: (\(endDate.stringForDisplay()))")
    }
}
