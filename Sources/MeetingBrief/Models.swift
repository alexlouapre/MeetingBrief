import Foundation

struct MeetingAnalysis: Codable, Equatable {
    var titre: String
    var date: String
    var resume: String
    var sujets: [String]
    var decisions: [Decision]
    var actions: [ActionItem]
}

struct Decision: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var contenu: String
    var responsable: String
    var implications: String

    enum CodingKeys: String, CodingKey {
        case contenu, responsable, implications
    }
}

struct ActionItem: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var tache: String
    var responsable: String
    var echeance: String

    enum CodingKeys: String, CodingKey {
        case tache, responsable, echeance
    }
}

struct SlackChannel: Codable, Identifiable, Hashable {
    let id: String
    let name: String
}
