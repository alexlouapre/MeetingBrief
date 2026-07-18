import SwiftUI
import AppKit

struct TranscriptInputView: View {
    @EnvironmentObject var state: AppState

    @State private var isHovering = false
    @State private var emptyClipboardHint = false

    var body: some View {
        Group {
            if state.transcript.isEmpty {
                emptyDropzone
            } else {
                filledPreview
            }
        }
    }

    // MARK: - Empty dropzone

    private var emptyDropzone: some View {
        Button(action: pasteFromClipboard) {
            VStack(spacing: 14) {
                Spacer()
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundColor(.secondary)
                VStack(spacing: 4) {
                    Text("Clique ici pour coller le transcript")
                        .font(.title3.weight(.medium))
                    Text("ou ⌘V")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if emptyClipboardHint {
                        Text("Presse-papiers vide")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.top, 4)
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovering ? Color.primary.opacity(0.03) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovering = hovering }
        }
        .keyboardShortcut("v", modifiers: .command)
    }

    // MARK: - Filled preview

    private var filledPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let countdown = state.autoAnalyzeSecondsRemaining {
                autoAnalyzeBanner(countdown)
            }

            ScrollView {
                Text(state.transcript)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.25))
            )

            HStack {
                Text("\(state.transcript.count) caractères")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Effacer") {
                    state.cancelAutoAnalyze()
                    state.transcript = ""
                }
                .buttonStyle(.plain)
                Button("Analyser") {
                    state.triggerAnalyze()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(state.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func autoAnalyzeBanner(_ countdown: Int) -> some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("Analyse automatique dans \(countdown)s…")
                .font(.callout)
            Spacer()
            Button("Annuler") { state.cancelAutoAnalyze() }
                .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.accentColor.opacity(0.3))
        )
        .cornerRadius(6)
    }

    // MARK: - Actions

    private func pasteFromClipboard() {
        guard let clip = NSPasteboard.general.string(forType: .string), !clip.isEmpty else {
            withAnimation { emptyClipboardHint = true }
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                await MainActor.run {
                    withAnimation { emptyClipboardHint = false }
                }
            }
            return
        }
        state.transcript = clip
        state.startAutoAnalyzeCountdown()
    }
}
