import SwiftUI
import AppKit

struct TranscriptInputView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Colle ici le transcript de ta réunion")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextEditor(text: $state.transcript)
                .font(.system(.body, design: .monospaced))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray.opacity(0.3))
                )

            HStack {
                Button("Coller depuis le presse-papiers") {
                    if let clip = NSPasteboard.general.string(forType: .string) {
                        state.transcript = clip
                    }
                }
                Spacer()
                Button("Analyser") {
                    Task { await analyze() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(state.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    @MainActor
    private func analyze() async {
        state.errorMessage = nil
        state.step = .analyzing
        do {
            let analysis = try await ClaudeService.analyze(transcript: state.transcript)
            state.analysis = analysis
            state.step = .review
        } catch {
            state.errorMessage = error.localizedDescription
            state.step = .input
        }
    }
}
