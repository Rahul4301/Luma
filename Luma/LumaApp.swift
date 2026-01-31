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
        Settings {
            SettingsView()
        }
    }
}
