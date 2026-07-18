import SwiftUI
import AppKit

/// Mini picker Slack affiché après l'enregistrement direct de la note.
/// La note est déjà sur disque — rien ne part sur Slack sans clic explicite.
struct MiniSlackPickerView: View {
    @EnvironmentObject var state: AppState
    @AppStorage(Prefs.lastSlackDestinationIds) var lastSlackDestinationIdsString: String = ""
    @AppStorage(Prefs.favoriteSlackChannelIds) var favoriteChannelIdsString: String = ""

    @State private var selectedIds: Set<String> = []
    @State private var loadingChannels = false
    @Namespace private var glassNamespace

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
        VStack(alignment: .leading, spacing: 16) {
            header
                .glassCard()

            Text("Partager sur Slack ?")
                .font(.subheadline.weight(.semibold))

            destinationsSection

            HStack {
                Button("Passer") { state.step = .done }
                    .buttonStyle(.glass)
                Spacer()
                Button("Envoyer sur Slack") {
                    Task { await state.postToSlack(destinationIds: selectedIds) }
                }
                .buttonStyle(.glassProminent)
                .disabled(selectedIds.isEmpty)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            if selectedIds.isEmpty {
                let lastIds = lastSlackDestinationIdsString
                    .split(separator: ",").map(String.init).filter { !$0.isEmpty }
                selectedIds = Set(lastIds)
            }
            if state.slackChannels.isEmpty {
                Task {
                    loadingChannels = true
                    defer { loadingChannels = false }
                    await state.loadSlackChannels()
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.green)
            VStack(alignment: .leading, spacing: 4) {
                Text("Note enregistrée").font(.headline)
                if let url = state.lastNoteURL {
                    Text(url.lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Afficher dans le Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var destinationsSection: some View {
        if loadingChannels && state.slackChannels.isEmpty {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Chargement des destinations…").font(.caption).foregroundColor(.secondary)
            }
        } else if state.slackChannels.isEmpty {
            Text("Aucune destination. Configure le token Slack dans Réglages.")
                .font(.caption).foregroundColor(.secondary)
        } else if visibleDestinations.isEmpty && selectedDestinations.isEmpty {
            Text("Toutes les destinations sont masquées. Coche-en au moins une dans Réglages → « Destinations visibles à l'envoi ».")
                .font(.caption).foregroundColor(.orange)
        } else {
            destinationsPicker
        }
    }

    private var destinationsPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            GlassEffectContainer(spacing: 6) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(selectedDestinations) { dest in
                        destinationChip(dest)
                    }
                }
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
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: Capsule())
        .glassEffectUnion(id: "picker-chips", namespace: glassNamespace)
    }
}
