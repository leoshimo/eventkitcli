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
    static var configuration = CommandConfiguration(commandName: "cal",
                                                    abstract: "Calendar commands",
                                                    subcommands: [
                                                        Get.self,
                                                    ],
                                                    defaultSubcommand: Get.self)
    
    enum OutputFormat: String, ExpressibleByArgument, CaseIterable {
        case human, id
    }
    
    struct Get: AsyncParsableCommand {
        static var configuration = CommandConfiguration(commandName: "get",
                                                        abstract: "Get calendars")
        
        @Flag(help: "Return the default calendar")
        var `default`: Bool = false
        
        @Option(name: .shortAndLong, help: "Return calendar with matching title")
        var title: String?
        
        @Option(name: .shortAndLong, help: "Output format")
        var format: OutputFormat = .human
        
        func run() async throws {
            let store = EKEventStore()
            
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
            
            if calendars.isEmpty {
                throw CLI.Err.NoCalendarsFound
            }
            
            for c in calendars {
                print(c.asString(in: format))
            }
        }
        
    }
    
}

extension EKCalendar {
    func asString(in format: Calendars.OutputFormat) -> String {
        switch format {
        case .human:
            "\(calendarIdentifier) - \(title)"
        case .id:
            "\(calendarIdentifier)"
        }
    }
}
