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
    static func writeNote(analysis: MeetingAnalysis, transcript: String, folderPath: String) throws -> URL {
        guard !folderPath.isEmpty else { throw ObsidianError.missingPath }

        let expanded = (folderPath as NSString).expandingTildeInPath
        let folder = URL(fileURLWithPath: expanded)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        let slug = slugify(analysis.titre)
        let dateStr = analysis.date.isEmpty ? todayString() : analysis.date
        let filename = "\(dateStr)-\(slug).md"
        let fileURL = folder.appendingPathComponent(filename)

        let markdown = renderMarkdown(analysis: analysis, transcript: transcript)
        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw ObsidianError.writeFailed(error.localizedDescription)
        }
        return fileURL
    }

    static func renderMarkdown(analysis: MeetingAnalysis, transcript: String) -> String {
        var s = ""
        s += "---\n"
        s += "type: meeting\n"
        s += "date: \(analysis.date)\n"
        s += "titre: \(escapeYAML(analysis.titre))\n"
        s += "---\n\n"
        s += "# \(analysis.titre)\n\n"

        if !analysis.resume.isEmpty {
            s += "## Résumé\n\n\(analysis.resume)\n\n"
        }

        s += "## Sujets\n\n"
        if analysis.sujets.isEmpty {
            s += "_Aucun sujet identifié._\n\n"
        } else {
            for sujet in analysis.sujets { s += "- \(sujet)\n" }
            s += "\n"
        }

        s += "## Décisions\n\n"
        if analysis.decisions.isEmpty {
            s += "_Aucune décision identifiée._\n\n"
        } else {
            for d in analysis.decisions {
                let resp = d.responsable.isEmpty ? "" : " **[\(d.responsable)]**"
                var line = "-\(resp) \(d.contenu)"
                if !d.implications.isEmpty {
                    line += " — _implications : \(d.implications)_"
                }
                s += line + "\n"
            }
            s += "\n"
        }

        s += "## Actions\n\n"
        if analysis.actions.isEmpty {
            s += "_Aucune action identifiée._\n\n"
        } else {
            for a in analysis.actions {
                let resp = a.responsable.isEmpty ? "" : " **[\(a.responsable)]**"
                let ech = a.echeance.isEmpty ? "" : " — échéance : \(a.echeance)"
                s += "- [ ]\(resp) \(a.tache)\(ech)\n"
            }
            s += "\n"
        }

        s += "## Transcript brut\n\n"
        s += "<details>\n<summary>Voir le transcript</summary>\n\n"
        s += transcript
        s += "\n\n</details>\n"

        return s
    }

    static func renderSlackMessage(analysis: MeetingAnalysis, fileURL: URL?) -> String {
        var s = "*\(analysis.titre)* — \(analysis.date)\n\n"
        if !analysis.resume.isEmpty {
            s += "_\(analysis.resume)_\n\n"
        }

        if !analysis.decisions.isEmpty {
            s += "*Décisions*\n"
            for d in analysis.decisions {
                let resp = d.responsable.isEmpty ? "" : " [\(d.responsable)]"
                s += "•\(resp) \(d.contenu)\n"
            }
            s += "\n"
        }

        if !analysis.actions.isEmpty {
            s += "*Actions*\n"
            for a in analysis.actions {
                let resp = a.responsable.isEmpty ? "" : " [\(a.responsable)]"
                let ech = a.echeance.isEmpty ? "" : " (d'ici \(a.echeance))"
                s += "•\(resp) \(a.tache)\(ech)\n"
            }
            s += "\n"
        }

        if let url = fileURL {
            s += "_Note enregistrée : \(url.lastPathComponent)_"
        }
        return s
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
        if s.contains(":") || s.contains("\"") || s.contains("#") {
            let esc = s.replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(esc)\""
        }
        return s
    }

    private static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
