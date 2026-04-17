import SwiftUI
import AppKit

@main
struct MeetingBriefApp: App {
    @StateObject private var state = AppState()

    init() {
        NSApp.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("MeetingBrief", systemImage: "doc.text.magnifyingglass") {
            ContentView()
                .environmentObject(state)
                .frame(width: 540, height: 640)
        }
        .menuBarExtraStyle(.window)
    }
}
