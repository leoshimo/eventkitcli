import ArgumentParser
import EventKit
import SwiftyChrono

@main
struct CLI: AsyncParsableCommand {
    @OptionGroup var output: OutputOptions
    static var configuration = CommandConfiguration(
        commandName: "eventkitcli",
        abstract: "A CLI to EventKit Framework",
        version: "0.1.0",
        subcommands: [
            Setup.self,
            Events.self,
            Calendars.self,
            Utils.self,
        ])

    enum Err: Error, CustomStringConvertible {
        typealias RawValue = String
        case NoPermission
        case UnsupportedDateFormat(String)
        case FailedToSave(Error)
        case NoCalendarsFound
        case UnrecognizedIdentifier(String)

        var description: String {
            switch self {
            case .NoPermission: return "Calendar full access is required. Run 'eventkitcli setup'; if denied, enable Calendar access in System Settings > Privacy & Security > Calendars."
            case .UnsupportedDateFormat(let text): return "Cannot parse date: \(text)"
            case .FailedToSave(let error): return "Could not save event: \(error.localizedDescription)"
            case .NoCalendarsFound: return "No calendars found."
            case .UnrecognizedIdentifier(let id): return "Unknown calendar identifier: \(id)"
            }
        }
    }
}

struct Setup: AsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Setup CLI")
    @OptionGroup var output: OutputOptions
    
    func run() async throws {
        let store = EKEventStore()
        
        let granted = if #available(macOS 14.0, *) {
            try await store.requestFullAccessToEvents()
        } else {
            try await store.requestAccess(to: .event)
        }
        if granted {
            if output.selectedFormat == .json {
                try printJSON(["granted": true])
            } else {
                print("Permissions are granted")
            }
        } else {
            throw CLI.Err.NoPermission
        }
    }
}

struct Utils: AsyncParsableCommand {
    @OptionGroup var output: OutputOptions
    static var configuration = CommandConfiguration(abstract: "A CLI to EventKit Framework",
                                                    subcommands: [ParseDate.self])
}

struct ParseDate: AsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Parse a string into date")
    @OptionGroup var output: OutputOptions

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
        if output.selectedFormat == .json {
            try printJSON(["date": EventDates.iso(date)])
        } else {
            print(date.asDateTimeString())
        }
    }

}
