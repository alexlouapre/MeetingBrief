import Foundation

enum ClaudeError: Error, LocalizedError {
    case missingKey
    case apiError(String)
    case parsingError(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: return "Clé API Claude manquante. Configure-la dans Réglages."
        case .apiError(let msg): return "Erreur API Claude : \(msg)"
        case .parsingError(let msg): return "Impossible de parser la réponse de Claude : \(msg)"
        }
    }
}

struct ClaudeService {
    static let model = "claude-sonnet-4-6"
    static let apiVersion = "2023-06-01"
    static let url = URL(string: "https://api.anthropic.com/v1/messages")!

    static func analyze(transcript: String) async throws -> MeetingAnalysis {
        guard let key = Keychain.get("claude_api_key"), !key.isEmpty else {
            throw ClaudeError.missingKey
        }

        let systemPrompt = """
        Tu es un assistant qui analyse des transcripts de réunions professionnelles.
        Tu extrais de manière structurée :
        - Un titre court (max 80 caractères)
        - La date de la réunion si mentionnée dans le transcript, sinon la date du jour au format YYYY-MM-DD
        - Un résumé en 3 à 5 phrases
        - La liste des sujets discutés (titres courts, 3-6 mots)
        - Les décisions prises, avec responsable et implications
        - Les actions, avec responsable et échéance

        Tu réponds TOUJOURS avec un objet JSON valide, et rien d'autre : pas de texte autour, pas de markdown, pas de ```.
        """

        let schema = """
        {
          "titre": "string",
          "date": "YYYY-MM-DD",
          "resume": "string",
          "sujets": ["string"],
          "decisions": [{"contenu": "string", "responsable": "string", "implications": "string"}],
          "actions": [{"tache": "string", "responsable": "string", "echeance": "string"}]
        }
        """

        let userPrompt = """
        Analyse ce transcript et renvoie un objet JSON conforme au schéma suivant :

        \(schema)

        Règles :
        - Si une information manque (ex: pas d'échéance explicite pour une action), mets une chaîne vide ""
        - N'invente rien, ne déduis que ce qui est explicitement ou implicitement présent dans le transcript
        - Les sujets sont des titres courts (3-6 mots)
        - Les décisions incluent le "quoi" + "par qui" + "pourquoi/implications"
        - Les actions sont actionnables (verbe d'action + responsable + échéance si dispo)

        Transcript :
        \(transcript)
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userPrompt]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "erreur inconnue"
            throw ClaudeError.apiError(msg)
        }

        struct Resp: Codable {
            struct Content: Codable { let text: String }
            let content: [Content]
        }
        let decoded = try JSONDecoder().decode(Resp.self, from: data)
        guard let text = decoded.content.first?.text else {
            throw ClaudeError.parsingError("réponse vide")
        }

        var jsonText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if jsonText.hasPrefix("```") {
            jsonText = jsonText.replacingOccurrences(of: "```json", with: "")
            jsonText = jsonText.replacingOccurrences(of: "```", with: "")
            jsonText = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let jsonData = jsonText.data(using: .utf8) else {
            throw ClaudeError.parsingError("encodage utf8")
        }

        do {
            return try JSONDecoder().decode(MeetingAnalysis.self, from: jsonData)
        } catch {
            throw ClaudeError.parsingError(error.localizedDescription)
        }
    }
}
