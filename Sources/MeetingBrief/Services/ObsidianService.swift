import Foundation

enum ObsidianError: Error, LocalizedError {
    case missingPath
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingPath: return "Dossier Obsidian non configuré. Configure-le dans Réglages."
        case .writeFailed(let m): return "Impossible d'écrire la note : \(m)"
        }
    }
}

struct ObsidianService {
    @discardableResult
    static func writeNote(analysis: MeetingAnalysis, folderPath: String) throws -> URL {
        guard !folderPath.isEmpty else { throw ObsidianError.missingPath }

        let expanded = (folderPath as NSString).expandingTildeInPath
        let folder = URL(fileURLWithPath: expanded)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        let slug = slugify(analysis.titre)
        let dateStr = analysis.date.isEmpty ? todayString() : analysis.date
        // Dé-dup : sans étape de review, écraser silencieusement une note existante
        // serait une perte de données. YYYY-MM-DD-slug.md, puis -2, -3, …
        var fileURL = folder.appendingPathComponent("\(dateStr)-\(slug).md")
        var suffix = 2
        while FileManager.default.fileExists(atPath: fileURL.path) {
            fileURL = folder.appendingPathComponent("\(dateStr)-\(slug)-\(suffix).md")
            suffix += 1
        }

        let markdown = renderMarkdown(analysis: analysis)
        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw ObsidianError.writeFailed(error.localizedDescription)
        }
        return fileURL
    }

    static func renderMarkdown(analysis: MeetingAnalysis) -> String {
        var s = ""
        s += "---\n"
        s += "type: meeting\n"
        s += "date: \(analysis.date)\n"
        s += "titre: \(escapeYAML(analysis.titre))\n"
        let participants = analysis.participants.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !participants.isEmpty {
            s += "participants:\n\(yamlList(participants))\n"
        }
        let sujets = analysis.sujets.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !sujets.isEmpty {
            s += "tags:\n\(yamlList(sujets))\n"
        }
        s += "---\n\n"
        s += "# \(analysis.titre)\n\n"

        let resume = analysis.resume.trimmingCharacters(in: .whitespacesAndNewlines)
        if !resume.isEmpty {
            s += "> [!summary] Résumé\n"
            for line in resume.split(separator: "\n", omittingEmptySubsequences: true) {
                s += "> \(line)\n"
            }
            s += "\n"
        }

        for section in analysis.sections {
            s += "### \(section.titre)\n"
            for p in section.points where !p.isEmpty { s += "- \(p)\n" }
            if section.decisions.contains(where: { !$0.isEmpty }) {
                s += "\n**Décisions**\n"
                for d in section.decisions where !d.isEmpty { s += "- \(d)\n" }
            }
            if section.pistes.contains(where: { !$0.isEmpty }) {
                s += "\n**Pistes / idées**\n"
                for p in section.pistes where !p.isEmpty { s += "- \(p)\n" }
            }
            if section.questionsOuvertes.contains(where: { !$0.isEmpty }) {
                s += "\n**Questions ouvertes**\n"
                for q in section.questionsOuvertes where !q.isEmpty { s += "- \(q)\n" }
            }
            s += "\n"
        }

        s += "### Actions\n\n"
        if analysis.actions.isEmpty {
            s += "_Aucune action identifiée._\n"
        } else {
            s += renderActionsGrouped(analysis.actions, boldMarker: "**")
        }

        return s
    }

    static func renderSlackMessage(analysis: MeetingAnalysis) -> String {
        var parts: [String] = []
        parts.append("Meeting — \(frenchLongDate(analysis.date))")

        if analysis.actions.isEmpty {
            parts.append("Aucune action enregistrée suite au meeting.")
            return parts.joined(separator: "\n\n")
        }

        parts.append("Suite au meeting d'aujourd'hui, ces actions ont été enregistrées :")
        parts.append(renderActionsGrouped(analysis.actions, boldMarker: "").trimmingCharacters(in: .newlines))

        return parts.joined(separator: "\n\n")
    }

    /// Groupe les actions par `responsable` (normalisé), trie par nombre d'actions desc
    /// (tiebreak = ordre d'apparition), et rend un bloc texte :
    ///
    ///     **Prénom**
    ///     [] tache1
    ///     [] tache2
    ///
    /// `boldMarker` = `"**"` pour Obsidian, `"*"` pour Slack.
    private static func renderActionsGrouped(_ actions: [ActionItem], boldMarker: String) -> String {
        var order: [String] = []
        var groups: [String: [ActionItem]] = [:]
        for a in actions {
            let key = formatResponsable(a.responsable)
            if groups[key] == nil {
                groups[key] = []
                order.append(key)
            }
            groups[key]?.append(a)
        }

        // Preserve insertion order — le prompt demande au modèle de produire
        // les actions dans l'ordre d'affichage souhaité (nb actions desc,
        // binômes juste après la personne principale).
        let sortedKeys = order

        var out = ""
        for (idx, key) in sortedKeys.enumerated() {
            guard let acts = groups[key] else { continue }
            out += "\(boldMarker)\(key)\(boldMarker)\n"
            for a in acts {
                out += "[ ] \(a.tache)\n"
            }
            if idx < sortedKeys.count - 1 {
                out += "\n"
            }
        }
        return out
    }

    private static func formatResponsable(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "Non assigné" }
        let parts = trimmed
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.count > 1 ? parts.joined(separator: " & ") : trimmed
    }

    private static func frenchLongDate(_ iso: String) -> String {
        let inFmt = DateFormatter()
        inFmt.dateFormat = "yyyy-MM-dd"
        inFmt.locale = Locale(identifier: "en_US_POSIX")
        guard let date = inFmt.date(from: iso) else { return iso }
        let outFmt = DateFormatter()
        outFmt.dateFormat = "d MMMM yyyy"
        outFmt.locale = Locale(identifier: "fr_FR")
        return outFmt.string(from: date)
    }

    private static func slugify(_ s: String) -> String {
        let lowered = s.lowercased()
        let folded = lowered.folding(options: .diacriticInsensitive, locale: .current)
        let allowed = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-"))
        let filteredScalars = folded.unicodeScalars.filter { allowed.contains($0) }
        let cleaned = String(String.UnicodeScalarView(filteredScalars))
        var dashed = cleaned.replacingOccurrences(of: " ", with: "-")
        while dashed.contains("--") {
            dashed = dashed.replacingOccurrences(of: "--", with: "-")
        }
        let trimmed = dashed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let final = trimmed.isEmpty ? "meeting" : trimmed
        return String(final.prefix(60))
    }

    private static func escapeYAML(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "\"\"" }
        // Quote if the value contains structural chars, or starts with a YAML
        // reserved indicator that would otherwise be misparsed in frontmatter.
        let needsQuoteContains = trimmed.contains(":") || trimmed.contains("\"") || trimmed.contains("#")
        let reservedFirstChars: Set<Character> = ["-", "?", "[", "]", "{", "}", ",", "&", "*", "!", "|", ">", "'", "%", "@", "`"]
        let startsReserved = trimmed.first.map { reservedFirstChars.contains($0) } ?? false
        let hasEdgeSpace = s != trimmed
        if needsQuoteContains || startsReserved || hasEdgeSpace {
            let esc = trimmed
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(esc)\""
        }
        return trimmed
    }

    /// Renders a YAML block-sequence (one `  - value` per line), each value escaped.
    private static func yamlList(_ items: [String]) -> String {
        items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { "  - \(escapeYAML($0))" }
            .joined(separator: "\n")
    }

    private static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
