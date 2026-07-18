import Foundation
import SwiftUI
import AppKit

enum Step {
    case input
    case analyzing
    case review
    case sending
    case done
    case settings
}

@MainActor
final class AppState: ObservableObject {
    @Published var step: Step = .input
    @Published var transcript: String = ""
    @Published var analysis: MeetingAnalysis?
    @Published var errorMessage: String?
    @Published var slackChannels: [SlackChannel] = []
    @Published var autoAnalyzeSecondsRemaining: Int?
    @Published var analyzeReceivedChars: Int = 0

    private var autoAnalyzeTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?

    func reset() {
        autoAnalyzeTask?.cancel()
        autoAnalyzeTask = nil
        analysisTask?.cancel()
        analysisTask = nil
        step = .input
        transcript = ""
        analysis = nil
        errorMessage = nil
        autoAnalyzeSecondsRemaining = nil
        analyzeReceivedChars = 0
    }

    func cancelAutoAnalyze() {
        autoAnalyzeTask?.cancel()
        autoAnalyzeTask = nil
        autoAnalyzeSecondsRemaining = nil
    }

    func startAutoAnalyzeCountdown() {
        autoAnalyzeSecondsRemaining = 2
        autoAnalyzeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
            self?.autoAnalyzeSecondsRemaining = 1
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
            guard let self else { return }
            self.autoAnalyzeSecondsRemaining = nil
            self.autoAnalyzeTask = nil
            self.triggerAnalyze()
        }
    }

    /// Runs the Claude request in a Task owned by AppState (survives popover open/close
    /// cycles, so the user can dismiss the popover and get a notification on completion).
    func triggerAnalyze() {
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        cancelAutoAnalyze()
        errorMessage = nil
        analyzeReceivedChars = 0
        step = .analyzing

        analysisTask?.cancel()
        analysisTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let analysis = try await ClaudeService.analyze(transcript: self.transcript) { chars in
                    Task { @MainActor [weak self] in
                        self?.analyzeReceivedChars = chars
                    }
                }
                self.analysis = analysis
                self.step = .review
                await NotificationService.postAnalysisReady()
            } catch {
                self.errorMessage = error.localizedDescription
                self.step = .input
            }
            self.analysisTask = nil
        }
    }
}
