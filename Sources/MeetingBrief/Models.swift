import Foundation

struct MeetingAnalysis: Codable, Equatable {
    var titre: String
    var date: String
    var resume: String
    var participants: [String]
    var sujets: [String]
    var sections: [MeetingSection]
    var actions: [ActionItem]

    enum CodingKeys: String, CodingKey {
        case titre, date, resume, participants, sujets, sections, actions
    }

    init(titre: String, date: String, resume: String = "", participants: [String] = [], sujets: [String] = [], sections: [MeetingSection], actions: [ActionItem]) {
        self.titre = titre
        self.date = date
        self.resume = resume
        self.participants = participants
        self.sujets = sujets
        self.sections = sections
        self.actions = actions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.titre = try c.decodeIfPresent(String.self, forKey: .titre) ?? ""
        self.date = try c.decodeIfPresent(String.self, forKey: .date) ?? ""
        self.resume = try c.decodeIfPresent(String.self, forKey: .resume) ?? ""
        self.participants = try c.decodeIfPresent([String].self, forKey: .participants) ?? []
        self.sujets = try c.decodeIfPresent([String].self, forKey: .sujets) ?? []
        self.sections = try c.decodeIfPresent([MeetingSection].self, forKey: .sections) ?? []
        self.actions = try c.decodeIfPresent([ActionItem].self, forKey: .actions) ?? []
    }
}

struct MeetingSection: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var titre: String
    var points: [String]
    var decisions: [String]
    var pistes: [String]
    var questionsOuvertes: [String]

    enum CodingKeys: String, CodingKey {
        case titre, points, decisions, pistes
        case questionsOuvertes = "questions_ouvertes"
    }

    init(titre: String, points: [String] = [], decisions: [String] = [], pistes: [String] = [], questionsOuvertes: [String] = []) {
        self.titre = titre
        self.points = points
        self.decisions = decisions
        self.pistes = pistes
        self.questionsOuvertes = questionsOuvertes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.titre = try c.decodeIfPresent(String.self, forKey: .titre) ?? ""
        self.points = try c.decodeIfPresent([String].self, forKey: .points) ?? []
        self.decisions = try c.decodeIfPresent([String].self, forKey: .decisions) ?? []
        self.pistes = try c.decodeIfPresent([String].self, forKey: .pistes) ?? []
        self.questionsOuvertes = try c.decodeIfPresent([String].self, forKey: .questionsOuvertes) ?? []
    }

    /// Rendu texte brut pour la review view (notesMd n'y est PAS rendu en markdown).
    /// Aplati les 4 tableaux en bullets indentés lisibles, sans marqueurs `**`.
    var notesMd: String {
        var lines: [String] = []
        for p in points where !p.isEmpty { lines.append("- \(p)") }
        if decisions.contains(where: { !$0.isEmpty }) {
            lines.append("Décisions :")
            for d in decisions where !d.isEmpty { lines.append("  - \(d)") }
        }
        if pistes.contains(where: { !$0.isEmpty }) {
            lines.append("Pistes / idées :")
            for p in pistes where !p.isEmpty { lines.append("  - \(p)") }
        }
        if questionsOuvertes.contains(where: { !$0.isEmpty }) {
            lines.append("Questions ouvertes :")
            for q in questionsOuvertes where !q.isEmpty { lines.append("  - \(q)") }
        }
        return lines.joined(separator: "\n")
    }
}

struct ActionItem: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var responsable: String
    var tache: String

    enum CodingKeys: String, CodingKey {
        case responsable, tache
    }

    init(responsable: String, tache: String) {
        self.responsable = responsable
        self.tache = tache
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.responsable = try c.decodeIfPresent(String.self, forKey: .responsable) ?? ""
        self.tache = try c.decodeIfPresent(String.self, forKey: .tache) ?? ""
    }
}

enum SlackDestinationKind: String, Codable, Hashable {
    case channel
    case user
}

struct SlackChannel: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let kind: SlackDestinationKind

    init(id: String, name: String, kind: SlackDestinationKind = .channel) {
        self.id = id
        self.name = name
        self.kind = kind
    }

    var displayLabel: String {
        switch kind {
        case .channel: return "#\(name)"
        case .user:    return "@\(name)"
        }
    }
}
