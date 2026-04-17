import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @AppStorage("obsidianPath") var obsidianPath: String = ""
    @AppStorage("slackChannelId") var slackChannelId: String = ""
    @AppStorage("slackChannelName") var slackChannelName: String = ""

    @State private var claudeKey: String = ""
    @State private var slackToken: String = ""
    @State private var loadingChannels = false
    @State private var savedToast: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("Clé API Claude") {
                    SecureField("sk-ant-…", text: $claudeKey)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Enregistrer") {
                            Keychain.set(claudeKey, for: "claude_api_key")
                            toast("Clé Claude enregistrée")
                        }
                        Button("Effacer") {
                            Keychain.delete("claude_api_key")
                            claudeKey = ""
                        }
                    }
                    Text("Stockée dans le Keychain macOS.").font(.caption).foregroundColor(.secondary)
                }

                section("Dossier Obsidian") {
                    HStack {
                        TextField("~/BriocheBrain/1-notes", text: $obsidianPath)
                            .textFieldStyle(.roundedBorder)
                        Button("Parcourir…") { pickFolder() }
                    }
                    Text("Les notes seront écrites sous la forme `YYYY-MM-DD-titre.md`.")
                        .font(.caption).foregroundColor(.secondary)
                }

                section("Slack Bot Token") {
                    SecureField("xoxb-…", text: $slackToken)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Enregistrer") {
                            Keychain.set(slackToken, for: "slack_bot_token")
                            toast("Token Slack enregistré")
                        }
                        Button(loadingChannels ? "Chargement…" : "Charger les channels") {
                            Task { await loadChannels() }
                        }
                        .disabled(loadingChannels)
                    }
                    Text("Scopes requis : chat:write, channels:read, groups:read.")
                        .font(.caption).foregroundColor(.secondary)
                }

                section("Channel Slack") {
                    if state.slackChannels.isEmpty {
                        Text("Charge d'abord les channels avec le bouton ci-dessus.")
                            .font(.caption).foregroundColor(.secondary)
                    } else {
                        Picker("Channel", selection: Binding(
                            get: { slackChannelId },
                            set: { newId in
                                slackChannelId = newId
                                slackChannelName = state.slackChannels.first(where: { $0.id == newId })?.name ?? ""
                            }
                        )) {
                            Text("— Choisir —").tag("")
                            ForEach(state.slackChannels) { ch in
                                Text("#\(ch.name)").tag(ch.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                if let toast = savedToast {
                    Text(toast)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .onAppear {
            claudeKey = Keychain.get("claude_api_key") ?? ""
            slackToken = Keychain.get("slack_bot_token") ?? ""
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).bold()
            content()
        }
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
    private func loadChannels() async {
        state.errorMessage = nil
        loadingChannels = true
        defer { loadingChannels = false }
        do {
            state.slackChannels = try await SlackService.listChannels()
            toast("\(state.slackChannels.count) channels chargés")
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }
}
