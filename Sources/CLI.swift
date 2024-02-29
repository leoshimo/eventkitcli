import ArgumentParser
import EventKit

@main
struct CLI: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "A CLI to EventKit Framework",
        subcommands: [Setup.self, AddEvent.self])
    
    enum Err: Error {
        typealias RawValue = String
        case NoPermission
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
    
    func run() async throws {
        let store = EKEventStore()
        
        let event = EKEvent(eventStore: store)
        event.title = title
        event.calendar = store.defaultCalendarForNewEvents
        
        // TODO: Date Parsing
        event.startDate = Date()
        event.endDate = event.startDate.addingTimeInterval(3600)
        
        
        try store.save(event, span: .thisEvent, commit: true)
    }
}
