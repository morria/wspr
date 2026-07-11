//
//  WSPRApp.swift
//  WSPR
//
//  A small, native iOS app for sending and receiving WSPR
//  (Weak Signal Propagation Reporter) data.
//

import SwiftUI

@main
struct WSPRApp: App {
    // Long-lived app state. Created once and shared through the environment.
    @State private var settings = SettingsStore()
    @State private var location = LocationManager()
    @State private var reports = ReportsStore()
    @State private var transmitter = TransmitController()
    @State private var receiver = ReceiveController()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(location)
                .environment(reports)
                .environment(transmitter)
                .environment(receiver)
                .tint(.accentColor)
                .task {
                    // Feed locally decoded ("radio") spots into the shared store.
                    reports.attach(receiver: receiver)
                }
        }
    }
}
