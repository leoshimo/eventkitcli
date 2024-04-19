//
//  Events.swift
//  Subcommands for Events
//
//  Created by Leo Shimonaka on 4/18/24.
//
import ArgumentParser
import EventKit
import SwiftyChrono

struct Events: AsyncParsableCommand {
    static var configuration = CommandConfiguration(commandName: "events",
                                                    abstract: "Event commands",
                                                    subcommands: [
                                                        GetEvents.self,
                                                        CreateEvent.self,
                                                    ],
                                                    defaultSubcommand: GetEvents.self)
}

struct GetEvents: AsyncParsableCommand {
    static var configuration = CommandConfiguration(commandName: "get",
                                                    abstract: "Get events in range")

    @Option(name: .shortAndLong, help: "The start date for search range")
    var startDate: String

    @Option(name: .shortAndLong, help: "The end date for search range")
    var endDate: String

    @Flag(help: "Whether or not to skip all-day events in results")
    var excludeAllDay: Bool = false
    
    @Option(name: [.customLong("calendar"), .short], help: "The calendar to from. Repeat to specify multiple. If omitted, searches all calendars.")
    var calendarIds: [String] = []

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
        
        let calendars: [EKCalendar]?
        if !calendarIds.isEmpty {
            calendars = try calendarIds.map({ id in
                guard let calendar = store.calendar(withIdentifier: id) else {
                    throw CLI.Err.UnrecognizedIdentifier(id)
                }
                return calendar
            })
        } else {
            calendars = nil
        }
        
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
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

struct CreateEvent: AsyncParsableCommand {
    static var configuration = CommandConfiguration(commandName: "create",
                                                    abstract: "Creates a new calendar event")
    
    @Option(name: .shortAndLong, help: "Title of event")
    var title: String
    
    @Option(name: .shortAndLong, help: "The start date for search range")
    var startDate: String

    @Option(name: .shortAndLong, help: "The end date for search range")
    var endDate: String

    @Option(name: [.customLong("calendar"), .short], help: "The calendar new event will be created in. Omit for default calendar")
    var calendarId: String?
    
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
        
        let calendar: EKCalendar?
        if let calendarId {
            guard let specifiedCalendar = store.calendar(withIdentifier: calendarId) else {
                throw CLI.Err.UnrecognizedIdentifier(calendarId)
            }
            calendar = specifiedCalendar
        } else {
            calendar = store.defaultCalendarForNewEvents
        }
        
        event.title = title
        event.calendar = calendar
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

