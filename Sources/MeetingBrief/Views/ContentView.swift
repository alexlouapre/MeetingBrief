import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            Group {
                switch state.step {
                case .input:     TranscriptInputView()
                case .analyzing: analyzingView
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
        .background(paperBackground)
        .onAppear {
            Task { await NotificationService.requestAuthIfNeeded() }
        }
    }

    private var paperBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.12, green: 0.12, blue: 0.13)
            : Color.white
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
            Text("Meeting envoyé !").font(.headline)
            Button("Nouveau meeting") { state.reset() }
                .buttonStyle(.borderedProminent)
        }
    }
}
