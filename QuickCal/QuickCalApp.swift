//
//  QuickCalApp.swift
//  QuickCal
//
//  Created by Tord Johansson with the help of AI
//

import SwiftUI
import EventKit

@main
struct NextEventMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView() // No settings window required
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    let eventStore = EKEventStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "Loading..."

        // Request calendar access
        requestCalendarAccess()
    }

    func requestCalendarAccess() {
        // Check current authorization status
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .notDetermined:
            // Request access if the status is not determined
            eventStore.requestAccess(to: .event) { granted, error in
                if granted {
                    DispatchQueue.main.async {
                        self.updateNextEvent()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.statusItem?.button?.title = "Access Denied"
                    }
                }
            }
        case .authorized:
            // Already authorized
            updateNextEvent()
        case .restricted, .denied:
            // Restricted or denied access
            DispatchQueue.main.async {
                self.statusItem?.button?.title = "Enable Access in System Settings"
            }
        @unknown default:
            DispatchQueue.main.async {
                self.statusItem?.button?.title = "Access Error"
            }
        }
    }

    func updateNextEvent() {
        let calendars = eventStore.calendars(for: .event)
        let now = Date()
        let oneDayLater = Calendar.current.date(byAdding: .day, value: 1, to: now)!

        let predicate = eventStore.predicateForEvents(withStart: now, end: oneDayLater, calendars: calendars)
        let events = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        if let nextEvent = events.first {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short

            // Format start and end times
            let startTime = timeFormatter.string(from: nextEvent.startDate)
            let endTime = timeFormatter.string(from: nextEvent.endDate)

            // Truncate the title if it's too long
            let maxTitleLength = 20 // Set your desired maximum length
            let title = nextEvent.title ?? "No Title"
            let truncatedTitle = title.count > maxTitleLength ? String(title.prefix(maxTitleLength)) + "…" : title

            DispatchQueue.main.async {
                self.statusItem?.button?.title = "\(startTime) - \(endTime): \(truncatedTitle)"
            }
        } else {
            DispatchQueue.main.async {
                self.statusItem?.button?.title = "No Events Today"
            }
        }
    }
}
