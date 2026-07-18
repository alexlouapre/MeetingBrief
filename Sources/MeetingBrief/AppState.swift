import Foundation
import SwiftUI
import AppKit

enum Step: Equatable {
    case onboarding
    case input
    case analyzing
    case review        // legacy, seulement si l'étape de validation est réactivée
    case saving        // écriture de la note (flux direct, bref)
    case saveFailed    // échec d'écriture — transcript + analyse conservés
    case slackPicker   // mini picker ; la note est déjà sur disque
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
    @Published var lastNoteURL: URL?

    /// Vrai quand le popover MenuBarExtra est à l'écran (maintenu par ContentView).
    var isPopoverVisible = false
    /// Actions de scène capturées depuis l'environnement de ContentView — le popover
    /// est forcément ouvert pour coller un transcript, donc capturées avant besoin.
    var openWindowAction: OpenWindowAction?
    var dismissWindowAction: DismissWindowAction?

    static let slackPickerWindowID = "slack-picker"

    private var autoAnalyzeTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?

    private var defaults: UserDefaults { .standard }

    var validationStepEnabled: Bool { defaults.bool(forKey: Prefs.validationStepEnabled) }
    var slackEnabled: Bool { defaults.bool(forKey: Prefs.slackEnabled) }
    var hasCompletedOnboarding: Bool { defaults.bool(forKey: Prefs.hasCompletedOnboarding) }

    init() {
        Prefs.registerDefaults()
        if !defaults.bool(forKey: Prefs.hasCompletedOnboarding) {
            step = .onboarding
        }
    }

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
        lastNoteURL = nil
        dismissWindowAction?(id: Self.slackPickerWindowID)
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
                await self.handleAnalysisReady()
            } catch {
                self.errorMessage = error.localizedDescription
                self.step = .input
            }
            self.analysisTask = nil
        }
    }

    private func handleAnalysisReady() async {
        if validationStepEnabled {
            step = .review
            await NotificationService.post(body: "Analyse prête — clique l'icône pour voir")
            return
        }
        await saveNoteAndAdvance()
    }

    /// Flux direct : écrit la note puis avance vers le picker Slack ou `.done`.
    /// Aussi appelé par « Réessayer » depuis `.saveFailed`.
    func saveNoteAndAdvance() async {
        step = .saving
        do {
            try writeNoteToObsidian()
        } catch {
            errorMessage = error.localizedDescription
            step = .saveFailed
            await NotificationService.post(body: "Impossible d'enregistrer la note — rien n'est perdu, clique l'icône")
            return
        }

        if slackEnabled {
            step = .slackPicker
            await NotificationService.post(body: "Note enregistrée — choisis la destination Slack")
            if !isPopoverVisible {
                openWindowAction?(id: Self.slackPickerWindowID)
                NSApp.activate(ignoringOtherApps: true)
            }
        } else {
            step = .done
            await NotificationService.post(body: "Note enregistrée dans Obsidian")
        }
    }

    @discardableResult
    func writeNoteToObsidian() throws -> URL {
        guard let analysis else { throw ObsidianError.missingPath }
        let folderPath = (defaults.string(forKey: Prefs.obsidianPath) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let url = try ObsidianService.writeNote(analysis: analysis, folderPath: folderPath)
        lastNoteURL = url
        return url
    }

    /// Poste le message Slack vers chaque destination. Rien n'est envoyé sans que
    /// l'utilisateur ait explicitement cliqué le bouton qui appelle cette méthode.
    func postToSlack(destinationIds: Set<String>) async {
        guard let analysis, !destinationIds.isEmpty else { return }
        let previousStep = step
        errorMessage = nil
        step = .sending
        do {
            let slackText = ObsidianService.renderSlackMessage(analysis: analysis)
            for id in destinationIds {
                try await SlackService.postMessage(channelId: id, text: slackText)
            }
            defaults.set(destinationIds.sorted().joined(separator: ","), forKey: Prefs.lastSlackDestinationIds)
            step = .done
        } catch {
            errorMessage = error.localizedDescription
            step = previousStep
        }
    }

    func loadSlackChannels() async {
        do {
            let result = try await SlackService.listDestinations()
            slackChannels = result.items
            if let usersError = result.usersError {
                errorMessage = "Utilisateurs Slack non chargés : \(usersError)"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
