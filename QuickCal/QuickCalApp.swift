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
    var timer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "Loading..."
        
        requestCalendarAccess()
        startEventRefreshTimer()
    }
    
    func requestCalendarAccess() {
        let status = EKEventStore.authorizationStatus(for: .event)
        
        switch status {
        case .notDetermined:
            eventStore.requestAccess(to: .event) { granted, error in
                if granted {
                    DispatchQueue.main.async {
                        self.updateNextEvent()
                        self.startEventRefreshTimer()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.statusItem?.button?.title = "Access denied"
                    }
                }
            }
        case .authorized:
            updateNextEvent()
            startEventRefreshTimer()
        case .restricted, .denied:
            DispatchQueue.main.async {
                self.statusItem?.button?.title = "Enable access in system settings"
            }
        @unknown default:
            DispatchQueue.main.async {
                self.statusItem?.button?.title = "Access error"
            }
        }
    }
    
    func startEventRefreshTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            self.updateNextEvent()
        }
    }
    
    func updateNextEvent() {
        let calendars = eventStore.calendars(for: .event)
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now)!

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: calendars)
        let events = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        
        let pastEvents = events.filter { $0.endDate <= now }
        let upcomingEvents = events.filter { $0.endDate > now }
        
        DispatchQueue.main.async {
            if events.isEmpty {
                self.statusItem?.button?.title = "No events today"
            } else if upcomingEvents.isEmpty {
                self.statusItem?.button?.title = "All events done for today"
            } else {
                self.updateMenu(with: upcomingEvents)
                return
            }
            self.updateMenu(with: [])
        }
    }
    
    func updateMenu(with events: [EKEvent]) {
        let menu = NSMenu()
        
        if let nextEvent = events.first {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            
            let startTime = timeFormatter.string(from: nextEvent.startDate)
            let endTime = timeFormatter.string(from: nextEvent.endDate)
            let title = nextEvent.title ?? "No title"
            statusItem?.button?.title = "\(startTime) - \(endTime): \(title)"
        }
        
        for event in events {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            
            let startTime = timeFormatter.string(from: event.startDate)
            let title = event.title ?? "No title"
            let location = event.location ?? "No location"
            let menuItem = NSMenuItem(title: "\(startTime): \(title) @ \(location)", action: nil, keyEquivalent: "")
            menu.addItem(menuItem)
        }
        
        if events.isEmpty {
            menu.addItem(NSMenuItem(title: "No events", action: nil, keyEquivalent: ""))
        }
        
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }
}
