import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @AppStorage(Prefs.obsidianPath) var obsidianPath: String = ""
    @AppStorage(Prefs.favoriteSlackChannelIds) var favoriteChannelIdsString: String = ""
    @AppStorage(Prefs.validationStepEnabled) var validationStepEnabled: Bool = false
    @AppStorage(Prefs.slackEnabled) var slackEnabled: Bool = true
    @AppStorage(Prefs.llmProvider) var llmProvider: String = "anthropic"
    @AppStorage(Prefs.llmModel) var llmModel: String = "claude-sonnet-5"
    @AppStorage(Prefs.llmBaseURL) var llmBaseURL: String = ""

    @State private var apiKey: String = ""
    @State private var slackToken: String = ""
    @State private var loadingChannels = false
    @State private var testingKey = false
    @State private var savedToast: String?

    private var provider: LLMProvider { LLMProvider(rawValue: llmProvider) ?? .anthropic }

    private var favoriteChannelIds: Set<String> {
        Set(favoriteChannelIdsString.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    private func toggleFavorite(_ id: String) {
        var set = favoriteChannelIds
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
        favoriteChannelIdsString = set.sorted().joined(separator: ",")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("Modèle & fournisseur") {
                    Picker("Fournisseur", selection: $llmProvider) {
                        Text("Claude (Anthropic)").tag(LLMProvider.anthropic.rawValue)
                        Text("Compatible OpenAI").tag(LLMProvider.openaiCompatible.rawValue)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .onChange(of: llmProvider) {
                        // Recharge la clé du bon slot pour ne pas mélanger les deux dialectes.
                        apiKey = SecretStore.get(LLMService.secretKeyName(for: provider)) ?? ""
                    }

                    TextField(
                        provider == .anthropic ? "claude-sonnet-5" : "gpt-4o",
                        text: $llmModel
                    )
                    .textFieldStyle(.roundedBorder)

                    if provider == .openaiCompatible {
                        TextField("https://api.openai.com/v1", text: $llmBaseURL)
                            .textFieldStyle(.roundedBorder)
                        Text("URL de base de l'API (compatible OpenAI). Vide → https://api.openai.com/v1. Local Ollama : http://localhost:11434/v1.")
                            .font(.caption).foregroundColor(.secondary)
                    }

                    SecureField(provider == .anthropic ? "sk-ant-…" : "sk-…", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Enregistrer") {
                            SecretStore.set(apiKey, for: LLMService.secretKeyName(for: provider))
                            toast("Clé enregistrée")
                        }
                        Button(testingKey ? "Test…" : "Tester") {
                            Task { await testAPIKey() }
                        }
                        .disabled(testingKey || apiKey.isEmpty)
                        Button("Effacer") {
                            SecretStore.delete(LLMService.secretKeyName(for: provider))
                            apiKey = ""
                        }
                    }
                    Text("Clé stockée dans ~/Library/Application Support/MeetingBrief/ (permissions 600), une par fournisseur.").font(.caption).foregroundColor(.secondary)
                }

                section("Dossier Obsidian") {
                    HStack {
                        TextField("~/BriocheBrain/1-notes", text: $obsidianPath)
                            .textFieldStyle(.roundedBorder)
                        Button("Parcourir…") { pickFolder() }
                    }
                    Text("Les notes seront écrites sous la forme `YYYY-MM-DD-titre.md`.")
                        .font(.caption).foregroundColor(.secondary)
                    if !obsidianPath.isEmpty {
                        Text("✓ \(obsidianPath)").font(.caption).foregroundColor(.green)
                    }
                }

                section("Slack Bot Token") {
                    SecureField("xoxb-…", text: $slackToken)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Enregistrer") {
                            SecretStore.set(slackToken, for: "slack_bot_token")
                            toast("Token Slack enregistré")
                        }
                        Button(loadingChannels ? "Chargement…" : "Charger les destinations") {
                            Task { await loadChannels() }
                        }
                        .disabled(loadingChannels)
                    }
                    Text("Scopes requis : chat:write, channels:read, groups:read, users:read, im:write.")
                        .font(.caption).foregroundColor(.secondary)
                    if !state.slackChannels.isEmpty {
                        let channelCount = state.slackChannels.filter { $0.kind == .channel }.count
                        let userCount = state.slackChannels.filter { $0.kind == .user }.count
                        Text("✓ \(channelCount) channels, \(userCount) utilisateurs")
                            .font(.caption).foregroundColor(.green)
                    }
                }

                if !state.slackChannels.isEmpty {
                    section("Destinations visibles à l'envoi") {
                        Text("Coche les channels et utilisateurs que tu veux voir dans le sélecteur au moment d'envoyer. Si rien n'est coché, tout est affiché.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Button("Tout cocher") {
                                let all = state.slackChannels.map(\.id).sorted()
                                favoriteChannelIdsString = all.joined(separator: ",")
                            }
                            Button("Tout décocher") {
                                favoriteChannelIdsString = ""
                            }
                            Spacer()
                            Text("\(favoriteChannelIds.count) / \(state.slackChannels.count) coché(s)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        let channels = state.slackChannels.filter { $0.kind == .channel }
                        let users = state.slackChannels.filter { $0.kind == .user }

                        VStack(alignment: .leading, spacing: 10) {
                            if !channels.isEmpty {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Channels").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                                    ForEach(channels) { ch in
                                        Toggle(isOn: Binding(
                                            get: { favoriteChannelIds.contains(ch.id) },
                                            set: { _ in toggleFavorite(ch.id) }
                                        )) {
                                            Text("#\(ch.name)").font(.callout)
                                        }
                                        .toggleStyle(.checkbox)
                                    }
                                }
                            }
                            if !users.isEmpty {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Utilisateurs (DM)").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                                    ForEach(users) { u in
                                        Toggle(isOn: Binding(
                                            get: { favoriteChannelIds.contains(u.id) },
                                            set: { _ in toggleFavorite(u.id) }
                                        )) {
                                            Text("@\(u.name)").font(.callout)
                                        }
                                        .toggleStyle(.checkbox)
                                    }
                                }
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2))
                        )
                    }
                }

                section("Flux") {
                    Toggle("Étape de validation avant envoi", isOn: $validationStepEnabled)
                    Text("Si activé, l'analyse s'ouvre en mode relecture avant d'écrire la note. Sinon la note part directement dans Obsidian.")
                        .font(.caption).foregroundColor(.secondary)
                    Toggle("Publication Slack", isOn: $slackEnabled)
                    Text("Si désactivé, le flux se termine après l'écriture de la note (pas de picker Slack).")
                        .font(.caption).foregroundColor(.secondary)
                    Button("Relancer l'onboarding") {
                        UserDefaults.standard.set(false, forKey: Prefs.hasCompletedOnboarding)
                        state.step = .onboarding
                    }
                }

                if let toast = savedToast {
                    Text(toast)
                        .font(.caption)
                        .foregroundColor(.green)
                }

                Divider().padding(.vertical, 6)
                HStack {
                    Spacer()
                    Button("Quitter MeetingBrief") { NSApp.terminate(nil) }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                }
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .onAppear {
            apiKey = SecretStore.get(LLMService.secretKeyName(for: provider)) ?? ""
            slackToken = SecretStore.get("slack_bot_token") ?? ""
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).bold()
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
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

    private func toast(_ msg: String) {
        savedToast = msg
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run { savedToast = nil }
        }
    }

    @MainActor
    private func testAPIKey() async {
        state.errorMessage = nil
        // Ensure the key is saved before testing (LLMService reads from SecretStore).
        if !apiKey.isEmpty {
            SecretStore.set(apiKey, for: LLMService.secretKeyName(for: provider))
        }
        testingKey = true
        defer { testingKey = false }
        do {
            try await LLMService.testKey()
            toast("✓ Clé valide")
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadChannels() async {
        state.errorMessage = nil
        loadingChannels = true
        defer { loadingChannels = false }
        do {
            let result = try await SlackService.listDestinations()
            state.slackChannels = result.items
            if let usersError = result.usersError {
                state.errorMessage = "Utilisateurs Slack non chargés : \(usersError)"
            }
            toast("\(state.slackChannels.count) destinations chargées")
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }
}
