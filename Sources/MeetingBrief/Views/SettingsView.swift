import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @AppStorage(Prefs.obsidianPath) var obsidianPath: String = ""
    @AppStorage(Prefs.favoriteSlackChannelIds) var favoriteChannelIdsString: String = ""
    @AppStorage(Prefs.validationStepEnabled) var validationStepEnabled: Bool = false
    @AppStorage(Prefs.slackEnabled) var slackEnabled: Bool = true

    @State private var claudeKey: String = ""
    @State private var slackToken: String = ""
    @State private var loadingChannels = false
    @State private var testingClaude = false
    @State private var savedToast: String?

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
                section("Clé API Claude") {
                    SecureField("sk-ant-…", text: $claudeKey)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Enregistrer") {
                            SecretStore.set(claudeKey, for: "claude_api_key")
                            toast("Clé Claude enregistrée")
                        }
                        Button(testingClaude ? "Test…" : "Tester") {
                            Task { await testClaudeKey() }
                        }
                        .disabled(testingClaude || claudeKey.isEmpty)
                        Button("Effacer") {
                            SecretStore.delete("claude_api_key")
                            claudeKey = ""
                        }
                    }
                    Text("Stockée dans ~/Library/Application Support/MeetingBrief/ (permissions 600).").font(.caption).foregroundColor(.secondary)
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
            claudeKey = SecretStore.get("claude_api_key") ?? ""
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
    private func testClaudeKey() async {
        state.errorMessage = nil
        // Ensure the key is saved before testing
        if !claudeKey.isEmpty {
            SecretStore.set(claudeKey, for: "claude_api_key")
        }
        testingClaude = true
        defer { testingClaude = false }
        do {
            try await ClaudeService.testKey()
            toast("✓ Clé Claude valide")
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
