//
//  LumaApp.swift
//  Luma
//
//  Root app entry for the Luma browser.
//
import SwiftUI

@main
struct LumaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 1200, height: 800)
        Settings {
            SettingsView()
        }
    }
}
