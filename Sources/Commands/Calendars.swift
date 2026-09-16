//
//  Calendar.swift
//  Commands for Calendar
//
//  Created by Leo Shimonaka on 4/18/24.
//
import ArgumentParser
import EventKit

// TODO: Adopt subcommand aliases for shorthands https://github.com/apple/swift-argument-parser/issues/248
struct Calendars: AsyncParsableCommand {
    @OptionGroup var output: OutputOptions
    static var configuration = CommandConfiguration(commandName: "cal",
                                                    abstract: "Calendar commands",
                                                    subcommands: [
                                                        Get.self,
                                                    ],
                                                    defaultSubcommand: Get.self)
    
    struct Get: AsyncParsableCommand {
        static var configuration = CommandConfiguration(commandName: "get",
                                                        abstract: "Get calendars")
        
        @Flag(help: "Return the default calendar")
        var `default`: Bool = false
        
        @Option(name: .shortAndLong, help: "Return calendar with matching title")
        var title: String?
        
        @OptionGroup var output: OutputOptions
        
        func run() async throws {
            let store = try authorizedStore()
            
            let calendars: [EKCalendar] = if `default` {
                if let defaultCalendar = store.defaultCalendarForNewEvents {
                    [defaultCalendar]
                } else {
                    []
                }
            } else if let title {
                store.calendars(for: .event).filter { cal in cal.title == title }
            } else {
                store.calendars(for: .event)
            }
            
            if output.selectedFormat == .json {
                try printJSON(calendars.map { CalendarRecord(id: $0.calendarIdentifier, title: $0.title, allowsContentModifications: $0.allowsContentModifications) })
                return
            }
            if calendars.isEmpty {
                throw CLI.Err.NoCalendarsFound
            }
            for c in calendars {
                print(c.asString(in: output.selectedFormat))
            }
        }
        
    }
    
}

extension EKCalendar {
    func asString(in format: EventFormat) -> String {
        switch format {
        case .human:
            "\(calendarIdentifier) - \(title)"
        case .id:
            "\(calendarIdentifier)"
        case .json:
            "" // JSON arrays are encoded by the command.
        }
    }
}

struct CalendarRecord: Encodable {
    let id: String
    let title: String
    let allowsContentModifications: Bool
}
