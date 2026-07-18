import SwiftUI
import AppKit

/// Onboarding premier lancement — pager custom dans le popover
/// (une fenêtre séparée se bat avec la policy .accessory + LaunchAgent).
struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @AppStorage(Prefs.obsidianPath) var obsidianPath: String = ""
    @AppStorage(Prefs.slackEnabled) var slackEnabled: Bool = true
    @AppStorage(Prefs.favoriteSlackChannelIds) var favoriteChannelIdsString: String = ""
    @AppStorage(Prefs.lastSlackDestinationIds) var lastSlackDestinationIdsString: String = ""

    @State private var currentPage = 0
    @State private var claudeKey: String = ""
    @State private var claudeTestResult: String?
    @State private var testingClaude = false
    @State private var slackToken: String = ""
    @State private var loadingChannels = false

    private let pageCount = 7

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                pageContent
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollEdgeEffectStyle(.soft, for: .vertical)

            Divider()
            footer
        }
        .onAppear {
            claudeKey = SecretStore.get("claude_api_key") ?? ""
            slackToken = SecretStore.get("slack_bot_token") ?? ""
        }
    }

    // MARK: - Pages

    @ViewBuilder
    private var pageContent: some View {
        switch currentPage {
        case 0: pastePage
        case 1: analyzePage
        case 2: slackIntroPage
        case 3: claudeKeyPage
        case 4: obsidianPage
        case 5: slackSetupPage
        default: readyPage
        }
    }

    private var pastePage: some View {
        tutorialPage(
            icon: "doc.on.clipboard",
            title: "Colle ton transcript",
            lines: [
                "Copie le transcript de ton meeting (Granola, Zoom, Teams…).",
                "Clique l'icône MeetingBrief dans la barre des menus, puis clique la zone — ou ⌘V.",
                "L'analyse démarre automatiquement 2 secondes après le collage.",
            ]
        )
    }

    private var analyzePage: some View {
        tutorialPage(
            icon: "sparkles",
            title: "Claude structure la note",
            lines: [
                "Claude extrait résumé, sections thématiques, décisions et actions par responsable.",
                "La note part directement dans ton vault Obsidian, prête à être consultée.",
                "Claude peut reformuler ou omettre — garde un œil critique sur les actions engagées.",
            ]
        )
    }

    private var slackIntroPage: some View {
        tutorialPage(
            icon: "paperplane",
            title: "Partage sur Slack",
            lines: [
                "Une fois la note enregistrée, MeetingBrief te propose d'envoyer le récap des actions sur Slack.",
                "La dernière destination utilisée est pré-sélectionnée — un clic et c'est parti.",
                "Rien n'est jamais envoyé sans ton clic. Tu peux aussi passer cette étape.",
            ]
        )
    }

    private var claudeKeyPage: some View {
        setupPage(icon: "key", title: "Ta clé API Claude") {
            Text("MeetingBrief appelle l'API Claude avec ta propre clé. Crée-la sur [console.anthropic.com](https://console.anthropic.com).")
                .font(.callout)
                .foregroundColor(.secondary)

            SecureField("sk-ant-…", text: $claudeKey)
                .textFieldStyle(.roundedBorder)
                .onSubmit { SecretStore.set(claudeKey, for: "claude_api_key") }

            HStack(spacing: 10) {
                Button(testingClaude ? "Test…" : "Tester la clé") {
                    Task { await testClaudeKey() }
                }
                .disabled(testingClaude || claudeKey.isEmpty)
                if let result = claudeTestResult {
                    Text(result)
                        .font(.caption)
                        .foregroundColor(result.hasPrefix("✓") ? .green : .red)
                }
            }

            Text("Stockée en local uniquement (~/Library/Application Support/MeetingBrief/, permissions 600).")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var obsidianPage: some View {
        setupPage(icon: "folder", title: "Ton dossier Obsidian") {
            Text("Choisis le dossier de ton vault où les notes de meeting seront écrites (`YYYY-MM-DD-titre.md`).")
                .font(.callout)
                .foregroundColor(.secondary)

            HStack {
                TextField("~/MonVault/meetings", text: $obsidianPath)
                    .textFieldStyle(.roundedBorder)
                Button("Parcourir…") { pickFolder() }
            }

            if !obsidianPath.isEmpty {
                Text("✓ \(obsidianPath)").font(.caption).foregroundColor(.green)
            }
        }
    }

    private var slackSetupPage: some View {
        setupPage(icon: "paperplane", title: "Slack (optionnel)") {
            Toggle("Proposer l'envoi sur Slack après chaque note", isOn: $slackEnabled)

            if slackEnabled {
                Text("Colle le Bot Token de ton app Slack (`xoxb-…`). Scopes requis : chat:write, channels:read, groups:read, users:read, im:write — voir le README pour créer l'app en 5 min.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                SecureField("xoxb-…", text: $slackToken)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { SecretStore.set(slackToken, for: "slack_bot_token") }

                Button(loadingChannels ? "Chargement…" : "Charger les destinations") {
                    // Le token doit être persisté AVANT l'appel réseau (SlackService lit le SecretStore).
                    SecretStore.set(slackToken, for: "slack_bot_token")
                    Task {
                        loadingChannels = true
                        defer { loadingChannels = false }
                        await state.loadSlackChannels()
                    }
                }
                .disabled(loadingChannels || slackToken.isEmpty)

                if !state.slackChannels.isEmpty {
                    destinationSelection
                }
            } else {
                Text("Tu pourras l'activer plus tard dans les Réglages.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var destinationSelection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Destinations favorites (affichées au moment d'envoyer) :")
                .font(.caption.weight(.semibold))

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(state.slackChannels) { ch in
                        Toggle(isOn: Binding(
                            get: { favoriteChannelIds.contains(ch.id) },
                            set: { _ in toggleFavorite(ch.id) }
                        )) {
                            Text(ch.displayLabel).font(.callout)
                        }
                        .toggleStyle(.checkbox)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 160)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))

            HStack {
                Text("Destination par défaut :").font(.caption)
                Menu(defaultDestinationLabel) {
                    ForEach(state.slackChannels) { ch in
                        Button(ch.displayLabel) {
                            lastSlackDestinationIdsString = ch.id
                        }
                    }
                }
                .fixedSize()
            }
        }
    }

    private var readyPage: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 30)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundColor(.green)
            Text("C'est prêt !").font(.title.weight(.semibold))
            Text("Copie le transcript de ton prochain meeting et clique l'icône MeetingBrief dans la barre des menus.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Spacer(minLength: 30)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Layout helpers

    private func tutorialPage(icon: String, title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(.accentColor)
                .padding(.top, 20)
            Text(title).font(.title.weight(.semibold))
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .top, spacing: 8) {
                    Text("•").foregroundColor(.secondary)
                    Text(.init(line)).font(.callout)
                }
            }
        }
    }

    private func setupPage<Content: View>(icon: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(.accentColor)
                .padding(.top, 12)
            Text(title).font(.title2.weight(.semibold))
            content()
        }
    }

    private var footer: some View {
        HStack {
            if currentPage > 0 {
                Button("Retour") { withAnimation { currentPage -= 1 } }
            }
            Spacer()
            pageDots
            Spacer()
            if currentPage < pageCount - 1 {
                Button("Suivant") {
                    commitCurrentPage()
                    withAnimation { currentPage += 1 }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canGoNext)
            } else {
                Button("C'est parti") { finish() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<pageCount, id: \.self) { i in
                Circle()
                    .fill(i == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
    }

    // MARK: - Logic

    private var favoriteChannelIds: Set<String> {
        Set(favoriteChannelIdsString.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    private func toggleFavorite(_ id: String) {
        var set = favoriteChannelIds
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
        favoriteChannelIdsString = set.sorted().joined(separator: ",")
    }

    private var defaultDestinationLabel: String {
        let ids = Set(lastSlackDestinationIdsString.split(separator: ",").map(String.init))
        let names = state.slackChannels.filter { ids.contains($0.id) }.map(\.displayLabel)
        return names.isEmpty ? "Choisir…" : names.joined(separator: ", ")
    }

    private var canGoNext: Bool {
        switch currentPage {
        case 3: return !claudeKey.trimmingCharacters(in: .whitespaces).isEmpty
        case 4: return !obsidianPath.trimmingCharacters(in: .whitespaces).isEmpty
        case 5: return !slackEnabled || !slackToken.trimmingCharacters(in: .whitespaces).isEmpty
        default: return true
        }
    }

    private func commitCurrentPage() {
        switch currentPage {
        case 3: SecretStore.set(claudeKey, for: "claude_api_key")
        case 5: if slackEnabled { SecretStore.set(slackToken, for: "slack_bot_token") }
        default: break
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Prefs.hasCompletedOnboarding)
        state.step = .input
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            obsidianPath = url.path
        }
    }

    @MainActor
    private func testClaudeKey() async {
        claudeTestResult = nil
        SecretStore.set(claudeKey, for: "claude_api_key")
        testingClaude = true
        defer { testingClaude = false }
        do {
            try await ClaudeService.testKey()
            claudeTestResult = "✓ Clé valide"
        } catch {
            claudeTestResult = error.localizedDescription
        }
    }
}
