import SwiftUI

struct AnalysisReviewView: View {
    @EnvironmentObject var state: AppState
    @AppStorage("obsidianPath") var obsidianPath: String = ""
    @AppStorage("slackChannelId") var slackChannelId: String = ""
    @AppStorage("slackChannelName") var slackChannelName: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if state.analysis != nil {
                    field(label: "Titre", binding: Binding(
                        get: { state.analysis?.titre ?? "" },
                        set: { state.analysis?.titre = $0 }
                    ))

                    field(label: "Date", binding: Binding(
                        get: { state.analysis?.date ?? "" },
                        set: { state.analysis?.date = $0 }
                    ), placeholder: "YYYY-MM-DD")

                    editor(label: "Résumé", binding: Binding(
                        get: { state.analysis?.resume ?? "" },
                        set: { state.analysis?.resume = $0 }
                    ))

                    sujetsSection
                    decisionsSection
                    actionsSection

                    if obsidianPath.isEmpty || slackChannelId.isEmpty {
                        Text("⚠︎ Configure le dossier Obsidian et le channel Slack dans Réglages avant d'envoyer.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    HStack {
                        Button("Annuler") { state.reset() }
                        Spacer()
                        Button("Valider et envoyer") {
                            Task { await send() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(obsidianPath.isEmpty || slackChannelId.isEmpty)
                    }
                }
            }
        }
    }

    private func field(label: String, binding: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary)
            TextField(placeholder, text: binding)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func editor(label: String, binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary)
            TextEditor(text: binding)
                .frame(height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray.opacity(0.3))
                )
        }
    }

    private var sujetsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sujets").font(.caption).foregroundColor(.secondary)
            ForEach(Array((state.analysis?.sujets ?? []).enumerated()), id: \.offset) { idx, _ in
                HStack {
                    TextField("Sujet", text: Binding(
                        get: { state.analysis?.sujets[safe: idx] ?? "" },
                        set: { if state.analysis?.sujets.indices.contains(idx) == true { state.analysis?.sujets[idx] = $0 } }
                    ))
                    .textFieldStyle(.roundedBorder)
                    Button {
                        if state.analysis?.sujets.indices.contains(idx) == true {
                            state.analysis?.sujets.remove(at: idx)
                        }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                }
            }
            Button("+ Ajouter un sujet") {
                state.analysis?.sujets.append("")
            }
            .buttonStyle(.plain)
            .font(.caption)
        }
    }

    private var decisionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Décisions").font(.caption).foregroundColor(.secondary)
            ForEach(Array((state.analysis?.decisions ?? []).enumerated()), id: \.offset) { idx, _ in
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Contenu", text: Binding(
                        get: { state.analysis?.decisions[safe: idx]?.contenu ?? "" },
                        set: { if state.analysis?.decisions.indices.contains(idx) == true { state.analysis?.decisions[idx].contenu = $0 } }
                    ))
                    .textFieldStyle(.roundedBorder)
                    HStack {
                        TextField("Responsable", text: Binding(
                            get: { state.analysis?.decisions[safe: idx]?.responsable ?? "" },
                            set: { if state.analysis?.decisions.indices.contains(idx) == true { state.analysis?.decisions[idx].responsable = $0 } }
                        ))
                        .textFieldStyle(.roundedBorder)
                        TextField("Implications", text: Binding(
                            get: { state.analysis?.decisions[safe: idx]?.implications ?? "" },
                            set: { if state.analysis?.decisions.indices.contains(idx) == true { state.analysis?.decisions[idx].implications = $0 } }
                        ))
                        .textFieldStyle(.roundedBorder)
                        Button {
                            if state.analysis?.decisions.indices.contains(idx) == true {
                                state.analysis?.decisions.remove(at: idx)
                            }
                        } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(6)
            }
            Button("+ Ajouter une décision") {
                state.analysis?.decisions.append(Decision(contenu: "", responsable: "", implications: ""))
            }
            .buttonStyle(.plain)
            .font(.caption)
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Actions").font(.caption).foregroundColor(.secondary)
            ForEach(Array((state.analysis?.actions ?? []).enumerated()), id: \.offset) { idx, _ in
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Tâche", text: Binding(
                        get: { state.analysis?.actions[safe: idx]?.tache ?? "" },
                        set: { if state.analysis?.actions.indices.contains(idx) == true { state.analysis?.actions[idx].tache = $0 } }
                    ))
                    .textFieldStyle(.roundedBorder)
                    HStack {
                        TextField("Responsable", text: Binding(
                            get: { state.analysis?.actions[safe: idx]?.responsable ?? "" },
                            set: { if state.analysis?.actions.indices.contains(idx) == true { state.analysis?.actions[idx].responsable = $0 } }
                        ))
                        .textFieldStyle(.roundedBorder)
                        TextField("Échéance", text: Binding(
                            get: { state.analysis?.actions[safe: idx]?.echeance ?? "" },
                            set: { if state.analysis?.actions.indices.contains(idx) == true { state.analysis?.actions[idx].echeance = $0 } }
                        ))
                        .textFieldStyle(.roundedBorder)
                        Button {
                            if state.analysis?.actions.indices.contains(idx) == true {
                                state.analysis?.actions.remove(at: idx)
                            }
                        } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(6)
            }
            Button("+ Ajouter une action") {
                state.analysis?.actions.append(ActionItem(tache: "", responsable: "", echeance: ""))
            }
            .buttonStyle(.plain)
            .font(.caption)
        }
    }

    @MainActor
    private func send() async {
        guard let analysis = state.analysis else { return }
        state.errorMessage = nil
        state.step = .sending
        do {
            let fileURL = try ObsidianService.writeNote(analysis: analysis, transcript: state.transcript, folderPath: obsidianPath)
            let slackText = ObsidianService.renderSlackMessage(analysis: analysis, fileURL: fileURL)
            try await SlackService.postMessage(channelId: slackChannelId, text: slackText)
            state.step = .done
        } catch {
            state.errorMessage = error.localizedDescription
            state.step = .review
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
