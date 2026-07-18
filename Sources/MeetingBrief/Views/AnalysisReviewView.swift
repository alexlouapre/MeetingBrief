import SwiftUI

struct AnalysisReviewView: View {
    @EnvironmentObject var state: AppState
    @AppStorage(Prefs.obsidianPath) var obsidianPath: String = ""
    @AppStorage(Prefs.lastSlackDestinationIds) var lastSlackDestinationIdsString: String = ""
    @AppStorage(Prefs.favoriteSlackChannelIds) var favoriteChannelIdsString: String = ""

    @State private var selectedIds: Set<String> = []
    @State private var loadingChannels = false
    @State private var showTranscript = false

    private var trimmedObsidianPath: String {
        obsidianPath.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSend: Bool {
        !trimmedObsidianPath.isEmpty && !selectedIds.isEmpty
    }

    private var visibleDestinations: [SlackChannel] {
        let favs = Set(favoriteChannelIdsString.split(separator: ",").map(String.init).filter { !$0.isEmpty })
        if favs.isEmpty { return state.slackChannels }
        return state.slackChannels.filter { favs.contains($0.id) }
    }

    private var selectedDestinations: [SlackChannel] {
        state.slackChannels.filter { selectedIds.contains($0.id) }
    }

    private var availableToAdd: [SlackChannel] {
        visibleDestinations.filter { !selectedIds.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if state.analysis != nil {
                    verificationBanner
                    transcriptDisclosure

                    field(label: "Titre", binding: Binding(
                        get: { state.analysis?.titre ?? "" },
                        set: { state.analysis?.titre = $0 }
                    ))

                    field(label: "Date", binding: Binding(
                        get: { state.analysis?.date ?? "" },
                        set: { state.analysis?.date = $0 }
                    ), placeholder: "YYYY-MM-DD")

                    summaryHeader

                    sectionsSection
                    actionsSection

                    Divider().padding(.vertical, 4)

                    channelSection

                    if trimmedObsidianPath.isEmpty {
                        warning("⚠︎ Configure le dossier Obsidian dans Réglages.")
                    }

                    HStack {
                        Button("Annuler") { state.reset() }
                        Spacer()
                        Button("J'ai vérifié — Envoyer") {
                            Task { await send() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSend)
                    }
                }
            }
        }
        .onAppear {
            if selectedIds.isEmpty {
                let lastIds = lastSlackDestinationIdsString
                    .split(separator: ",").map(String.init).filter { !$0.isEmpty }
                selectedIds = Set(lastIds)
            }
            if state.slackChannels.isEmpty {
                Task { await loadChannels() }
            }
        }
    }

    private var channelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Destinations Slack").font(.caption).foregroundColor(.secondary)
                Spacer()
                Button {
                    Task { await loadChannels() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Recharger la liste des destinations")
                .disabled(loadingChannels)
            }

            if loadingChannels && state.slackChannels.isEmpty {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Chargement des destinations…").font(.caption).foregroundColor(.secondary)
                }
            } else if state.slackChannels.isEmpty {
                Text("Aucune destination. Configure le token Slack dans Réglages puis recharge.")
                    .font(.caption).foregroundColor(.secondary)
            } else if visibleDestinations.isEmpty {
                Text("Toutes les destinations sont masquées. Coche-en au moins une dans Réglages → « Destinations visibles à l'envoi ».")
                    .font(.caption).foregroundColor(.orange)
            } else {
                destinationsPicker
            }
        }
    }

    private var destinationsPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(selectedDestinations) { dest in
                destinationChip(dest)
            }

            Menu {
                ForEach(availableToAdd) { dest in
                    Button(dest.displayLabel) { selectedIds.insert(dest.id) }
                }
            } label: {
                Label(
                    selectedDestinations.isEmpty ? "Choisir une destination" : "Ajouter une destination",
                    systemImage: "plus.circle"
                )
                .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .disabled(availableToAdd.isEmpty)
            .fixedSize()
        }
    }

    private func destinationChip(_ dest: SlackChannel) -> some View {
        HStack(spacing: 6) {
            Image(systemName: dest.kind == .user ? "person.fill" : "number")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(dest.kind == .user ? dest.name : "#\(dest.name)")
                .font(.callout)
            Spacer(minLength: 0)
            Button {
                selectedIds.remove(dest.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Retirer cette destination")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.1))
        )
    }

    private func warning(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.orange)
    }

    private var verificationBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Vérifie chaque item contre le transcript source.")
                    .font(.caption.weight(.semibold))
                Text("Claude peut avoir reformulé, omis ou inventé des actions.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.orange.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
        )
        .cornerRadius(6)
    }

    private var transcriptDisclosure: some View {
        DisclosureGroup(isExpanded: $showTranscript) {
            ScrollView {
                Text(state.transcript.isEmpty ? "_(transcript vide)_" : state.transcript)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(maxHeight: 200)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.25))
            )
        } label: {
            Text("Transcript source (\(state.transcript.count) caractères)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func field(label: String, binding: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary)
            TextField(placeholder, text: binding)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Résumé").font(.caption).foregroundColor(.secondary)
                TextField("Résumé du meeting…", text: Binding(
                    get: { state.analysis?.resume ?? "" },
                    set: { state.analysis?.resume = $0 }
                ), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...6)
            }

            let participants = (state.analysis?.participants ?? []).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let sujets = (state.analysis?.sujets ?? []).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            if !participants.isEmpty || !sujets.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    if !participants.isEmpty {
                        Text("Participants : \(participants.joined(separator: ", "))")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    if !sujets.isEmpty {
                        Text("Sujets : \(sujets.joined(separator: ", "))")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var sectionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sections")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
            if (state.analysis?.sections ?? []).isEmpty {
                Text("_Aucune section identifiée._")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array((state.analysis?.sections ?? []).enumerated()), id: \.element.id) { idx, section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.titre)
                            .font(.headline)
                        Text(section.notesMd.isEmpty ? "_(pas de notes)_" : section.notesMd)
                            .font(.body)
                            .lineSpacing(4)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 8)

                    if idx < (state.analysis?.sections.count ?? 0) - 1 {
                        Divider().opacity(0.5)
                    }
                }
            }
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Actions")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.bottom, 4)

            let actions = state.analysis?.actions ?? []
            ForEach(Array(actions.enumerated()), id: \.offset) { idx, _ in
                actionRow(idx: idx)

                if idx < actions.count - 1 {
                    Divider().opacity(0.5)
                }
            }

            Button("+ Ajouter une action") {
                state.analysis?.actions.append(ActionItem(responsable: "", tache: ""))
            }
            .buttonStyle(.plain)
            .font(.caption)
            .padding(.top, 6)
        }
    }

    private func actionRow(idx: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(idx + 1).")
                .font(.body.weight(.semibold))
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .trailing)

            VStack(alignment: .leading, spacing: 6) {
                TextField("Tâche…", text: Binding(
                    get: { state.analysis?.actions[safe: idx]?.tache ?? "" },
                    set: { if state.analysis?.actions.indices.contains(idx) == true { state.analysis?.actions[idx].tache = $0 } }
                ), axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .lineLimit(1...5)

                HStack(spacing: 4) {
                    Text("@").foregroundColor(.secondary)
                    TextField("Responsable", text: Binding(
                        get: { state.analysis?.actions[safe: idx]?.responsable ?? "" },
                        set: { if state.analysis?.actions.indices.contains(idx) == true { state.analysis?.actions[idx].responsable = $0 } }
                    ))
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .foregroundColor(.secondary)
                }
            }

            Button {
                if state.analysis?.actions.indices.contains(idx) == true {
                    state.analysis?.actions.remove(at: idx)
                }
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(0.3)
            .help("Supprimer cette action")
        }
        .padding(.vertical, 10)
    }

    @MainActor
    private func loadChannels() async {
        loadingChannels = true
        defer { loadingChannels = false }
        await state.loadSlackChannels()
    }

    @MainActor
    private func send() async {
        guard state.analysis != nil, !selectedIds.isEmpty else { return }
        state.errorMessage = nil
        do {
            try state.writeNoteToObsidian()
        } catch {
            state.errorMessage = error.localizedDescription
            return
        }
        await state.postToSlack(destinationIds: selectedIds)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
