// MasterProjectApp.swift
// UPDATE: Replace your existing MasterProjectApp.swift with this

import SwiftUI

@main
struct MasterProjectApp: App {
    @StateObject private var sessionManager = ExperimentSessionManager()
    @StateObject private var classifier = SoundClassifierService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
                .environmentObject(classifier)
                .onAppear {
                    classifier.sessionManager = sessionManager
                    UIDevice.current.isBatteryMonitoringEnabled = true
                }
        }
    }
}
