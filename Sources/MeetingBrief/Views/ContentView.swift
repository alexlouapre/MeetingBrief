import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            Group {
                switch state.step {
                case .input:     TranscriptInputView()
                case .analyzing: progressView("Analyse en cours…")
                case .review:    AnalysisReviewView()
                case .sending:   progressView("Envoi vers Obsidian et Slack…")
                case .done:      doneView
                case .settings:  SettingsView()
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
    }

    private var header: some View {
        HStack {
            Text("MeetingBrief").font(.headline)
            Spacer()
            if state.step != .settings {
                Button { state.step = .settings } label: {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)
                .help("Réglages")
            } else {
                Button("Retour") { state.step = .input }
                    .buttonStyle(.plain)
            }
            Button { NSApp.terminate(nil) } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.plain)
            .help("Quitter")
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

    private var doneView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("Meeting envoyé !").font(.headline)
            Button("Nouveau meeting") { state.reset() }
                .buttonStyle(.borderedProminent)
        }
    }
}
