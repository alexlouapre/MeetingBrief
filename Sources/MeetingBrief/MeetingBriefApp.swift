import SwiftUI
import AppKit

@main
struct MeetingBriefApp: App {
    @StateObject private var state = AppState()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("MeetingBrief", systemImage: "doc.text.magnifyingglass") {
            ContentView()
                .environmentObject(state)
                .frame(width: 680, height: 760)
        }
        .menuBarExtraStyle(.window)
    }
}
