import ArgumentParser
import EventKit
import SwiftyChrono

@main
struct CLI: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "eventkitcli",
        abstract: "A CLI to EventKit Framework",
        subcommands: [
            Setup.self,
            Events.self,
            Calendars.self,
            Utils.self,
        ])

    enum Err: Error {
        typealias RawValue = String
        case NoPermission
        case UnsupportedDateFormat(String)
        case FailedToSave(Error)
        case NoCalendarsFound
        case UnrecognizedIdentifier(String)
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

struct Utils: AsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "A CLI to EventKit Framework",
                                                    subcommands: [ParseDate.self])
}

struct ParseDate: AsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Parse a string into date")

    @Argument(help: "The date expression to parse")
    var date: String

    @Option(name: [.customLong("refdate")], help: "The relative date to use. Defaults to current date")
    var refDateString: String?

    func run() async throws {
        let chrono = Chrono()

        var refDate: Date
        if let refDateString {
            guard let refDateParsed = chrono.parseDate(text: refDateString, refDate: Date()) else {
                throw CLI.Err.UnsupportedDateFormat(date)
            }
            refDate = refDateParsed
        } else {
            refDate = Date() // default to now
        }

        guard let date = chrono.parseDate(text: date, refDate: refDate) else {
            throw CLI.Err.UnsupportedDateFormat(date)
        }
        print(date.asDateTimeString())
    }

}
