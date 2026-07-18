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

        // MenuBarExtra ne peut pas être ouvert programmatiquement : quand l'analyse se
        // termine popover fermé, cette fenêtre flottante sert de point de ré-entrée.
        Window("MeetingBrief", id: AppState.slackPickerWindowID) {
            SlackPickerWindowView()
                .environmentObject(state)
                .frame(width: 420)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .windowLevel(.floating)
    }
}

/// Contenu de la fenêtre flottante post-analyse. Reflète les mêmes steps que le
/// popover pour la fin du flux ; se ferme dès que le flux repart au début.
struct SlackPickerWindowView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Group {
            switch state.step {
            case .slackPicker:
                MiniSlackPickerView()
            case .sending:
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Envoi vers Slack…").foregroundColor(.secondary)
                }
            case .done:
                VStack(spacing: 14) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 42))
                        .foregroundColor(.green)
                    Text("C'est dans la boîte !").font(.headline)
                    if let url = state.lastNoteURL {
                        Button("Ouvrir la note") { NSWorkspace.shared.open(url) }
                    }
                    Button("Fermer") { state.reset() }
                        .buttonStyle(.borderedProminent)
                }
            case .saveFailed:
                SaveFailedView()
            default:
                // Le flux est reparti ailleurs — cette fenêtre n'a plus de raison d'être.
                Color.clear.onAppear { dismissWindow(id: AppState.slackPickerWindowID) }
            }
        }
        .padding(20)
        .frame(minHeight: 200)
    }
}
