import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            Group {
                switch state.step {
                case .onboarding:  OnboardingView()
                case .input:       TranscriptInputView()
                case .analyzing:   analyzingView
                case .review:      AnalysisReviewView()
                case .saving:      progressView("Enregistrement de la note…")
                case .saveFailed:  SaveFailedView()
                case .slackPicker: MiniSlackPickerView()
                case .sending:     progressView("Envoi vers Slack…")
                case .done:        doneView
                case .settings:    SettingsView()
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let err = state.errorMessage {
                Divider()
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear {
            state.isPopoverVisible = true
            state.openWindowAction = openWindow
            state.dismissWindowAction = dismissWindow
            // Le picker est visible dans le popover — pas besoin de la fenêtre flottante en double.
            dismissWindow(id: AppState.slackPickerWindowID)
            Task { await NotificationService.requestAuthIfNeeded() }
        }
        .onDisappear {
            state.isPopoverVisible = false
        }
    }

    private var header: some View {
        HStack {
            Text("MeetingBrief").font(.headline)
            Spacer()
            if state.step == .settings {
                Button("Retour") { state.step = .input }
                    .buttonStyle(.plain)
            } else if state.step != .onboarding {
                Button { state.step = .settings } label: {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)
                .help("Réglages")
            }
            Button { NSApp.keyWindow?.close() } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.plain)
            .help("Fermer")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func progressView(_ label: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(label).foregroundColor(.secondary)
        }
    }

    private var analyzingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Analyse en cours…").foregroundColor(.secondary)
            if state.analyzeReceivedChars > 0 {
                Text("\(state.analyzeReceivedChars) caractères reçus")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var doneView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("C'est dans la boîte !").font(.headline)
            if let url = state.lastNoteURL {
                Button("Ouvrir la note") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Nouveau meeting") { state.reset() }
                .buttonStyle(.borderedProminent)
        }
    }
}

/// Vue d'échec d'écriture de la note — le transcript et l'analyse sont conservés.
struct SaveFailedView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 42))
                .foregroundColor(.orange)
            Text("La note n'a pas pu être enregistrée").font(.headline)
            Text("Le transcript et l'analyse sont conservés — rien n'est perdu.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Button("Copier le markdown") {
                    if let analysis = state.analysis {
                        let md = ObsidianService.renderMarkdown(analysis: analysis)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(md, forType: .string)
                    }
                }
                Button("Ouvrir Réglages") { state.step = .settings }
                Button("Réessayer") {
                    Task { await state.saveNoteAndAdvance() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
