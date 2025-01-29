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
                        self.statusItem?.button?.title = "Access Denied"
                    }
                }
            }
        case .authorized:
            updateNextEvent()
            startEventRefreshTimer()
        case .restricted, .denied:
            DispatchQueue.main.async {
                self.statusItem?.button?.title = "Enable Access in System Settings"
            }
        @unknown default:
            DispatchQueue.main.async {
                self.statusItem?.button?.title = "Access Error"
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
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now)!

        let predicate = eventStore.predicateForEvents(withStart: now, end: endOfDay, calendars: calendars)
        let events = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        DispatchQueue.main.async {
            self.updateMenu(with: events)
        }
    }
    
    func updateMenu(with events: [EKEvent]) {
        let menu = NSMenu()
        
        if let nextEvent = events.first {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            
            let startTime = timeFormatter.string(from: nextEvent.startDate)
            let endTime = timeFormatter.string(from: nextEvent.endDate)
            let title = nextEvent.title ?? "No Title"
            statusItem?.button?.title = "\(startTime) - \(endTime): \(title)"
        } else {
            statusItem?.button?.title = "No Events Today"
        }
        
        for event in events {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            
            let startTime = timeFormatter.string(from: event.startDate)
            let title = event.title ?? "No Title"
            let location = event.location ?? "No Location"
            let menuItem = NSMenuItem(title: "\(startTime): \(title) @ \(location)", action: nil, keyEquivalent: "")
            menu.addItem(menuItem)
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
